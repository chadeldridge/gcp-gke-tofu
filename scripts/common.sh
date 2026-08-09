#!/usr/bin/env bash
# Shared helpers for scripts/*.sh. Source this, don't execute it directly.

DEBUG="${DEBUG:-false}"

log()  { echo "==> $*"; }
dbg()  { [[ "$DEBUG" == "true" ]] && echo "    [dbg] $*" >&2 || true; }
die()  { echo "ERROR: $*" >&2; exit 1; }

# Get an output value from terragrunt in the current directory.
tg_get() { terragrunt output -raw "$1"; }

# Print and run a command (command visible only in debug mode).
run() {
  dbg "$ $*"
  "$@"
}

# Run a command with a hard timeout (first arg = seconds).
# Prints the timeout and command in debug mode, always errors clearly on timeout.
timed() {
  local secs="$1"; shift
  dbg "$ (timeout ${secs}s) $*"
  local code=0
  # Capture exit code via || to avoid the `if ! cmd` bash gotcha where $?
  # inside an if-negation block reflects the inverted status (always 0).
  timeout "${secs}" "$@" || code=$?
  # exit code 124 is the timeout sentinel from GNU timeout
  [[ $code -eq 124 ]] && die "Command timed out after ${secs}s: $*"
  return $code
}

require() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is not installed or not on PATH"
  done
}

# Track wall-clock time for each named phase.
_PHASE_T0=""
phase_start() {
  log "$*"
  _PHASE_T0=$(date +%s)
}
phase_end() {
  local elapsed=$(( $(date +%s) - _PHASE_T0 ))
  dbg "Phase completed in ${elapsed}s"
}
