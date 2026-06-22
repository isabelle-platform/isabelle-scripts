#!/bin/bash
# Isabelle project
# This script deploys Isabelle to the system.

TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

function stage_install_deps() {
    local machine_type="$1"

    echo "Installing dependencies"
    which apt-get && apt-get update
    which apt-get && apt-get install -y build-essential cargo curl docker.io docker-buildx git jq letsencrypt libssl-dev nginx pkg-config python3-certbot-nginx python3-pip sshpass
    if [ "$machine_type" == "droplet" ] ; then
        which apt-get && apt-get remove -y unattended-upgrades
        which apt-get && apt-get upgrade -y
    fi

    # docker-compose v2 plugin: not in default Ubuntu repos when using docker.io.
    # Try apt first (works when docker-ce repo is configured), fall back to the
    # official binary release.
    if ! docker compose version > /dev/null 2>&1 ; then
        if ! apt-get install -y docker-compose-plugin > /dev/null 2>&1 ; then
            local arch
            arch="$(uname -m)"
            case "$arch" in
                x86_64) arch="x86_64" ;;
                aarch64|arm64) arch="aarch64" ;;
            esac
            mkdir -p /usr/local/lib/docker/cli-plugins
            curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${arch}" \
                -o /usr/local/lib/docker/cli-plugins/docker-compose
            chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
        fi
    fi

    if command -v systemctl > /dev/null 2>&1 ; then
        systemctl enable --now docker || true
    fi

    # Enable BuildKit in dockerd by default — Dockerfiles using --mount
    # (e.g. bublik-runner) require it.
    if [ -d /etc/docker ] && ! grep -q '"buildkit": true' /etc/docker/daemon.json 2> /dev/null ; then
        if [ ! -f /etc/docker/daemon.json ] ; then
            echo '{"features": {"buildkit": true}}' > /etc/docker/daemon.json
        else
            python3 - <<'PY'
import json, pathlib
p = pathlib.Path('/etc/docker/daemon.json')
try:
    cfg = json.loads(p.read_text())
except Exception:
    cfg = {}
cfg.setdefault('features', {})['buildkit'] = True
p.write_text(json.dumps(cfg, indent=2))
PY
        fi
        systemctl restart docker || true
    fi

    if command -v getent > /dev/null 2>&1 && getent group docker > /dev/null ; then
        if ! id -nG root | tr ' ' '\n' | grep -qx docker ; then
            usermod -aG docker root || true
        fi
    fi

    return 0
}

function stage_set_up_firewall() {
    if [ "${no_fw}" == "" ] ; then
    	echo "Set up UFW"
	    ufw allow ssh
	    ufw allow 443/tcp
	    ufw allow 80/tcp
	    ufw --force enable
	fi
	return 0
}

