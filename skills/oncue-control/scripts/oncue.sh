#!/bin/bash
# Locate the installed App; forward argv and streams without interpreting commands.
set -euo pipefail

fail() {
  printf 'oncue helper: %s\n' "$1" >&2
  exit 127
}

binary=''
if [[ ${ONCUE_BIN+x} ]]; then
  [[ "$ONCUE_BIN" == /* ]] || fail 'ONCUE_BIN must be a trusted absolute executable path.'
  [[ -f "$ONCUE_BIN" && -x "$ONCUE_BIN" ]] || fail 'ONCUE_BIN is not an executable file. Set it to the trusted OnCue binary.'
  binary="$ONCUE_BIN"
else
  [[ "$(/usr/bin/uname -s)" == Darwin ]] || fail 'Automatic discovery supports macOS only. Set ONCUE_BIN to a trusted absolute executable path.'
  candidates=('/Applications/OnCue.app/Contents/MacOS/oncue')
  if [[ ${HOME:-} == /* ]]; then
    candidates+=("$HOME/Applications/OnCue.app/Contents/MacOS/oncue")
  fi
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" && -x "$candidate" ]]; then
      binary="$candidate"
      break
    fi
  done
  [[ -n "$binary" ]] || fail 'OnCue was not found in /Applications or ~/Applications. Install a CLI-capable App or set ONCUE_BIN to its trusted absolute executable path; PATH is not searched.'
fi

# macOS Bash 3.2 treats an empty array as unbound under nounset.
if (( $# == 0 )); then
  exec "$binary"
fi
argv=("$@")
exec "$binary" "${argv[@]}"
