You are configuring THIS machine as my coding-agent setup (primarily Claude Code). Work autonomously and completely. Only stop to ask me for: a login you can't complete, a secret value, or a sudo password. Print one line per item — PASS, FAIL, or SKIP.

Source of truth (public — read the raw file directly, no clone needed):
https://raw.githubusercontent.com/danwan/coding-agent/main/PROVISION.md

Steps:

1. Read PROVISION.md at the URL above. Each item is tagged [default], [optional], or [module:x] and lists what, from where, why, and a one-line verify. It has NO install commands on purpose — you decide HOW. Read your own current documentation, check your version, and note anything specific about this OS and this agent. Do whatever is actually needed so each item works with your current version; if a mechanism changed since this doc was written, adapt — the intent is the contract, not any command.

2. Ask me which optional items and modules to add on top of the defaults: the [optional] entries (e.g. playwright, memsearch), the "personal" toggle (dotfiles + settings), and the modules "google" and/or "webservice". Wait for my answer. Install every [default] item plus whatever I pick.

3. Install each selected item from its source: CLI tools via this OS's package manager; plugins via their marketplace; skills via skills.sh; MCP servers into your MCP config. For any secret, resolve its op:// reference with the 1Password CLI if available, otherwise ask me — never write a secret value anywhere in a repo.

4. Place the authored config from "Authored config" (and "Personal" if chosen): fetch each file from this same repo by raw URL and put it where THIS version of the agent reads its global instructions, rules, runbooks, and skills. Determine every location from your own current docs, not any fixed path.

5. Run every selected item's verify line. Report PASS or FAIL for each.

6. Prune: list what is actually installed and placed, compare to the selected PROVISION.md items + authored set, and for anything present but not listed ask me whether to remove it or add it to PROVISION.md. Never delete without asking.

7. Report what you installed, placed, verified, and pruned, and anything you couldn't finish.
