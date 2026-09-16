#!/usr/bin/env python3
"""Generate complete public declarations from Swift symbol graphs (no third-party dependencies)."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("symbol_graph_directory", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
modules = {}
for graph_file in sorted(args.symbol_graph_directory.rglob("*.symbols.json")):
    graph = json.loads(graph_file.read_text())
    name = graph["module"]["name"]
    if name not in {"Networking", "NetworkingTransfers", "NetworkingRealtime", "NetworkingSync"}:
        continue
    symbols = modules.setdefault(name, {})
    for symbol in graph.get("symbols", []):
        if symbol.get("accessLevel") == "public":
            symbols[symbol["identifier"]["precise"]] = symbol
lines = ["# Komplett offentlig API-referanse", "", "Generert fra Swift-symbolgraphs. Ikke rediger deklarasjonene manuelt.", "",
         "Se [håndboken](README.md) for defaults, eksempler, sikkerhetsgrenser og lifecycle. Referansen inkluderer alle offentlige deklarasjoner og eventuelle syntetiserte protokollmedlemmer fra den bygde toolchainen.", ""]
for name in ("Networking", "NetworkingTransfers", "NetworkingRealtime", "NetworkingSync"):
    symbols = sorted(modules.get(name, {}).values(), key=lambda s: (s.get("pathComponents", []), s["identifier"]["precise"]))
    lines += [f"## {name}", "", f"{len(symbols)} offentlige symboler.", ""]
    for symbol in symbols:
        title = ".".join(symbol.get("pathComponents", [symbol["names"]["title"]]))
        declaration = "".join(fragment["spelling"] for fragment in symbol.get("declarationFragments", []))
        lines += [f"### {title}", "", "```swift", declaration, "```", ""]
        doc = "\n".join(line["text"] for line in symbol.get("docComment", {}).get("lines", []))
        if doc and symbol.get("location"):
            lines += [doc, ""]
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text("\n".join(lines))
print(f"Generated {args.output}: {sum(len(v) for v in modules.values())} public symbols")
