#!/bin/bash
# Isabelle project
# Thin wrapper invoked by core (POST /system/update) so that the
# --update-script value is a single token without spaces.
TOP_DIR="$(cd "$(dirname "$(which "$0")")" ; pwd -P)"
exec "${TOP_DIR}/update.sh" --coreenv
