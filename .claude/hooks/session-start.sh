#!/bin/bash
# Installs the Flutter SDK (pinned in flutter_app/.tool-versions) so `dart format`,
# `flutter analyze`, and `flutter test` are available in this session,
# matching the definition-of-done checks required by AGENTS.md.
set -euo pipefail

FLUTTER_VERSION="$(grep -m1 '^flutter ' "$CLAUDE_PROJECT_DIR/flutter_app/.tool-versions" | awk '{print $2}')"
FLUTTER_HOME="/opt/flutter"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION..." >&2
  rm -rf "$FLUTTER_HOME"
  curl -fsSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  mkdir -p /opt
  tar -xf /tmp/flutter.tar.xz -C /opt
  rm -f /tmp/flutter.tar.xz
  git config --global --add safe.directory "$FLUTTER_HOME"
fi

# Make flutter/dart resolvable both for this hook's own shell profile and
# for any non-interactive `bash -c` invocation (e.g. dispatched subagents'
# tool calls), which does not source ~/.bashrc or /etc/profile.
ln -sf "$FLUTTER_HOME/bin/flutter" /usr/local/bin/flutter
ln -sf "$FLUTTER_HOME/bin/dart" /usr/local/bin/dart

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

cd "$CLAUDE_PROJECT_DIR/flutter_app"
flutter --version

# `flutter pub get`'s per-package "X (Y available)" output is pure noise on
# every session start (dozens of lines, unrelated to this session's actual
# task) and costs context on every single session, not just the board
# worker. Keep it, but only surface it when something actually goes wrong.
PUB_GET_LOG="$(mktemp)"
if ! flutter pub get > "$PUB_GET_LOG" 2>&1; then
  echo "flutter pub get failed:" >&2
  cat "$PUB_GET_LOG" >&2
  rm -f "$PUB_GET_LOG"
  exit 1
fi
rm -f "$PUB_GET_LOG"
echo "Dependencies resolved."
