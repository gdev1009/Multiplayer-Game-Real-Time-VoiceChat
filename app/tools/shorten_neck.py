#!/usr/bin/env python3
"""
DEPRECATED — do not run.

This tool was a stop-gap for the OLD clay-render base bodies, which sat with the
head too high and left a long bare neck. It lowered the head assembly (and the
head-registered parts) by a fixed offset.

The artist later shipped a full, self-consistent 2D pack (assets/images/All (1))
whose bodies already have natural necks and whose parts register correctly. That
pack is imported by tools/import_character_art.py, which is now the single source
of truth. Running this script against the new pack would SHIFT the head parts out
of alignment again, so it is intentionally disabled.
"""

import sys


def main() -> None:
    sys.exit(
        "shorten_neck.py is deprecated. The new artist pack has natural necks; "
        "use tools/import_character_art.py instead. Refusing to run."
    )


if __name__ == "__main__":
    main()

