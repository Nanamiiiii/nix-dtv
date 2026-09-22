"""Prepend a GitHub-compatible table of contents to nixosOptionsDoc Markdown."""

import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
toc = ["# Options Reference", "", "## Index", ""]
anchors = {}
for heading in re.findall(r"^## (.+)$", source, re.MULTILINE):
    title = re.sub(r"\\([\W_])", r"\1", heading)
    anchor = re.sub(r"[^\w\- ]", "", title.lower()).replace(" ", "-")
    count = anchors.get(anchor, 0)
    anchors[anchor] = count + 1
    if count:
        anchor = f"{anchor}-{count}"
    toc.append(f"- [`{title}`](#{anchor})")

Path(sys.argv[2]).write_text("\n".join(toc) + "\n\n" + source)
