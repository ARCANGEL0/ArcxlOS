#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${ROOT_DIR}/bin/lib/common.sh"

EDITION=""
BUILD_ALL=0
STAGE=1

for arg in "$@"; do
  case "${arg}" in
    --home|--gaming|--fallen|--netinstall)
      EDITION="${arg#--}"
      ;;
    --all)
      BUILD_ALL=1
      ;;
    --no-stage)
      STAGE=0
      ;;
    -h|--help)
      ax_usage
      exit 0
      ;;
    "")
      ;;
    *)
      printf '[-] Unknown argument: %s\n\n' "${arg}" >&2
      ax_usage >&2
      exit 1
      ;;
  esac
done

if [ -z "${EDITION}" ] && [ "${BUILD_ALL}" -eq 0 ]; then
  ax_usage
  exit 1
fi

if [ "${BUILD_ALL}" -eq 1 ] && [ -n "${EDITION}" ]; then
  ax_die "--all cannot be combined with a single edition flag."
fi

ax_check_env

if [ "${BUILD_ALL}" -eq 1 ]; then
  for e in "${AX_EDITIONS[@]}"; do
    ax_check_edition "${e}"
  done
  for e in "${AX_EDITIONS[@]}"; do
    ax_build "${e}" "${STAGE}"
  done
else
  ax_check_edition "${EDITION}"
  ax_build "${EDITION}" "${STAGE}"
fi
