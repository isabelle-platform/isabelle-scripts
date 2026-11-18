#!/bin/bash
# Isabelle project
#
# Close the platform to new operations before an update, and reopen it after.
#
# An update stops the service in the middle of whatever it is doing. The core
# counts the operations its plugins declare; this asks it to close at the
# first moment none is running, and waits for it to say it has. A flavour
# whose plugins declare none is closed at once: there the wait holds nothing.
#
#   maintenance.sh begin [--minutes N] [--wait-hours N]
#       0  closed: nothing is running and nothing new is taken. Go on.
#       0  nothing here answers such a request (no such platform, or the
#          service is down). There is nothing to wait for. Go on.
#       3  the wait for a quiet moment ran out; the platform stayed open.
#   maintenance.sh end
#       reopen, as soon as the platform is up to read it. The platform also
#       reopens by itself after the minutes it was closed for, so a failed
#       update cannot leave it closed.
#   maintenance.sh status
#
# The two sides talk through files in data/raw/platform: this writes
# `maintenance-request`, the platform takes it within a second and keeps
# `maintenance.json` up to date. Files, because this runs as root from a
# deploy and cannot sign in.

TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

PLATFORM_DIR="${DISTR_DIR}/data/raw/platform"
REQUEST="${PLATFORM_DIR}/maintenance-request"
STATE="${PLATFORM_DIR}/maintenance.json"

# How long the request may lie there before it is plain that nobody reads it.
TAKEN_WITHIN=30
# How often to look at the state, in seconds.
LOOK_EVERY=10

action="$1"
shift 1
minutes=""
wait_hours=""
while test -n "$1" ; do
	case $1 in
		--minutes)
			minutes="$2"
			shift 1
			;;
		--wait-hours)
			wait_hours="$2"
			shift 1
			;;
		*)
			fail "Unknown argument: $1"
			;;
	esac
	shift 1
done

# One field of the state file. It is written by the platform as one
# `"key": "value"` per line; a file that is missing or half there gives
# nothing, which every caller reads as "open".
function field() {
	sed -n 's/^ *"'"$1"'": *"\{0,1\}\([^",]*\)"\{0,1\},\{0,1\} *$/\1/p' "${STATE}" 2> /dev/null | head -n 1
}

# Leave a request. Written beside and renamed into place, so the platform
# never reads half of it; readable by the service's user, which removes it.
function ask() {
	if [ ! -d "${PLATFORM_DIR}" ] ; then
		mkdir -p "${PLATFORM_DIR}" || return 1
		# The service's, like the directory it is in: the platform removes
		# the request and writes its state there.
		chown --reference="${DISTR_DIR}/data/raw" "${PLATFORM_DIR}" 2> /dev/null
	fi
	local tmp="${REQUEST}.tmp"
	echo "action=$1" > "${tmp}" || return 1
	if [ -n "${minutes}" ] ; then
		echo "minutes=${minutes}" >> "${tmp}"
	fi
	if [ -n "${wait_hours}" ] ; then
		echo "wait_hours=${wait_hours}" >> "${tmp}"
	fi
	chmod 644 "${tmp}"
	mv "${tmp}" "${REQUEST}"
}

# Wait for the platform to take the request. False when it does not.
function taken() {
	local waited=0
	while [ -f "${REQUEST}" ] ; do
		[ "${waited}" -ge "${TAKEN_WITHIN}" ] && return 1
		sleep 1
		waited=$((waited + 1))
	done
	return 0
}

case "${action}" in
	begin)
		ask begin || fail "Could not write ${REQUEST}"
		if ! taken ; then
			rm -f "${REQUEST}"
			echo "Nothing here took the maintenance request within ${TAKEN_WITHIN} s:" \
				"no platform to wait for, going on." >&2
			exit 0
		fi
		said=""
		while true ; do
			state="$(field state)"
			case "${state}" in
				closed)
					echo "Closed for maintenance: nothing is running." \
						"Reopens by itself at $(field reopen_at)."
					exit 0
					;;
				waiting)
					now="waiting for a quiet moment, until $(field wait_until)"
					if [ "${now}" != "${said}" ] ; then
						echo "Operations are running: ${now}."
						said="${now}"
					fi
					;;
				*)
					note="$(field note)"
					echo "${note:-Not closed.}" >&2
					exit 3
					;;
			esac
			sleep "${LOOK_EVERY}"
		done
		;;
	end)
		# Only where a platform keeps this state: elsewhere a request would
		# lie there for ever.
		[ -f "${STATE}" ] || exit 0
		# Left for the platform to take when it is up: after an update the
		# service is still starting, and a request removed here would leave
		# it closed until its own clock reopens it.
		ask end || fail "Could not write ${REQUEST}"
		;;
	status)
		if [ -f "${STATE}" ] ; then
			cat "${STATE}"
		else
			echo "No maintenance state here: open."
		fi
		;;
	*)
		fail "Usage: maintenance.sh begin [--minutes N] [--wait-hours N] | end | status"
		;;
esac
