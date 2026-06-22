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
        --db)
            echo "$2" > "${DISTR_DIR}/.db"
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
        --cookie-http-insecure)
            echo "$2" > "${DISTR_DIR}/.cookie_http_insecure"
            shift 1
            ;;
        --no-serve-root)
            echo "$2" > "${DISTR_DIR}/.no_serve_root"
            shift 1
            ;;
        --coreenv-file)
            # Runtime secrets for the core + the protostar CLI it spawns
            # (DIGITALOCEAN_TOKEN, STRIPE_*, MIDAIR_IPA_*). The operator points
            # this at a filled-in env file (same format as protostar-cfgs/.env);
            # we stash it outside the tarball so it survives in-place updates.
            # deploy.sh installs it next to the protostar config and run.sh
            # sources it.
            cp "$2" "${DISTR_DIR}/.coreenv" || fail "Cannot read env file: $2"
            chmod 600 "${DISTR_DIR}/.coreenv"
            shift 1
            ;;
        --releases-user)
            echo "$2" > "${DISTR_DIR}/.releases_user"
            chmod 600 "${DISTR_DIR}/.releases_user"
            shift 1
            ;;
        --releases-password)
            echo "$2" > "${DISTR_DIR}/.releases_password"
            chmod 600 "${DISTR_DIR}/.releases_password"
            shift 1
            ;;
        *)
            fail "Unknown command: $1"
            ;;
    esac
    shift 1
done
