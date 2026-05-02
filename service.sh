#!/bin/bash
# Isabelle project
# This script controls the service associated with the backend.
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

action="$1"
service_name="isabelle-${flavour}"

systemctl "${action}" "${service_name}"

if [ -d extras/systemd ] ; then
	for unit_src in extras/systemd/*.service ; do
		[ -f "${unit_src}" ] || continue
		unit_name="$(basename "${unit_src}")"
		systemctl "${action}" "${unit_name}"
	done
fi

if [ -d extras/service ] ; then
	for file in $(ls extras/service/*) ; do
		TOP_DIR="${TOP_DIR}" "$file" "${action}"
	done
fi

exit "$?"
