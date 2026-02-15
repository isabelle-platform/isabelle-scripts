#!/bin/bash
# Isabelle project
# This script runs database system to carry user data.
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

action="$1"
container_name="isabelle-${flavour}-db"

if [ "$db" != "mongo" ] ; then
    echo "Database is managed externally"
    exit 0
fi

case "$action" in
    start)
        docker run --restart=always \
                   -p "127.0.0.1:${db_port}:27017" \
                   --name "${container_name}" \
                   -v "${DISTR_DIR}/data/database:/data/db" \
                   -d \
                   mongo:7.0
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
