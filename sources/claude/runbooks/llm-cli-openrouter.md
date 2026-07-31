# `llm` CLI with OpenRouter

Use Simon Willison's `llm` CLI for second opinions through OpenRouter.
Provisioning intent lives in `PROVISION.md`; this file contains the setup
commands.

## Install

Python tooling goes through `uv`:

```bash
uv tool install llm --with llm-openrouter
llm --version
```

If `llm` is not on `PATH`, run `uv tool update-shell` and open a new shell.
Install later plugin updates with `uv tool upgrade llm`.

## Configure the key

This needs a pay-as-you-go OpenRouter API key. Consumer subscriptions
(Claude Pro, ChatGPT Plus) grant no API access and cannot be used here.

Use the interactive prompt so the key does not enter shell history:

```bash
llm keys set openrouter
```

The CLI stores it outside the repo. `llm keys path` prints the current key-store
location. Never commit or paste that file into an issue, PR, or log.

The plugin also accepts `OPENROUTER_KEY`, but the CLI key store is preferred for
interactive use.

## Choose a current model and alias it

OpenRouter model IDs change. List the live catalog instead of copying a
version-pinned ID from this runbook:

```bash
llm openrouter refresh
llm models -q openrouter
llm aliases set review openrouter/<provider>/<model>
llm aliases view
```

Replace `<provider>/<model>` with an ID printed by the model listing. Use
additional aliases only when they are actually needed.

## Verify

```bash
printf '%s\n' 'Reply with only OK.' | llm -m review
llm logs -n 1
```

A response verifies the installation, plugin, stored key, selected model, and
alias together. `Unknown model` means the catalog or alias needs refreshing;
an authentication error means the OpenRouter key is missing or invalid.

Prompts, responses and token counts are logged to a local SQLite database;
`llm logs path` prints its location and `llm logs -n 1 --short --usage` shows
what the last call consumed. Treat `llm logs` output as sensitive because it
can contain source text or other supplied context.

## Use

```bash
llm -m review 'Review this design'
cat plan.md | llm -m review 'Find correctness risks'
cat diff.patch | llm -m review 'Review this diff'
```
