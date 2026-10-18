#!/bin/sh
set -eu

config="${SSHD_CONFIG:-/etc/ssh/sshd_config_v100}"
has_config=false

for argument in "$@"; do
  case "${argument}" in
    -f|-f*) has_config=true ;;
  esac
done

if [ "${has_config}" = false ]; then
  set -- -f "${config}" "$@"
fi

exec /usr/sbin/sshd "$@"
