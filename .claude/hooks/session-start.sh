#!/bin/bash
# Installs the Flutter SDK (pinned in .tool-versions) so `dart format`,
# `flutter analyze`, and `flutter test` are available in this session,
# matching the definition-of-done checks required by AGENTS.md.
set -euo pipefail

FLUTTER_VERSION="$(grep -m1 '^flutter ' "$CLAUDE_PROJECT_DIR/.tool-versions" | awk '{print $2}')"
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

cd "$CLAUDE_PROJECT_DIR"
flutter --version
flutter pub get
