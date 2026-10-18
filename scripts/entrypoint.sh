#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /run/sshd
ssh-keygen -A

if [[ "${1:-}" == "/usr/sbin/sshd" ]]; then
  /usr/sbin/sshd -t -f /etc/ssh/sshd_config_v100
fi

exec "$@"

