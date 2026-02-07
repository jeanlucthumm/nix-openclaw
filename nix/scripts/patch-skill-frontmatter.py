#!/usr/bin/env python3
"""Patch YAML frontmatter fields in a SKILL.md file.

Usage: patch-skill-frontmatter.py <input> <output> <key=value> [<key=value> ...]

Reads a SKILL.md with YAML frontmatter (delimited by ---), patches the
specified top-level keys, and writes the result to <output>.

Only top-level scalar fields are supported (name, description, homepage).
"""

import sys
import re


def parse_frontmatter(text):
    """Split text into (frontmatter_lines, body) where frontmatter is between --- delimiters."""
    match = re.match(r'^---\n(.*?\n)---\n?(.*)', text, re.DOTALL)
    if not match:
        return None, text
    return match.group(1), match.group(2)


def patch_frontmatter(fm_text, overrides):
    """Patch top-level keys in YAML frontmatter text.

    For each override key=value:
    - If the key exists, replace its line
    - If the key doesn't exist, append it before the closing ---
    """
    lines = fm_text.splitlines()
    remaining = dict(overrides)
    result = []

    for line in lines:
        replaced = False
        for key in list(remaining.keys()):
            # Match top-level key (not indented)
            if re.match(rf'^{re.escape(key)}\s*:', line):
                result.append(f'{key}: {remaining[key]}')
                del remaining[key]
                replaced = True
                break
        if not replaced:
            result.append(line)

    # Append any keys that weren't found
    for key, value in remaining.items():
        result.append(f'{key}: {value}')

    return '\n'.join(result) + '\n'


def main():
    if len(sys.argv) < 4:
        print(f'Usage: {sys.argv[0]} <input> <output> <key=value> ...', file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    overrides = {}
    for arg in sys.argv[3:]:
        if '=' not in arg:
            print(f'Invalid override (expected key=value): {arg}', file=sys.stderr)
            sys.exit(1)
        key, value = arg.split('=', 1)
        overrides[key] = value

    with open(input_path, 'r') as f:
        text = f.read()

    fm_text, body = parse_frontmatter(text)
    if fm_text is None:
        print(f'No frontmatter found in {input_path}', file=sys.stderr)
        sys.exit(1)

    patched_fm = patch_frontmatter(fm_text, overrides)
    result = f'---\n{patched_fm}---\n{body}'

    with open(output_path, 'w') as f:
        f.write(result)


if __name__ == '__main__':
    main()
