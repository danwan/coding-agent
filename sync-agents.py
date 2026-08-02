#!/usr/bin/env python3
"""Translate sources/claude/agents/*.md into each harness's subagent format.

    ./sync-agents.py           # show what would change
    ./sync-agents.py --apply   # write it

The four subagent definitions are authored once in Claude Code's format
(markdown + YAML frontmatter). Every other harness wants a different container:
Codex uses TOML with the prompt as one escaped string, OpenCode and Gemini use
markdown with differently-named frontmatter keys.

Grok is deliberately absent: it inherits rules and skills from ~/.claude via
[compat.claude], but its `agents` compat cell covers instruction files, not
subagent definitions — so the four agents are simply not available there. See
sources/harness-notes/grok.md.

The body is copied verbatim everywhere — it is the actual instruction, and
rewording it per harness is how copies start to drift. Only the frontmatter is
translated.

Model names are deliberately NOT translated. "opus" means nothing to Codex or
Gemini, and inventing a mapping would silently pin an agent to whatever model
the guess happened to name. Where a harness already has a model configured, that
choice is preserved; otherwise the field is omitted and the agent inherits the
session model. Harnesses that cannot express a field simply lose it, and the
dropped fields are recorded as comments so the loss is visible rather than
silent.
"""

import re
import sys
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parent
SRC = REPO / "sources/claude/agents"
HOME = Path.home()
APPLY = "--apply" in sys.argv

changed = same = 0


def parse(path):
    """Split a Claude agent file into (frontmatter dict, body)."""
    text = path.read_text()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        raise SystemExit(f"{path}: kein Frontmatter gefunden")
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    return meta, m.group(2)


def write(dest: Path, content: str, note=""):
    global changed, same
    if dest.exists() and dest.read_text() == content:
        same += 1
        return
    changed += 1
    label = f"{dest}".replace(str(HOME), "~")
    if APPLY:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content)
        print(f"  ~> {label}{note}")
    else:
        print(f"  would write {label}{note}")


def yaml_agent(meta, body, fields):
    """Markdown + YAML frontmatter, keeping only `fields` (ordered)."""
    lines = ["---"]
    for key, value in fields:
        if value:
            lines.append(f"{key}: {value}")
    lines += ["---", body.rstrip(), ""]
    return "\n".join(lines)


def toml_escape(s):
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def codex_agent(meta, body, existing: Path):
    """Codex: TOML, prompt inline as developer_instructions.

    Codex model IDs are its own (gpt-*). Keep whatever is already configured
    rather than deriving one from `model: opus`.
    """
    model = effort = None
    if existing.exists():
        try:
            prev = tomllib.loads(existing.read_text())
            model = prev.get("model")
            effort = prev.get("model_reasoning_effort")
        except tomllib.TOMLDecodeError:
            pass
    if effort is None:
        effort = meta.get("effort")

    out = [
        f'name = "{meta["name"]}"',
        f'description = "{toml_escape(meta["description"])}"',
    ]
    if model:
        out.append(f'model = "{model}"')
    if effort:
        out.append(f'model_reasoning_effort = "{effort}"')
    # Fields Codex has no equivalent for — recorded, not silently dropped.
    for key in ("tools", "memory", "maxTurns"):
        if meta.get(key):
            out.append(f"# source_{key} = \"{meta[key]}\"")
    out.append(f'developer_instructions = "{toml_escape(body.strip())}"')
    return "\n".join(out) + "\n"


def main():
    agents = sorted(SRC.glob("*.md"))
    if not agents:
        raise SystemExit("keine Agent-Definitionen in sources/claude/agents/")

    targets = [
        # (label, directory, builder) — skipped when the directory's parent is absent
        ("Codex", HOME / ".codex/agents", "codex"),
        ("OpenCode", HOME / ".config/opencode/agents", "opencode"),
        ("Gemini / Antigravity", HOME / ".gemini/agents", "gemini"),
        ("Claude Code", HOME / ".claude/agents", "claude"),
    ]

    for label, outdir, kind in targets:
        root = outdir.parent
        print(f"\n\033[1m{label}\033[0m")
        if not root.exists():
            print("  (nicht installiert — übersprungen)")
            continue
        for path in agents:
            meta, body = parse(path)
            name = meta["name"]
            if kind == "claude":
                write(outdir / f"{name}.md", path.read_text())
            elif kind == "codex":
                dest = outdir / f"{name}.toml"
                write(dest, codex_agent(meta, body, dest))
            elif kind == "opencode":
                write(
                    outdir / f"{name}.md",
                    yaml_agent(meta, body, [
                        ("description", meta.get("description")),
                        ("mode", "subagent"),
                    ]),
                )
            elif kind == "gemini":
                write(
                    outdir / f"{name}.md",
                    yaml_agent(meta, body, [
                        ("name", name),
                        ("description", meta.get("description")),
                        ("tools", meta.get("tools")),
                    ]),
                )

    print(f"\n\033[1mErgebnis\033[0m\n  identisch: {same}   zu schreiben: {changed}")
    if not APPLY and changed:
        print("\n  Nichts geändert. Mit ./sync-agents.py --apply anwenden.")


if __name__ == "__main__":
    main()
