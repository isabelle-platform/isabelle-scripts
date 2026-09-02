#!/bin/bash
# Isabelle project
#
# Run a self-update the core asked for.
#
# Started by `isabelle-update-<flavour>.path` when the core writes a request
# file. The core runs as an ordinary user and cannot stop a service, replace a
# distribution or start it again; this can, and is root for exactly that.
#
# Which makes the request file untrusted input. The core is the process
# answering anonymous HTTP, so what it writes is checked here rather than
# believed: an archive must be a regular file in this installation's own
# platform directory, and a version must look like a version. Nothing from the
# request reaches a shell unquoted, and nothing selects the script that runs —
# that is always this installation's `update.sh`.
#
# The request is removed before the update starts, so a failed update does not
# loop: the path unit fires on the file existing.

# Deliberately not `set -e`: lib_header.sh reads optional marker files, and a
# missing `.db_port` on a perfectly good installation would abort the update
# before it started. Every step below is checked in as many words instead.
set -o pipefail

TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

request="${DISTR_DIR}/data/raw/platform/update-request"
log="${DISTR_DIR}/data/raw/platform/update.log"

[ -f "${request}" ] || { echo "update-runner: no request" >&2; exit 0; }

archive=""
version=""

# Read as data: two known keys, one value each, and anything else ignored.
# `source` would run it, which is precisely what must not happen to a file the
# core can write.
while IFS='=' read -r key value ; do
	case "${key}" in
		archive) archive="${value}" ;;
		version) version="${value}" ;;
		*) ;;
	esac
done < "${request}"

# Taken away first: the path unit triggers on this file being there, and an
# update that fails must not start another one.
rm -f "${request}"

function refuse() {
	echo "update-runner: refusing: $*" >&2
	echo "$(date -u +%FT%TZ) update-runner refused: $*" >> "${log}" 2>/dev/null || true
	exit 1
}

case "${version}" in
	"") refuse "no version in the request" ;;
	*[!A-Za-z0-9._-]*) refuse "version '${version}' is not a version" ;;
esac

[ -n "${archive}" ] || refuse "no archive in the request"

# The archive must be one this installation downloaded. Resolved first, so
# that a path with `..` in it is judged by where it lands and not by how it is
# spelled.
platform_dir="$(cd "${DISTR_DIR}/data/raw/platform" 2> /dev/null && pwd -P)" \
	|| refuse "no platform directory"
archive_real="$(readlink -f "${archive}" 2> /dev/null || true)"
[ -n "${archive_real}" ] || refuse "archive '${archive}' does not resolve"
[ -f "${archive_real}" ] || refuse "archive '${archive}' is not a file"
case "${archive_real}" in
	"${platform_dir}/"*) ;;
	*) refuse "archive '${archive_real}' is outside ${platform_dir}" ;;
esac

echo "$(date -u +%FT%TZ) update-runner starting ${version} from ${archive_real}" >> "${log}"
exec "${TOP_DIR}/update.sh" --archive "${archive_real}" --version "${version}" >> "${log}" 2>&1