function stage_set_up_nginx() {
	local distr_ui_dir="$(echo ${DISTR_DIR}/distr/ui | sed 's/\//\\\//g')"

	local nginx_conf
	nginx_conf="$(cat server/nginx.conf | \
		sed "s/<pub_fqdn>/${pub_fqdn}/g" | \
		sed "s/<root_folder>/${distr_ui_dir}/g" | \
		sed "s/<srv_port>/${srv_port}/g" | \
		sed "s/<core_port>/${core_port}/g")"

	if [ "${no_serve_root}" != "" ] ; then
		nginx_conf="$(echo "${nginx_conf}" | \
			sed '/^\s*index index\.html;/d' | \
			sed 's|try_files \$uri \$uri/ /index\.html;|try_files \$uri \$uri/ =404;|')"
	fi

	echo "${nginx_conf}" > /etc/nginx/sites-available/isabelle-${flavour}.conf
    pushd /etc/nginx/sites-enabled
    ln -s ../sites-available/isabelle-${flavour}.conf
    popd

    mkdir -p /etc/nginx/isabelle
    if [ -d extras/nginx ] ; then
        cp -r extras/nginx/* /etc/nginx/isabelle/
    fi

    service nginx restart
    return 0
}

function stage_set_up_apache() {
	local distr_ui_dir="$(echo ${DISTR_DIR}/distr/ui | sed 's/\//\\\//g')"

	cat server/apache.conf | \
		sed "s/<pub_fqdn>/${pub_fqdn}/g" | \
		sed "s/<root_folder>/${distr_ui_dir}/g" | \
		sed "s/<srv_port>/${srv_port}/g" | \
		sed "s/<core_port>/${core_port}/g" > /etc/apache2/sites-available/isabelle-${flavour}.conf
    pushd /etc/apache2/sites-enabled
    ln -s ../sites-available/isabelle-${flavour}.conf
    popd

    service apache2 restart
    return 0
}

function stage_set_up_certs() {
	if [ "$no_cert" == "" ] ; then
		certbot --agree-tos --email "${cert_owner}" -n --${server_type} -d "$pub_fqdn"
	fi
	return 0
}

function stage_set_up_protostar_secrets() {
	# proteos: install the operator-provided runtime secrets next to the
	# shipped protostar config so run.sh can source them for the core and the
	# protostar CLI it spawns. The source file comes from
	# `configure.sh --coreenv-file` and lives outside the tarball, so both it
	# and this installed copy survive in-place updates (.env is gitignored, so
	# the release tarball never overwrites it). No-op for flavours that don't
	# bundle protostar-cfgs or when no secrets were configured.
	local cfgs_dir="${DISTR_DIR}/distr/core/protostar-cfgs"
	[ -d "${cfgs_dir}" ] || return 0
	[ -f "${DISTR_DIR}/.coreenv" ] || return 0

	cp "${DISTR_DIR}/.coreenv" "${cfgs_dir}/.env" || fail "Failed to install protostar env"
	chmod 600 "${cfgs_dir}/.env"
	return 0
}

function stage_set_up_service() {
	local run_script

	systemctl disable isabelle-${flavour}

	run_script="$(echo $(realpath ${DISTR_DIR}/scripts/run.sh) | sed 's/\//\\\//g')"

	cat service/isabelle.service \
    	| sed "s/<run_script>/${run_script}/g" > /lib/systemd/system/isabelle-${flavour}.service

    systemctl daemon-reload
    systemctl restart isabelle-${flavour}
    systemctl enable isabelle-${flavour}
    return 0
}

function stage_set_up_database() {
	${TOP_DIR}/database.sh start
	return 0
}

function stage_set_up_extra_units() {
	[ -d extras/systemd ] || return 0

	local distr_dir_norm
	local top_dir_norm
	distr_dir_norm="$(cd "${DISTR_DIR}" && pwd -P)"
	top_dir_norm="$(cd "${TOP_DIR}" && pwd -P)"

	local distr_dir_esc="$(echo ${distr_dir_norm} | sed 's/\//\\\//g')"
	local top_dir_esc="$(echo ${top_dir_norm} | sed 's/\//\\\//g')"
	local pub_fqdn_esc="$(echo ${pub_fqdn} | sed 's/\//\\\//g')"
	local flavour_esc="$(echo ${flavour} | sed 's/\//\\\//g')"

	local unit_src
	local unit_name
	for unit_src in extras/systemd/*.service ; do
		[ -f "${unit_src}" ] || continue
		unit_name="$(basename "${unit_src}")"
		sed -e "s/<distr_dir>/${distr_dir_esc}/g" \
		    -e "s/<top_dir>/${top_dir_esc}/g" \
		    -e "s/<pub_fqdn>/${pub_fqdn_esc}/g" \
		    -e "s/<flavour>/${flavour_esc}/g" \
		    "${unit_src}" > "/lib/systemd/system/${unit_name}"
	done

	systemctl daemon-reload

	for unit_src in extras/systemd/*.service ; do
		[ -f "${unit_src}" ] || continue
		unit_name="$(basename "${unit_src}")"
		systemctl enable "${unit_name}"
		systemctl restart "${unit_name}"
	done
	return 0
}

# Preparation
stage_install_deps "${machine_type}"
stage_set_up_firewall

if [ "${server_type}" == "apache" ] ; then
	stage_set_up_apache
else
	stage_set_up_nginx
fi

stage_set_up_certs

stage_set_up_database

# Run install-time extras hooks BEFORE the core service starts: hooks may seed
# data/raw/* (e.g. bublik-settings.sh injects bublik_ui_url and the SSH creds
# the core uses to docker-exec the bublik containers), and the core's first
# run snapshots that data once and writes the .initialized sentinel.
if [ -d extras/deploy ] ; then
	for file in $(ls extras/deploy/*.sh) ; do
		TOP_DIR="${TOP_DIR}" "$file"
	done
fi

stage_set_up_protostar_secrets
stage_set_up_service
stage_set_up_extra_units
