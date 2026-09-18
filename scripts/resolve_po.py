#!/usr/bin/env python3
"""Resolve merge conflicts in Gettext catalogues by keeping both sides.

Branches that each add translations append their entries at the same spot of
a .po/.pot file, so git reports a conflict although nothing contradicts. This
keeps both sides of every conflict hunk, repairs the one damage a line-level
union can do (an entry whose shared `msgstr` line fell outside the hunk), and
drops exact duplicate entries, keyed by msgctxt and msgid. Run
`mix gettext.extract --merge` afterwards to normalise the files.

Usage: resolve_po.py FILE...
"""

import re
import sys

HUNK = re.compile(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", re.S)


def entry_key(block):
    msgid = re.search(r'^msgid "(.*)"$', block, re.M)
    if not msgid or msgid.group(1) == "":
        return None
    msgctxt = re.search(r'^msgctxt "(.*)"$', block, re.M)
    obsolete = "#~" in block
    return (msgctxt.group(1) if msgctxt else None, msgid.group(1), obsolete)


def resolve(text):
    text = HUNK.sub(lambda m: m.group(1).rstrip("\n") + "\n\n" + m.group(2), text)
    text = re.sub(r'(\nmsgid "[^\n]*"\n)\n', r'\1msgstr ""\n\n', text)

    # A hunk that only differed in reference comments leaves them as a block
    # of their own; they belong to the entry that follows.
    blocks = []
    pending = []
    for block in text.split("\n\n"):
        if block and all(line.startswith("#:") for line in block.split("\n")):
            pending.append(block)
            continue
        blocks.append("\n".join(pending + [block]))
        pending = []
    blocks.extend(pending)

    seen = set()
    kept = []
    for block in blocks:
        key = entry_key(block)
        if key is not None:
            if key in seen:
                continue
            seen.add(key)
        kept.append(block)
    return "\n\n".join(kept)


def main(paths):
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        if "<<<<<<<" not in text:
            continue
        resolved = resolve(text)
        if "<<<<<<<" in resolved or ">>>>>>>" in resolved:
            sys.exit(f"could not resolve {path}")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(resolved)
        print(f"resolved {path}")


if __name__ == "__main__":
    main(sys.argv[1:])
