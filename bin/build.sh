#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

EDITION=""
EXTRA=()
for arg in "$@"; do
  case "${arg}" in
    --no-stage)
      EXTRA+=("${arg}")
      ;;
    home|gaming|fallen|netinstall)
      EDITION="${arg}"
      ;;
    *)
      printf '[-] Unknown argument: %s\n' "${arg}" >&2
      printf '    This shim accepts: [home|gaming|fallen|netinstall] [--no-stage]\n' >&2
      printf '    For the full interface use: ./build.sh --help\n' >&2
      exit 1
      ;;
  esac
done

if [ -z "${EDITION}" ]; then
  printf '[-] No edition given.\n' >&2
  printf '    Usage: %s [home|gaming|fallen|netinstall] [--no-stage]\n' "$0" >&2
  exit 1
fi

printf '[!] scripts/build.sh is deprecated; use ./build.sh --%s instead.\n' "${EDITION}" >&2
exec "${ROOT_DIR}/build.sh" "--${EDITION}" "${EXTRA[@]+"${EXTRA[@]}"}"
