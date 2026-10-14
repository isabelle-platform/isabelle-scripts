#!/bin/bash
# Isabelle project
# This script hardens the host an installation runs on.
#
# What it puts in place is the floor every machine on the internet needs and
# that a stock cloud image does not quite give:
#
#   * security updates, applied unattended;
#   * sshd: keys only, and root by key only;
#   * fail2ban on sshd, with repeat offenders banned for a week;
#   * the ports Docker publishes kept off the network.
#
# The last one is the reason this is more than a checklist. Docker writes its
# own iptables rules ahead of ufw's, so a container published as `5672:5672`
# is reachable from anywhere however tightly ufw is set — and a firewall
# status that says "22, 80, 443" is then simply untrue. DOCKER-USER is the
# chain Docker leaves for this: new connections that arrive on a real network
# interface and are bound for a container are dropped there. Containers reach
# each other over their bridges and the host reaches them over loopback, and
# neither crosses a real interface; a reply to a connection a container made
# is not new.
#
# Which ports are open is not this script's business. Whoever serves on a
# port opens it — deploy.sh opens 80 and 443, protostar's install.sh its API
# port to one host — and nothing here adds or removes a ufw rule.
#
# Safe to run again, and cheap when there is nothing to do: deploy.sh runs it
# once, and service.sh on every start, which is how a release that changes it
# reaches the machines already running.
#
# Every part is attempted even when another fails, and the exit status says
# whether all of them took. A host is never left worse off: an sshd drop-in
# that sshd refuses is taken back out before anything reloads.
#
# Usage: harden.sh [--trust <address or CIDR>]...
#   --trust  never banned by fail2ban; for the hosts that manage this one.

HARDEN_VERSION="1"

STATE_DIR="/var/lib/isabelle-harden"
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-isabelle-harden.conf"
F2B_JAIL="/etc/fail2ban/jail.d/isabelle-harden.local"
AUTO_UPGRADES="/etc/apt/apt.conf.d/20auto-upgrades"
FENCE_BIN="/usr/local/sbin/isabelle-docker-fence"
FENCE_UNIT="/etc/systemd/system/isabelle-docker-fence.service"

# Waiting for the dpkg lock rather than failing on it, but not for long: this
# runs on every service start, and a start that waits ten minutes behind an
# unattended upgrade is worse than a hardening step put off until the next.
APT_OPTS="-o DPkg::Lock::Timeout=120"

trusted=""
while [ "$#" -gt 0 ] ; do
	case "$1" in
		--trust)
			[ -n "${2:-}" ] || { echo "harden: --trust needs an address" >&2 ; exit 2 ; }
			trusted="${trusted} $2"
			shift 2
			;;
		*)
			echo "harden: unknown argument: $1" >&2
			exit 2
			;;
	esac
done

if [ "$(id -u)" != "0" ] ; then
	echo "harden: must run as root" >&2
	exit 2
fi

failed=""

function say() {
	echo "harden: $*"
}

# The first word names the part, for the summary and the state file.
function warn() {
	local part="$1"
	shift
	echo "harden: WARNING: ${part}: $*" >&2
	failed="${failed} ${part}"
}

# Write a file only when its contents differ, and say whether it did — so the
# caller restarts a service because something changed, not every time.
function put_file() {
	local path="$1"
	local mode="$2"
	local content="$3"

	if [ -f "${path}" ] && [ "$(cat "${path}")" == "${content}" ] ; then
		return 1
	fi
	mkdir -p "$(dirname "${path}")"
	printf '%s\n' "${content}" > "${path}.harden-new" || return 2
	chmod "${mode}" "${path}.harden-new"
	mv -f "${path}.harden-new" "${path}"
	return 0
}

function have_pkg() {
	dpkg-query -W -f='${Status}' "$1" 2> /dev/null | grep -q "install ok installed"
}

