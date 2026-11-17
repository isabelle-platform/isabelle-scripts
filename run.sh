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

	# Cores before 2.1.0 reject --cors-origin (they allowed every origin
	# anyway), so pass it only when the shipped run.sh knows it.
	local cors_origin_args=""
	if grep -q -- '--cors-origin' "${DISTR_DIR}/distr/core/run.sh" 2> /dev/null ; then
		local origin
		for origin in ${cors_origins} ; do
			cors_origin_args="${cors_origin_args} --cors-origin ${origin}"
		done
	fi

	echo ./run.sh --port "${core_port}" \
		--pub-url "${pub_url}" \
		--pub-fqdn "${pub_fqdn}" \
		--db-url "mongodb://127.0.0.1:${db_port:-27017}" \
		--database "${db}" \
		--data-path "../../data/raw" \
		${cookie_http_insecure:+--cookie-http-insecure} \
		${update_script_arg} \
		${cors_origin_args}
}

if [ ! -f "${DISTR_DIR}/distr/core/isabelle-gc/.installed" ] ; then
	pushd "${DISTR_DIR}/distr/core/isabelle-gc" > /dev/null
	./install.sh
	popd > /dev/null

	touch "${DISTR_DIR}/distr/core/isabelle-gc/.installed"
fi

cmd_line="$(get_cmd_line)"
export BINARY="./${flavour}-core"

# A home the core can write to, with the user-level bin directory those tools
# install into on the PATH (see setup_core_home in lib_header.sh for why).
setup_core_home "${DISTR_DIR}/home"

# proteos ships the protostar CLI inside the archive (distr/core/protostar);
# point the plugin at it via an absolute path so it resolves regardless of
# the core's cwd. Guarded on the file, so it's a no-op for flavours that
# don't bundle protostar, and doesn't override a value set in the env.
if [ -z "${PROTOSTAR_BIN}" ] && [ -x "${DISTR_DIR}/distr/core/protostar" ] ; then
	export PROTOSTAR_BIN="$(cd "${DISTR_DIR}/distr/core" && pwd -P)/protostar"
fi

# Runtime secrets of the core and its plugins (payment keys, release
# credentials, the provisioner token), given once with
# `configure.sh --coreenv-file`. The file lives outside the tarball, so an
# update never touches it. Read it here, and only here: the core's environment
# has one source.
if [ -f "${DISTR_DIR}/.coreenv" ] ; then
	set -a
	. "${DISTR_DIR}/.coreenv"
	set +a
fi

# protostar config + live fleet state ship under distr/core/protostar-cfgs.
# protostar.yaml is versioned (refreshed on update); state.json is created
# there at runtime and persists across updates (it's never in the tarball).
# Absolute paths so they resolve from the core's cwd. That directory holds the
# orchestrator's settings only: no secret of the core is read from it.
if [ -d "${DISTR_DIR}/distr/core/protostar-cfgs" ] ; then
	cfgs_dir="$(cd "${DISTR_DIR}/distr/core/protostar-cfgs" && pwd -P)"
	if [ -z "${PROTOSTAR_CONFIG}" ] && [ -f "${cfgs_dir}/protostar.yaml" ] ; then
		export PROTOSTAR_CONFIG="${cfgs_dir}/protostar.yaml"
	fi
	if [ -z "${PROTOSTAR_STATE}" ] ; then
		export PROTOSTAR_STATE="${cfgs_dir}/state.json"
	fi
	# Per-host SSH keys protostar generates at provision time. Lives under the
	# (gitignored) keys/ dir so it's never in the tarball and survives updates.
	if [ -z "${PROTOSTAR_KEY_DIR}" ] ; then
		export PROTOSTAR_KEY_DIR="${cfgs_dir}/keys"
	fi
fi

# Core seeds an empty database itself on startup (first-run autodetect),
# so no separate priming pass is needed.
pushd "${DISTR_DIR}/distr/core" > /dev/null
${cmd_line}
popd > /dev/null

exit $?
