#!/bin/bash
# Isabelle project
# This script runs Isabelle. This script is supposed to be invoked
# from systemd or other service handler.

TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

function get_cmd_line() {
	local update_script_arg=""
	if grep -q -- '--update-script' "${DISTR_DIR}/distr/core/run.sh" 2> /dev/null ; then
		update_script_arg="--update-script ${TOP_DIR}/update-coreenv.sh"
	fi

	echo ./run.sh --port "${core_port}" \
		--pub-url "${pub_url}" \
		--pub-fqdn "${pub_fqdn}" \
		--db-url "mongodb://127.0.0.1:${db_port:-27017}" \
		--database "${db}" \
		--data-path "../../data/raw" \
		${cookie_http_insecure:+--cookie-http-insecure} \
		${update_script_arg}
}

if [ ! -f "${DISTR_DIR}/distr/core/isabelle-gc/.installed" ] ; then
	pushd "${DISTR_DIR}/distr/core/isabelle-gc" > /dev/null
	./install.sh
	popd > /dev/null

	touch "${DISTR_DIR}/distr/core/isabelle-gc/.installed"
fi

cmd_line="$(get_cmd_line)"
export BINARY="./${flavour}-core"

# proteos ships the protostar CLI inside the archive (distr/core/protostar);
# point the plugin at it via an absolute path so it resolves regardless of
# the core's cwd. Guarded on the file, so it's a no-op for flavours that
# don't bundle protostar, and doesn't override a value set in the env.
if [ -z "${PROTOSTAR_BIN}" ] && [ -x "${DISTR_DIR}/distr/core/protostar" ] ; then
	export PROTOSTAR_BIN="$(cd "${DISTR_DIR}/distr/core" && pwd -P)/protostar"
fi

# Core seeds an empty database itself on startup (first-run autodetect),
# so no separate priming pass is needed.
pushd "${DISTR_DIR}/distr/core" > /dev/null
${cmd_line}
popd > /dev/null

exit $?