function ensure_pkgs() {
	local missing=""
	local p
	for p in "$@" ; do
		have_pkg "${p}" || missing="${missing} ${p}"
	done
	[ -z "${missing}" ] && return 0

	say "installing${missing}"
	export DEBIAN_FRONTEND=noninteractive
	# shellcheck disable=SC2086 # APT_OPTS and missing are word lists
	apt-get ${APT_OPTS} install -y --no-install-recommends ${missing} > /dev/null ||
		{ apt-get ${APT_OPTS} update > /dev/null &&
		  apt-get ${APT_OPTS} install -y --no-install-recommends ${missing} > /dev/null ; }
}

# ---------------------------------------------------------------------------
# Security updates
# ---------------------------------------------------------------------------
#
# Ubuntu's own 50unattended-upgrades already limits itself to the security
# pocket; what can be missing is the package, or the switch that runs it.
# No automatic reboot: a kernel waiting for one is something to report, and
# taking a customer's machine down at night without a word is not.
function harden_updates() {
	command -v apt-get > /dev/null 2>&1 || { say "updates: not a Debian-family host, skipped" ; return 0 ; }

	ensure_pkgs unattended-upgrades || { warn updates "cannot install unattended-upgrades" ; return ; }

	put_file "${AUTO_UPGRADES}" 644 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";'
	case "$?" in
		0) say "updates: security updates switched on" ;;
		2) warn updates "cannot write ${AUTO_UPGRADES}" ; return ;;
	esac
	systemctl enable --now unattended-upgrades > /dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# sshd
# ---------------------------------------------------------------------------
#
# A drop-in, not an edit of sshd_config. sshd keeps the first value it reads
# for each keyword, and Ubuntu includes sshd_config.d at the very top of the
# main file — so `00-` here wins over both the main file's `PermitRootLogin
# yes` and cloud-init's `50-` drop-in, without touching either.
#
# Match blocks are not affected: a flavour that needs password logins for one
# local user (bublik's, for docker exec) keeps its own `Match User` block.
#
# Root keeps logging in by key, because that is how protostar and the
# operators reach the machine; what goes is root by password.
function harden_sshd() {
	if [ ! -d /etc/ssh/sshd_config.d ] || ! command -v sshd > /dev/null 2>&1 ; then
		say "sshd: not installed, skipped"
		return 0
	fi
	if ! grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config ; then
		warn sshd "sshd_config does not include sshd_config.d; left as it is"
		return
	fi

	put_file "${SSHD_DROPIN}" 644 '# Written by isabelle-scripts/harden.sh; rewritten on every run.
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
X11Forwarding no'
	case "$?" in
		1) return 0 ;;
		2) warn sshd "cannot write ${SSHD_DROPIN}" ; return ;;
	esac

	# The one step here that could lock everybody out, so it is checked
	# before anything reloads, and taken back if sshd will not have it.
	if ! sshd -t > /dev/null 2>&1 ; then
		rm -f "${SSHD_DROPIN}"
		warn sshd "rejected the drop-in; removed it, sshd left as it was"
		return
	fi
	if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd ; then
		systemctl reload ssh > /dev/null 2>&1 ||
			systemctl reload sshd > /dev/null 2>&1 ||
			warn sshd "cannot reload sshd; the drop-in applies from its next start"
	fi
	say "sshd: keys only, root by key only"
}

