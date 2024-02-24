#!/bin/bash

function fail() {
	echo $@ >&2
	exit 1
}

if [ ! -f ${TOP_DIR}/.in_release ] ; then
	fail "Not in release!"
fi

DISTR_DIR="${TOP_DIR}/.."

if [ ! -d "${DISTR_DIR}/data" ] || [ ! -d "${DISTR_DIR}/distr" ] || [ ! -d "${DISTR_DIR}/.flavour" ] ; then
	fail "Doesn't look like distribution directory"
fi

flavour="$(cat ${DISTR_DIR}/.flavour)"
db_port="$(cat ${DISTR_DIR}/.db_port)"
core_port="$(cat ${DISTR_DIR}/.core_port)"
pub_fqdn="$(cat ${DISTR_DIR}/.pub_fqdn)"
pub_url="$(cat ${DISTR_DIR}/.pub_url)"

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
