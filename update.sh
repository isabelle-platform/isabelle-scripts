#!/bin/bash
# Isabelle project
# This script updates existing installation in place.

TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

user=""
password=""

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
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

if [ "${user}" == "" ] || [ "${password}" == "" ] ; then
    read -p "Releases user: " user
    read -p "Releases password: " password
fi

url_release_equestrian="https://releases.interpretica.io/isabelle-equestrian-release/main-latest/equestrian-main-latest.tar.xz"
url_release_intranet="https://releases.interpretica.io/isabelle-intranet-release/main-latest/intranet-main-latest.tar.xz"

case "$flavour" in
    equestrian)
        target_release="$url_release_equestrian"
        ;;
    intranet)
        target_release="$url_release_intranet"
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

${TOP_DIR}/service.sh start || fail "Failed to start service"
