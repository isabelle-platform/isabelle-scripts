#!/bin/bash
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"

. ./lib_header.sh

action="$1"
container_name="isabelle-${flavour}-db"

case "$action" in
    start)
        docker run --restart=always \
                   -p "127.0.0.1:${db_port}:27017" \
                   --name "${container_name}" \
                   -v "${DISTR_DIR}/data/database:/data/db" \
                   -d \
                   mongo
        exit $?
        ;;
    stop)
        docker stop "${container_name}"
        docker rm "${container_name}"
        exit 0
        ;;
    *)
        fail "Unknown command: ${action}"
        ;;
esac
