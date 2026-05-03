#!/bin/bash
# Isabelle project
# This script updates existing installation in place.

TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

user=""
password=""
coreenv=""

while test -n "$1" ; do
    case $1 in
        --user)
            user="$2"
            shift 1
            ;;
        --password)
            password="$2"
            shift 1
            ;;
        --coreenv)
            coreenv="y"
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
    shift 1
done

if [ "${coreenv}" == "y" ]; then
    if [ "${user}" == "" ] && [ -f "${DISTR_DIR}/.releases_user" ]; then
        user="$(cat "${DISTR_DIR}/.releases_user")"
    fi
    if [ "${password}" == "" ] && [ -f "${DISTR_DIR}/.releases_password" ]; then
        password="$(cat "${DISTR_DIR}/.releases_password")"
    fi
    if [ "${user}" == "" ] || [ "${password}" == "" ]; then
        fail "Releases credentials not found in core environment"
    fi
fi

if [ "${user}" == "" ] || [ "${password}" == "" ] ; then
    read -p "Releases user: " user
    read -p "Releases password: " password
fi

url_release_equestrian="https://releases.interpretica.io/isabelle-equestrian-release/main-latest/equestrian-main-latest.tar.xz"
url_release_sample="https://releases.interpretica.io/isabelle-sample-release/main-latest/sample-main-latest.tar.xz"
url_release_intranet="https://releases.interpretica.io/isabelle-intranet-release/main-latest/intranet-main-latest.tar.xz"
url_release_cloudcpe="https://releases.interpretica.io/isabelle-cloudcpe-release/main-latest/cloudcpe-main-latest.tar.xz"
url_release_didactist="https://releases.interpretica.io/isabelle-didactist-release/main-latest/didactist-main-latest.tar.xz"
url_release_midair="https://releases.interpretica.io/isabelle-midair-release/main-latest/midair-main-latest.tar.xz"

case "$flavour" in
    equestrian)
        target_release="$url_release_equestrian"
        ;;
    sample)
        target_release="$url_release_sample"
        ;;
    intranet)
        target_release="$url_release_intranet"
        ;;
    cloudcpe)
        target_release="$url_release_cloudcpe"
        ;;
    didactist)
        target_release="$url_release_didactist"
        ;;
    midair)
        target_release="$url_release_midair"
        ;;
    *)
        echo "Unknown flavour: $flavour" >&2
        exit 1
esac

pushd "${DISTR_DIR}" > /dev/null

rm distr/core/isabelle-gc/.installed > /dev/null 2> /dev/null

touch wget_tmp
chmod 600 wget_tmp
echo "user=$user" > wget_tmp
echo "password=$password" >> wget_tmp
WGETRC=./wget_tmp wget "${target_release}" -O release.tar.xz || fail "Failed to download release"
${TOP_DIR}/service.sh stop || fail "Failed to stop service"
rm -rf distr/ui
tar xvf release.tar.xz
rm release.tar.xz
rm wget_tmp

popd > /dev/null

chown -R www-data:www-data "${DISTR_DIR}"

# Re-apply install-time extras hooks: the tarball just overwrote distr/ and
# data/raw/, so any data the hooks injected (e.g. bublik_ui_url, SSH creds in
# data/raw/settings.js) needs to be re-applied before the core starts and
# snapshots its data again.
if [ -d "${TOP_DIR}/extras/deploy" ] ; then
	for file in $(ls "${TOP_DIR}/extras/deploy"/*.sh 2> /dev/null) ; do
		TOP_DIR="${TOP_DIR}" "$file" || fail "Extras deploy hook failed: $file"
	done
fi

${TOP_DIR}/service.sh start || fail "Failed to start service"
