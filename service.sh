#!/bin/bash
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

action="$1"
service_name="isabelle-${flavour}"

systemctl "${action}" "${service_name}"

exit "$?"
