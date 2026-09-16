#!/bin/bash
set -euo pipefail
repository_root=$(cd "$(dirname "$0")/.." && pwd)
documentation_scratch=${1:-/tmp/networking-documentation-build}
documentation_output=${2:-/tmp/networking-documentation}
use_shipped_guides=${3:-}
if [ "$use_shipped_guides" = --use-shipped-guides ]; then
  python3 "$repository_root/Tools/sync-documentation.py" --check
fi
module_cache="$documentation_scratch/module-cache"
symbols="$documentation_output/symbolgraphs"
mkdir -p "$symbols" "$module_cache"
cd "$repository_root"
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
  swift build --disable-sandbox --scratch-path "$documentation_scratch" \
  -Xswiftc -module-cache-path -Xswiftc "$module_cache"
macos_sdk=$(xcrun --sdk macosx --show-sdk-path)
architecture=$(uname -m)
for module_name in Networking NetworkingTransfers NetworkingRealtime NetworkingSync; do
  module_symbols="$symbols/$module_name"
  mkdir -p "$module_symbols"
  for graph in "$module_symbols"/*.symbols.json; do
    if [ -f "$graph" ]; then rm -- "$graph"; fi
  done
  xcrun swift-symbolgraph-extract -module-name "$module_name" \
    -I "$documentation_scratch/debug/Modules" -target "$architecture-apple-macosx13.0" \
    -sdk "$macos_sdk" -module-cache-path "$module_cache" \
    -minimum-access-level public -output-dir "$module_symbols"
done
if [ "$use_shipped_guides" != --use-shipped-guides ]; then
  python3 "$repository_root/Tools/generate-api-reference.py" "$symbols" "$repository_root/Docs/API.md"
  python3 "$repository_root/Tools/sync-documentation.py"
fi
for module_name in Networking NetworkingTransfers NetworkingRealtime NetworkingSync; do
  catalog="$repository_root/Sources/$module_name/$module_name.docc"
  xcrun docc convert "$catalog" --warnings-as-errors \
    --additional-symbol-graph-dir "$symbols/$module_name" \
    --fallback-display-name "$module_name" \
    --fallback-bundle-identifier "com.teisrud.$module_name" \
    --output-path "$documentation_output/$module_name.doccarchive"
done
printf 'Documentation archives: %s\n' "$documentation_output"
