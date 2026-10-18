#!/usr/bin/env bash
set -Eeuo pipefail

command_name="${1:-}"
command_name="${command_name##*/}"

if [[ "${command_name}" == "sshd" ]]; then
  /usr/local/sbin/ensure-sshd --validate-only
else
  /usr/local/sbin/ensure-sshd
fi

exec "$@"

