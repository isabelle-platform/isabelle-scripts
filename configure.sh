#!/bin/bash
# Isabelle project
# This script initializes Isabelle setup and puts configuration
# to files that are easily accessible by other scripts
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
cd "${TOP_DIR}"

. ./lib_header.sh

while test -n "$1" ; do
    case $1 in
        --flavour)
            echo "$2" > "${DISTR_DIR}/.flavour"
            shift 1
            ;;
        --db-port)
            echo "$2" > "${DISTR_DIR}/.db_port"
            shift 1
            ;;
        --core-port)
            echo "$2" > "${DISTR_DIR}/.core_port"
            shift 1
            ;;
        --pub-fqdn)
            echo "$2" > "${DISTR_DIR}/.pub_fqdn"
            shift 1
            ;;
        --pub-url)
            echo "$2" > "${DISTR_DIR}/.pub_url"
            shift 1
            ;;
        --cert-owner)
            echo "$2" > "${DISTR_DIR}/.cert_owner"
            shift 1
            ;;
        --srv-port)
            echo "$2" > "${DISTR_DIR}/.srv_port"
            shift 1
            ;;
        --machine-type)
            echo "$2" > "${DISTR_DIR}/.machine_type"
            shift 1
            ;;
        --server-type)
			echo "$2" > "${DISTR_DIR}/.server_type"
            shift 1
            ;;
        --no-cert)
			echo "$2" > "${DISTR_DIR}/.no_cert"
            shift 1
            ;;
        --no-fw)
			echo "$2" > "${DISTR_DIR}/.no_fw"
            shift 1
            ;;
        *)
			fail "Unknown command: $1"
			;;
    esac
    shift 1
done
