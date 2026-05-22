#!/usr/bin/env bash
# spawn-codex.sh — minimal codex exec wrapper for vibe-map codex loops.
#
# Usage:
#   spawn-codex.sh \
#     --cd <dir> \
#     --prompt <prompt-file> \
#     --log <log-file> \
#     --timeout <seconds> \
#     [--add-dir <dir>]... \
#     [--model <model>] \
#     [--sandbox <mode>] \
#     [--allow-short-timeout]
#
# Intended invocation pattern (Claude Code / agents that support background tasks):
#   - Run via Bash tool with run_in_background: true so the harness gets a
#     task-notification when codex exits. Controller then sweeps the log marker
#     to decide next phase.
#
# Contract:
#   - Prompt is read from a file via stdin (avoids argv length limit).
#   - Output goes to --log. EXIT=<code> and DONE_AT=<ISO8601> footers are
#     appended so controller can post-mortem from the log alone.
#   - Default sandbox is workspace-write (safe for most projects). Override
#     with --sandbox danger-full-access only if the project needs network /
#     external processes during tests, and only for prompts you wrote.
#
# Why timeout >= 3600s by default:
#   Codex implement/refactor jobs routinely take 30-90 min. Shorter timeouts
#   cause codex to be killed mid-edit and inflate rework. Pass
#   --allow-short-timeout to opt out (useful for tiny verification jobs).

set -euo pipefail

CD=""
PROMPT=""
LOG=""
TIMEOUT=""
MODEL=""
SANDBOX="workspace-write"
ALLOW_SHORT=0
ADD_DIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)                   CD="$2"; shift 2;;
    --prompt)               PROMPT="$2"; shift 2;;
    --log)                  LOG="$2"; shift 2;;
    --timeout)              TIMEOUT="$2"; shift 2;;
    --model)                MODEL="$2"; shift 2;;
    --sandbox)              SANDBOX="$2"; shift 2;;
    --add-dir)              ADD_DIRS+=("$2"); shift 2;;
    --allow-short-timeout)  ALLOW_SHORT=1; shift;;
    *)                      echo "unknown flag: $1" >&2; exit 2;;
  esac
done

for var in CD PROMPT LOG TIMEOUT; do
  if [[ -z "${!var}" ]]; then
    flag=$(printf '%s' "$var" | tr '[:upper:]' '[:lower:]')
    echo "missing required flag --${flag}" >&2
    exit 2
  fi
done

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH" >&2
  echo "install: https://github.com/openai/codex" >&2
  exit 127
fi

if [[ ! -f "$PROMPT" ]]; then
  echo "prompt file not found: $PROMPT" >&2
  exit 2
fi

if grep -q '{{[a-zA-Z_]' "$PROMPT"; then
  echo "prompt contains unresolved {{placeholder}} — controller forgot to substitute" >&2
  grep -n '{{[a-zA-Z_]' "$PROMPT" | head -5 >&2
  exit 2
fi

if (( TIMEOUT < 3600 )) && (( ALLOW_SHORT == 0 )); then
  echo "codex timeout ${TIMEOUT}s < 3600s minimum" >&2
  echo "pass --allow-short-timeout if this is intentional (small verify job)" >&2
  exit 2
fi

mkdir -p "$(dirname "$LOG")"

echo "SPAWN: prompt=$PROMPT log=$LOG cd=$CD timeout=${TIMEOUT}s sandbox=$SANDBOX${MODEL:+ model=$MODEL}" >&2

ARGS=(
  exec
  --sandbox "$SANDBOX"
  --skip-git-repo-check
  -C "$CD"
)

for d in "${ADD_DIRS[@]+"${ADD_DIRS[@]}"}"; do
  ARGS+=(--add-dir "$d")
done

if [[ -n "$MODEL" ]]; then
  ARGS+=(-m "$MODEL")
fi

ARGS+=(-)

run_codex_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT" codex "${ARGS[@]}" < "$PROMPT" > "$LOG" 2>&1
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$TIMEOUT" codex "${ARGS[@]}" < "$PROMPT" > "$LOG" 2>&1
    return $?
  fi

  # macOS does not ship GNU timeout. Job control gives the background codex
  # process its own process group, so timeout cleanup also reaches child tests.
  set -m
  codex "${ARGS[@]}" < "$PROMPT" > "$LOG" 2>&1 &
  child=$!
  set +m
  (
    sleep "$TIMEOUT"
    if kill -0 "$child" 2>/dev/null; then
      kill -TERM "-$child" 2>/dev/null || kill -TERM "$child" 2>/dev/null || true
      sleep 5
      kill -KILL "-$child" 2>/dev/null || kill -KILL "$child" 2>/dev/null || true
    fi
  ) &
  watchdog=$!

  wait "$child" 2>/dev/null
  child_status=$?

  if kill -0 "$watchdog" 2>/dev/null; then
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
  fi

  if (( child_status == 143 || child_status == 137 )); then
    return 124
  fi

  return "$child_status"
}

set +e
run_codex_with_timeout
EXIT=$?
set -e

{
  echo "EXIT=$EXIT"
  echo "DONE_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$LOG"

echo "DONE: log=$LOG exit=$EXIT" >&2

exit "$EXIT"
