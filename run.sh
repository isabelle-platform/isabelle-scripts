#!/bin/bash
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

function get_cmd_line() {
	echo ./run.sh --port "${core_port}" \
                  --pub-url "${pub_url}" \
                  --pub-fqdn "${pub_fqdn}" \
                  --data-path "../../data/raw"
}

cmd_line="$(get_cmd_line)"
export BINARY="./${flavour}-core"

if [ -f "${DISTR_DIR}/data/raw/.firstrun" ] ; then
	pushd "${DISTR_DIR}/distr/core" > /dev/null
	FIRST_RUN=y ${cmd_line}
	status="$?"
	popd > /dev/null
	if [ "$status" != "0" ] ; then
		fail "Failed to run Core for the first run: $status"
		exit $status
	fi

	rm "${DISTR_DIR}/data/raw/.firstrun"
fi

pushd "${DISTR_DIR}/distr/core" > /dev/null
${cmd_line}
popd > /dev/null

exit $?
