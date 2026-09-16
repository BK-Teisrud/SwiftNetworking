#!/usr/bin/env python3
"""Keep distributable DocC articles synchronized with the single editable handbook."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
mismatches = []
for catalog in sorted((root / 'Sources').glob('*/*.docc')):
    guides = catalog / 'Guides'
    expected = {}
    for guide in sorted((root / 'Docs').glob('*.md')):
        name = 'Handbook.md' if guide.name == 'README.md' else guide.name
        expected[name] = guide.read_text().replace('](README.md)', '](Handbook.md)')
    for name, content in expected.items():
        output = guides / name
        if not output.exists() or output.read_text() != content:
            mismatches.append(str(output.relative_to(root)))
            if not args.check:
                guides.mkdir(parents=True, exist_ok=True)
                output.write_text(content)
    for output in guides.glob('*.md'):
        if output.name not in expected:
            mismatches.append(str(output.relative_to(root)))
            if not args.check:
                output.unlink()
if args.check and mismatches:
    raise SystemExit('DocC articles out of sync:\n' + '\n'.join(mismatches))
print('DocC articles verified' if args.check else 'DocC articles synchronized')
