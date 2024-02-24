#!/bin/bash

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

if [ "$db_port" == "" ] ; then
	db_port="27017"
fi

if [ "$core_port" == "" ] ; then
	core_port="8081"
fi

if [ "$pub_fqdn" == "" ] ; then
	pub_fqdn="localhost"
fi

if [ "$pub_url" == "" ] ; then
	pub_url="http://localhost:${core_port}"
fi
