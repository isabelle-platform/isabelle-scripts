#!/bin/bash
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

read -p "Releases user: " user
read -p "Releases password: " password

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

pushd ${DISTR_DIR} > /dev/null

rm distr/core/isabelle-gc/.installed > /dev/null 2> /dev/null

touch wget_tmp
chmod 600 wget_tmp
echo "user=$user" > wget_tmp
echo "password=$password" >> wget_tmp
WGETRC=./wget_tmp wget "${target_release}" -o release.tar.xz || fail "Failed to download release"
${TOP_DIR}/service.sh stop || fail "Failed to stop service"
tar xvf release.tar.xz
rm release.tar.xz
rm wget_tmp

popd > /dev/null

${TOP_DIR}/service.sh start || fail "Failed to start service"
