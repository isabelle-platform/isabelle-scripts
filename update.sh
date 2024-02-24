#!/bin/bash
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

case "$flavour" in
    equestrian)
        target_data_gen="$url_datagen_equestrian"
        ;;
    intranet)
        target_data_gen="$url_datagen_intranet"
        ;;
    *)
        echo "Unknown flavour: $flavour" >&2
        exit 1
esac

${TOP_DIR}/service.sh stop
