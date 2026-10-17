#!/bin/bash
# Isabelle project
# Fast, hermetic test of setup_core_home (lib_header.sh): the writable home the
# core needs so the AI assistants' CLIs have somewhere to install. No network,
# no service, no root required.

set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LIB="${SELF_DIR}/../lib_header.sh"

fails=0
check() { # desc, expected, actual
	if [ "$2" = "$3" ] ; then
		echo "ok   - $1"
	else
		echo "FAIL - $1"
		echo "       expected: [$2]"
		echo "       actual:   [$3]"
		fails=$((fails + 1))
	fi
}

# A minimal tree that satisfies lib_header.sh's distribution guards, so we can
# source the real file and exercise the real function.
root="$(mktemp -d)"
trap 'chmod -R u+rwx "${root}" 2> /dev/null; rm -rf "${root}"' EXIT
mkdir -p "${root}/distr/data/raw" "${root}/distr/distr/core" "${root}/distr/scripts"
touch "${root}/distr/.flavour" "${root}/distr/scripts/.in_release"

TOP_DIR="${root}/distr/scripts"
. "${LIB}"   # defines setup_core_home; DISTR_DIR becomes ${root}/distr

# 1. A writable base: HOME moves into the installation and ~/.local/bin leads PATH.
(
	export HOME="/original/home" PATH="/usr/bin:/bin"
	setup_core_home "${DISTR_DIR}/home"
	check "writable: HOME is the install home" "${DISTR_DIR}/home" "${HOME}"
	check "writable: PATH leads with ~/.local/bin" "${DISTR_DIR}/home/.local/bin:/usr/bin:/bin" "${PATH}"
	check "writable: the home was created" "yes" "$([ -d "${DISTR_DIR}/home" ] && echo yes || echo no)"
)

# 2. An uncreatable base (a file sits where a path component must be a dir):
#    HOME and PATH are left exactly as inherited, for every uid including root.
touch "${root}/blocked"
(
	export HOME="/original/home" PATH="/usr/bin:/bin"
	setup_core_home "${root}/blocked/home"
	check "unwritable: HOME is left untouched" "/original/home" "${HOME}"
	check "unwritable: PATH is left untouched" "/usr/bin:/bin" "${PATH}"
)

# 3. setup_core_home never aborts the caller, whatever happened.
setup_core_home "${root}/blocked/home" ; rc=$?
check "never fatal (returns 0)" "0" "${rc}"

echo
if [ "${fails}" -eq 0 ] ; then
	echo "core-home: all checks passed"
	exit 0
fi
echo "core-home: ${fails} check(s) failed"
exit 1
