#!/bin/sh
set -eu

root=/opt/nvidia-fallback
library_path="${root}/usr/lib/x86_64-linux-gnu"
export LD_LIBRARY_PATH="${library_path}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

exec "${root}/usr/bin/nvidia-smi" "$@"
