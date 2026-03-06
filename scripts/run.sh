#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

# Keep caches inside repo to reduce environment-specific path/permission issues.
export CLANG_MODULE_CACHE_PATH="${REPO_ROOT}/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${REPO_ROOT}/.build/swiftpm-module-cache"
mkdir -p "${CLANG_MODULE_CACHE_PATH}" "${SWIFTPM_MODULECACHE_OVERRIDE}"

LOG_FILE="$(mktemp -t skillsmaster-run.XXXXXX.log)"
cleanup() {
  rm -f "${LOG_FILE}"
}
trap cleanup EXIT

run_once() {
  set +e
  swift run SkillsMaster 2>&1 | tee "${LOG_FILE}"
  local status=${PIPESTATUS[0]}
  set -e
  return "${status}"
}

matches_log() {
  local pattern="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -q "${pattern}" "${LOG_FILE}"
  else
    grep -Eq "${pattern}" "${LOG_FILE}"
  fi
}

if run_once; then
  exit 0
fi

if matches_log "PCH was compiled with module cache path|compiled with module cache path .* currently"; then
  echo ""
  echo "[skillsmaster/run] Detected stale module cache from a moved/renamed project path."
  echo "[skillsmaster/run] Cleaning .build and retrying once..."
  rm -rf "${REPO_ROOT}/.build"
  swift package clean >/dev/null 2>&1 || true
  run_once
  exit $?
fi

if matches_log "this SDK is not supported by the compiler|could not build Objective-C module 'SwiftShims'"; then
  echo ""
  echo "[skillsmaster/run] Detected Swift toolchain/SDK mismatch."
  echo "[skillsmaster/run] Try aligning Xcode/CommandLineTools, then run again:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

exit 1
