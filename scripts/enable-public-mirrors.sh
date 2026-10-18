#!/usr/bin/env bash

export HF_ENDPOINT=https://hf-mirror.com

github_public_url() {
  if [[ $# -ne 1 || "$1" != https://github.com/* ]]; then
    printf 'usage: github_public_url https://github.com/OWNER/REPO/...\n' >&2
    return 2
  fi

  printf 'https://ghfast.top/%s\n' "$1"
}

printf '%s\n' \
  'HF_ENDPOINT now uses hf-mirror.com for public resources.' \
  'Use github_public_url URL only for public GitHub archives/releases.' \
  'Do not send credentials, private repositories, or gated downloads through either mirror.'

