#!/bin/bash
# Isabelle project
# This is a common library for different scripts.

function fail() {
	echo $@ >&2
	exit 1
}

if [ ! -f ${TOP_DIR}/.in_release ] ; then
	fail "Not in release!"
fi

DISTR_DIR="${TOP_DIR}/.."

if [ ! -d "${DISTR_DIR}/data" ] || [ ! -d "${DISTR_DIR}/distr" ] || [ ! -f "${DISTR_DIR}/.flavour" ] ; then
	fail "Doesn't look like distribution directory"
fi

flavour="$(cat ${DISTR_DIR}/.flavour 2> /dev/null)"
db_port="$(cat ${DISTR_DIR}/.db_port 2> /dev/null)"
core_port="$(cat ${DISTR_DIR}/.core_port 2> /dev/null)"
pub_fqdn="$(cat ${DISTR_DIR}/.pub_fqdn 2> /dev/null)"
pub_url="$(cat ${DISTR_DIR}/.pub_url 2> /dev/null)"
cert_owner="$(cat ${DISTR_DIR}/.cert_owner 2> /dev/null)"
srv_port="$(cat ${DISTR_DIR}/.srv_port 2> /dev/null)"
machine_type="$(cat ${DISTR_DIR}/.machine_type 2> /dev/null)"
server_type="$(cat ${DISTR_DIR}/.server_type 2> /dev/null)"
no_cert="$(cat ${DISTR_DIR}/.no_cert 2> /dev/null)"
no_fw="$(cat ${DISTR_DIR}/.no_fw 2> /dev/null)"
db="$(cat ${DISTR_DIR}/.db 2> /dev/null)"
cookie_http_insecure="$(cat ${DISTR_DIR}/.cookie_http_insecure 2> /dev/null)"
no_serve_root="$(cat ${DISTR_DIR}/.no_serve_root 2> /dev/null)"

if [ "$db_port" == "" ] ; then
	db_port="27017"
fi

if [ "$core_port" == "" ] ; then
	core_port="8090"
fi

if [ "$pub_fqdn" == "" ] ; then
	pub_fqdn="localhost"
fi

if [ "$pub_url" == "" ] ; then
	pub_url="http://localhost:${core_port}"
fi

if [ "$srv_port" == "" ] ; then
	srv_port="80"
fi

if [ "${machine_type}" == "" ] ; then
	machine_type=""
fi

if [ "${server_type}" == "" ] ; then
	server_type="nginx"
fi

# no_cert
# no_fw

if [ "${db}" == "" ] ; then
	db="mongo"
fi

# cookie_http_insecure
# no_serve_root

# Install the operator-provided `features.js` where the core reads it.
#
# What a host is allowed to do belongs to the installation, not to the
# release: two hosts running the same tarball may be entitled to different
# things, so the document comes from `configure.sh --features-file` and lives
# outside the tarball. The core reads it once at startup and never writes it,
# so this has to run before the service is (re)started, and again after an
# update unpacks a new tarball over `data/raw`.
#
# The contents are the flavour's business. This script neither knows nor
# checks which names mean anything; it checks only that the document is the
# shape the core can read, because a malformed one declares *nothing* and
# that failure would otherwise surface much later, as somebody being refused
# something they are entitled to.
#
# Nothing configured means nothing written. That is deliberate: an
# installation set up before this option existed keeps whatever `features.js`
# it already has, and `tar` leaves files the archive does not contain alone.
function install_features() {
	local source="${DISTR_DIR}/.features"
	local target="${DISTR_DIR}/data/raw/features.js"

	[ -f "${source}" ] || return 0
	[ -d "${DISTR_DIR}/data/raw" ] || fail "No data/raw to install ${target} into"

	# jq is one of the deploy dependencies, so this runs on a deployed host
	# and is skipped anywhere it is genuinely unavailable rather than turning
	# a missing tool into a failed update.
	if command -v jq > /dev/null 2>&1 ; then
		jq -e 'type == "object"' "${source}" > /dev/null 2>&1 ||
			fail "${source} is not a JSON object of feature name to descriptor"
	fi

	cp "${source}" "${target}" || fail "Cannot install ${target}"

	# The core reads this as the service user. An update writes it after the
	# tree has already been handed over, so match the directory rather than
	# leave one root-owned file behind in it.
	chown --reference="${DISTR_DIR}/data/raw" "${target}" 2> /dev/null || true

	echo "Features: installed $(jq -r 'keys | join(", ")' "${target}" 2> /dev/null || echo "${target}")"
	return 0
}

# Write the release's extra systemd units and tell systemd about them.
#
# A flavour ships its own services beside the core — bublik, multiverse — as
# unit templates in extras/systemd. `service.sh` starts and stops every one of
# them, but only by name: the unit file itself has to be in /lib/systemd/system
# first. Deploy always wrote them; an update did not, so a service that a new
# release introduced was never installed on a host that was deployed before
# it, and `service.sh start` answered "Unit ... not found" while the update
# reported success. Both now go through here.
#
# Every unit is rewritten, not only the new ones: a release may change a unit
# it already shipped, and a host should run the one its release describes.
# Enabled too, so it comes back after a reboot. Starting is the caller's
# business — deploy restarts each one, an update starts them all with the core.
function install_extra_units() {
	[ -d "${TOP_DIR}/extras/systemd" ] || return 0
	command -v systemctl > /dev/null 2>&1 || return 0

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
	for unit_src in "${TOP_DIR}"/extras/systemd/*.service ; do
		[ -f "${unit_src}" ] || continue
		unit_name="$(basename "${unit_src}")"
		sed -e "s/<distr_dir>/${distr_dir_esc}/g" \
		    -e "s/<top_dir>/${top_dir_esc}/g" \
		    -e "s/<pub_fqdn>/${pub_fqdn_esc}/g" \
		    -e "s/<flavour>/${flavour_esc}/g" \
		    "${unit_src}" > "/lib/systemd/system/${unit_name}" ||
			fail "Cannot write /lib/systemd/system/${unit_name}"
	done

	systemctl daemon-reload

	for unit_src in "${TOP_DIR}"/extras/systemd/*.service ; do
		[ -f "${unit_src}" ] || continue
		systemctl enable "$(basename "${unit_src}")"
	done
	return 0
}
