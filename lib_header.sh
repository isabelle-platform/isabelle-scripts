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
