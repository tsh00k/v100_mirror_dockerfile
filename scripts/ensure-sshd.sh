#!/bin/sh
set -eu

config="${SSHD_CONFIG:-/etc/ssh/sshd_config_v100}"

install -d -m 0755 /run/sshd
ssh-keygen -A
/usr/sbin/sshd -t -f "${config}"

if [ "${1:-}" = "--validate-only" ]; then
  exit 0
fi

if ! pgrep -x sshd >/dev/null 2>&1; then
  /usr/sbin/sshd -f "${config}"
fi
