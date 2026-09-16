#!/bin/bash
set -euo pipefail
repository_root=$(cd "$(dirname "$0")/.." && pwd)
distribution_directory=$(mktemp -d /tmp/networking-distribution.XXXXXX)
trap 'rm -rf -- "$distribution_directory"' EXIT
# Copy only distributable files, including tracked DocC guides; no git/build caches or generated setup.
python3 - "$repository_root" "$distribution_directory/package" <<'PY'
import shutil
import sys
import subprocess
from pathlib import Path
source, destination = map(Path, sys.argv[1:])
destination.mkdir()
for name in ('Sources', 'Tests', 'Docs', 'Tools'):
    shutil.copytree(source / name, destination / name)
for name in ('Package.swift', 'README.md', 'CHANGELOG.md', 'LICENSE', 'CONTRIBUTING.md', 'SECURITY.md'):
    shutil.copy2(source / name, destination / name)
# Negative case: missing shipped article must fail check, not be regenerated.
guide = destination / 'Sources/Networking/Networking.docc/Guides/GettingStarted.md'
content = guide.read_text()
guide.unlink()
try:
    result = subprocess.run([sys.executable, str(destination / 'Tools/sync-documentation.py'), '--check'],
                            capture_output=True, text=True)
    if result.returncode == 0:
        raise SystemExit('Missing distributed article was incorrectly accepted')
finally:
    guide.write_text(content)
print('Missing guide detection verified')
PY
cd "$distribution_directory/package"
# Build shipped catalogs directly; this mode does not generate or repair missing guide articles.
Tools/build-documentation.sh "$distribution_directory/build" "$distribution_directory/docs" --use-shipped-guides
printf 'Clean distribution documentation verified\n'
