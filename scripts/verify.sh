#!/usr/bin/env bash
# Semantic verification for Reciplease. swiftc -parse is only the last step,
# and only for files the Swift package cannot typecheck.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "${HOME}/.local/share/swiftly/env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${HOME}/.local/share/swiftly/env.sh"
fi

step() {
  printf '\n== %s ==\n' "$1"
}

step "swift build (semantic typecheck)"
swift build

step "swift test"
swift test

step "SwiftLint"
lint_bin=""
if command -v swiftlint >/dev/null 2>&1; then
  lint_bin="$(command -v swiftlint)"
else
  cache="${ROOT}/.cache/tools"
  mkdir -p "${cache}"
  arch="$(uname -m)"
  os="$(uname -s)"
  version="0.65.1"
  if [[ "${os}" == "Linux" ]]; then
    case "${arch}" in
      x86_64|amd64) asset="swiftlint_linux_amd64.zip" ;;
      aarch64|arm64) asset="swiftlint_linux_arm64.zip" ;;
      *) echo "no pinned SwiftLint build for ${arch}" >&2; exit 1 ;;
    esac
    dest="${cache}/swiftlint-${version}-linux-${arch}"
    if [[ ! -x "${dest}" ]]; then
      url="https://github.com/realm/SwiftLint/releases/download/${version}/${asset}"
      tmp="$(mktemp -d)"
      if ! curl -fsSL --retry 3 -o "${tmp}/swiftlint.zip" "${url}"; then
        echo "SwiftLint download failed (${url})." >&2
        if [[ ! -t 1 ]] && ! curl -fsI --max-time 5 https://github.com >/dev/null 2>&1; then
          echo "offline; skipping SwiftLint" >&2
          lint_bin=""
        else
          exit 1
        fi
      else
        unzip -qo "${tmp}/swiftlint.zip" swiftlint-static -d "${tmp}"
        mv "${tmp}/swiftlint-static" "${dest}"
        chmod +x "${dest}"
        rm -rf "${tmp}"
      fi
    fi
    if [[ -x "${dest}" ]]; then
      lint_bin="${dest}"
    fi
  elif [[ "${os}" == "Darwin" ]]; then
    echo "swiftlint is not on PATH. Install it with: brew install swiftlint" >&2
    exit 1
  else
    echo "unsupported OS for SwiftLint: ${os}" >&2
    exit 1
  fi
fi

if [[ -n "${lint_bin}" ]]; then
  "${lint_bin}" lint --config "${ROOT}/.swiftlint.yml" --strict --quiet
  echo "SwiftLint ok (${lint_bin})"
fi

step "swiftc -parse (files excluded from the Swift package)"
excluded=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && excluded+=("${line}")
done < <(python3 - <<'PY'
import re
from pathlib import Path
text = Path("Package.swift").read_text()
# First target's exclude list is the app sources that are not typechecked by SPM.
match = re.search(r"exclude:\s*\[(.*?)\]", text, re.S)
root = Path("PantryPal")
excluded = []
if match:
    for raw in re.findall(r'"([^"]+)"', match.group(1)):
        excluded.append(root / raw)
for path in sorted(root.rglob("*.swift")):
    if any(path == item or item in path.parents for item in excluded):
        print(path)
PY
)
if ((${#excluded[@]})); then
  # -parse checks syntax only. Type errors in these files are caught by xcodebuild.
  printf '%s\n' "${excluded[@]}" | xargs -n 20 swiftc -parse
  echo "parsed ${#excluded[@]} Swift files not in the package target"
else
  echo "package target covers every Swift file under PantryPal/"
fi

step "Xcode project integrity"
python3 scripts/check_pbxproj.py

if command -v xcodebuild >/dev/null 2>&1; then
  step "stub plists (gitignored) and unsigned simulator build"
  python3 - <<'PY'
from pathlib import Path

def write_if_missing(path: Path, body: str) -> None:
    if path.exists():
        print(f"keep {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    print(f"wrote {path}")

env = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>RECIPE_API_BASE_URL</key><string>https://example.com</string>
  <key>RECIPLEASE_API_BASE_URL</key><string>https://example.com</string>
  <key>REVENUECAT_API_KEY</key><string>stub</string>
  <key>MAX_SCAN_PHOTOS</key><string>4</string>
  <key>TRIAL_MAX_INTERACTIONS</key><string>5</string>
  <key>PRO_MAX_INTERACTIONS</key><string>100</string>
  <key>USAGE_LIMITS_ENABLED</key><string>true</string>
</dict></plist>
"""
google = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>API_KEY</key><string>stub</string>
  <key>GCM_SENDER_ID</key><string>1</string>
  <key>PLIST_VERSION</key><string>1</string>
  <key>BUNDLE_ID</key><string>com.henrychipman.Reciplease.dev</string>
  <key>PROJECT_ID</key><string>stub</string>
  <key>STORAGE_BUCKET</key><string>stub.appspot.com</string>
  <key>GOOGLE_APP_ID</key><string>1:1:ios:stub</string>
</dict></plist>
"""
write_if_missing(Path("EnvProd.plist"), env)
write_if_missing(Path("EnvSandbox.plist"), env)
write_if_missing(Path("PantryPal/GoogleService-Info.plist"), google)
PY
  export RECIPE_API_BASE_URL="${RECIPE_API_BASE_URL:-https://example.com}"
  export RECIPLEASE_API_BASE_URL="${RECIPLEASE_API_BASE_URL:-https://example.com}"
  export REVENUECAT_API_KEY="${REVENUECAT_API_KEY:-stub}"
  xcodebuild \
    -project PantryPal.xcodeproj \
    -scheme PantryPal \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  echo "xcodebuild not found; skipped the iOS SDK build (expected on Linux)"
fi

echo
echo "verify.sh finished"
