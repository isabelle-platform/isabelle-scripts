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
    which apt-get && apt-get install -y build-essential cargo curl docker.io git letsencrypt libssl-dev nginx pkg-config python3-certbot-nginx python3-pip
    if [ "$machine_type" == "droplet" ] ; then
        which apt-get && apt-get remove -y unattended-upgrades
        which apt-get && apt-get upgrade -y
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

	cat server/nginx.conf | \
		sed "s/<pub_fqdn>/${pub_fqdn}/g" | \
		sed "s/<root_folder>/${distr_ui_dir}/g" | \
		sed "s/<srv_port>/${srv_port}/g" | \
		sed "s/<core_port>/${core_port}/g" > /etc/nginx/sites-available/isabelle-${flavour}.conf
    pushd /etc/nginx/sites-enabled
    ln -s ../sites-available/isabelle-${flavour}.conf
    popd

    mkdir -p /etc/nginx/isabelle

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

function stage_set_up_service() {
	local run_script

	systemctl disable isabelle-${flavour}

	run_script="$(echo ${DISTR_DIR}/scripts/run.sh | sed 's/\//\\\//g')"

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
stage_set_up_service

if [ -d extras/deploy ] ; then
	for file in $(ls extras/deploy/*) ; do
		TOP_DIR="${TOP_DIR}" "$file"
	done
fi
