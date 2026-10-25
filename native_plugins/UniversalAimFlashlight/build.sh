#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XWIN="${XWIN_DIR:-$HOME/.cache/cargo-xwin/xwin}"
SDK="${RED4EXT_SDK_INCLUDE:-/home/jakeshea/.gemini/antigravity-cli/brain/6374a691-b674-431b-8d44-b31dbb35e7c4/scratch/RED4ext.SDK/include}"

if [[ ! -e "$SDK/RED4ext/rtti" && -d "$SDK/RED4ext/RTTI" ]]; then
  ln -sf RTTI "$SDK/RED4ext/rtti"
fi

clang++ --target=x86_64-pc-windows-msvc \
  -std=c++23 -O2 -DNDEBUG -DWIN32_LEAN_AND_MEAN -DNOMINMAX \
  -fms-extensions -fms-compatibility -fms-compatibility-version=19.40 \
  -Wno-unknown-pragmas -Wno-unused-function -Wno-nonportable-include-path \
  -Wno-unused-value -Wno-invalid-offsetof -Wno-deprecated-volatile \
  -isystem "$XWIN/crt/include" \
  -isystem "$XWIN/sdk/include/ucrt" \
  -isystem "$XWIN/sdk/include/um" \
  -isystem "$XWIN/sdk/include/shared" \
  -I "$SDK" \
  -fuse-ld=lld-link \
  -shared \
  "$SCRIPT_DIR/Main.cpp" \
  -Wl,/LIBPATH:"$XWIN/crt/lib/x86_64" \
  -Wl,/LIBPATH:"$XWIN/sdk/lib/ucrt/x86_64" \
  -Wl,/LIBPATH:"$XWIN/sdk/lib/um/x86_64" \
  -Wl,kernel32.lib,user32.lib,libcmt.lib,libvcruntime.lib,libucrt.lib \
  -o "$SCRIPT_DIR/UniversalAimFlashlight.dll"

echo "Built $SCRIPT_DIR/UniversalAimFlashlight.dll ($(stat -c%s "$SCRIPT_DIR/UniversalAimFlashlight.dll") bytes)"