# ---------------------------------------------------------------------------
# fail2ban
# ---------------------------------------------------------------------------
#
# sshd from the journal, which is where it logs on a current Ubuntu, and
# `recidive` on fail2ban's own log for addresses that keep coming back after
# their hour is up. The ban goes in front of ufw's rules, so it holds whatever
# ufw allows.
#
# `aggressive`, because the default mode is written for a server that takes
# passwords. Once it does not, a guess at an existing account is logged as
# "Connection closed by authenticating user ... [preauth]" and never as
# "Failed password", and the default mode lets all of those through: tried
# against bob six times, it counted one. A legitimate client that authenticates
# never leaves that line behind, so nothing that gets in is counted.
function harden_fail2ban() {
	command -v apt-get > /dev/null 2>&1 || { say "fail2ban: not a Debian-family host, skipped" ; return 0 ; }

	# nftables because Ubuntu's own jail defaults ban through `nft`. Without
	# it a ban is recorded and blocks nothing — fail2ban reports the address
	# as banned while it carries on connecting.
	ensure_pkgs fail2ban python3-systemd nftables || { warn fail2ban "cannot install fail2ban" ; return ; }

	put_file "${F2B_JAIL}" 644 "# Written by isabelle-scripts/harden.sh; rewritten on every run.
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1${trusted}
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
mode = aggressive

[recidive]
enabled = true
backend = auto
bantime = 1w
findtime = 1d
maxretry = 5"
	local changed="$?"
	[ "${changed}" == "2" ] && { warn fail2ban "cannot write ${F2B_JAIL}" ; return ; }

	systemctl enable fail2ban > /dev/null 2>&1 || true
	if [ "${changed}" == "0" ] || ! systemctl is-active --quiet fail2ban ; then
		systemctl restart fail2ban > /dev/null 2>&1 ||
			{ warn fail2ban "does not start: $(journalctl -u fail2ban -n 3 --no-pager -o cat 2> /dev/null | tr '\n' ' ')" ; return ; }
	fi
	say "fail2ban: sshd and recidive"
}

# ---------------------------------------------------------------------------
# Docker's published ports
# ---------------------------------------------------------------------------
#
# A unit rather than a rule added once: the rules live in the kernel, so they
# are gone after a reboot, and the unit puts them back every time Docker
# starts. Interfaces are listed when it runs, which on a cloud machine means
# the public one and the private network both.
function harden_docker() {
	if ! command -v docker > /dev/null 2>&1 || ! command -v iptables > /dev/null 2>&1 ; then
		say "docker: not installed, nothing to fence"
		return 0
	fi

	put_file "${FENCE_BIN}" 755 '#!/bin/sh
# Written by isabelle-scripts/harden.sh; rewritten on every run.
#
# Drops new connections that arrive on a real network interface bound for a
# container. Docker publishes ports ahead of ufw; this is the chain it leaves
# for saying otherwise. Loopback, Docker'"'"'s own bridges and the veth pairs
# behind them are not real interfaces, and replies are not new connections.
set -u
iptables -N DOCKER-USER 2> /dev/null || true
status=0
for dev in $(ip -o link show | awk -F": " "{print \$2}" | cut -d@ -f1) ; do
	case "${dev}" in
		lo|docker*|br-*|veth*) continue ;;
	esac
	iptables -C DOCKER-USER -i "${dev}" -m conntrack --ctstate NEW -j DROP 2> /dev/null ||
		iptables -I DOCKER-USER -i "${dev}" -m conntrack --ctstate NEW -j DROP || status=1
done
exit "${status}"'
	[ "$?" == "2" ] && { warn docker "cannot write ${FENCE_BIN}" ; return ; }

	put_file "${FENCE_UNIT}" 644 "# Written by isabelle-scripts/harden.sh; rewritten on every run.
[Unit]
Description=Keep the ports Docker publishes off the network
After=docker.service
PartOf=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${FENCE_BIN}

[Install]
WantedBy=docker.service"
	case "$?" in
		0) systemctl daemon-reload ;;
		2) warn docker "cannot write ${FENCE_UNIT}" ; return ;;
	esac

	systemctl enable isabelle-docker-fence > /dev/null 2>&1 || true
	# Run now as well, not only when Docker next starts: the containers
	# already published are the ones this is for.
	if systemctl is-active --quiet docker ; then
		systemctl restart isabelle-docker-fence > /dev/null 2>&1 ||
			{ warn docker "the fence did not apply" ; return ; }
	fi
	say "docker: published ports kept off the network"
}

harden_updates
harden_sshd
harden_fail2ban
harden_docker

mkdir -p "${STATE_DIR}"
{
	echo "version=${HARDEN_VERSION}"
	echo "applied_at=$(date -Is)"
	echo "failed=${failed# }"
} > "${STATE_DIR}/state"

if [ -n "${failed}" ] ; then
	echo "harden: done, except:${failed}" >&2
	exit 1
fi
say "done"
exit 0
