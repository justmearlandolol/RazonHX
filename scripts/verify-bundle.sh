#!/bin/bash
set -euo pipefail
trap 'echo "::error title=Bundle verification::Failed at line $LINENO: $BASH_COMMAND"' ERR
app=${1:?Provide path to RazonHX.app}
arch=${2:?Provide x86_64 or arm64}
minimum=${3:?Provide deployment target}
test -f "$app/Contents/MacOS/RazonHX"
test -f "$app/Contents/Resources/Logo/RazonHX.png"
test -f "$app/Contents/Resources/RazonHX.icns"
test -f "$app/Contents/Resources/default.json"
plutil -lint "$app/Contents/Info.plist"
actual=$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")
test "$actual" = "$minimum"
lipo -verify_arch "$arch" "$app/Contents/MacOS/RazonHX"
# Reject an unexpected deployment target in the Mach-O itself, not just Info.plist.
load_commands=$(otool -l "$app/Contents/MacOS/RazonHX")
if ! printf '%s\n' "$load_commands" | awk -v expected="$minimum" '
  /cmd LC_VERSION_MIN_MACOSX/ { legacy=1; next }
  legacy && /version / { if ($2 == expected || $2 == expected ".0") ok=1; legacy=0 }
  /cmd LC_BUILD_VERSION/ { modern=1; next }
  modern && /minos / { if ($2 == expected || $2 == expected ".0") ok=1; modern=0 }
  END { exit !ok }'; then
  echo "Mach-O deployment target did not match $minimum" >&2; exit 1
fi
# Catch accidental non-system dynamic dependencies (e.g. a local Homebrew library).
otool -L "$app/Contents/MacOS/RazonHX"
if otool -L "$app/Contents/MacOS/RazonHX" | tail -n +2 | grep -E '/(opt/homebrew|usr/local|Users)/'; then
  echo "Nonportable dynamic dependency" >&2; exit 1
fi
echo "Bundle structure, architecture and deployment metadata verified. Runtime testing still required."
