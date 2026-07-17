---
name: notion-safe-writes
description: >
  Safe-write guardrails for the Notion MCP. Use this BEFORE you create or edit any Notion
  page — i.e. any call to notion-create-pages or notion-update-page (replace_content /
  update_content / insert_content), and whenever the user asks to create, write, update,
  edit, append to, or restructure a Notion page, doc, or database entry. Prevents the known
  Notion MCP write bugs: literal \u-escapes ending up as visible text, search-replace edits
  that silently skip, accidental child-page deletion on replace_content, and broken
  table-row / toggle edits. Consult this even for a "quick" one-line Notion edit — the
  silent-failure modes look like success until you re-fetch.
---

# Notion Safe Writes

The Notion MCP has several write-time bugs where a call **reports success but silently does
the wrong thing** — escapes stored as literal text, search-replace entries skipped, table
rows not updated. None of these throw. The only way to catch them is to know the patterns up
front and to verify by re-fetching. This skill is that knowledge.

Source of truth: the user's "Notion MCP – Bugs & Quirks" page. These are observed behaviors,
not all officially confirmed — so treat the verify step as mandatory, not optional.

## The core loop — always

Every edit to an existing page follows **fetch → write → re-fetch & verify**:

1. **Fetch first.** Before any `notion-update-page`, call `notion-fetch` on the page. You are
   editing against Notion's *canonical backing text*, which is often not what you wrote or
   what you'd guess: URLs get rewritten, markdown tables become native blocks, emojis may be
   stored differently. Your `old_str` must match the fetched form exactly.
2. **Write** using the rules below.
3. **Re-fetch & verify.** Fetch the page again and confirm every intended change actually
   landed. This is not paranoia — several failure modes report success while skipping edits
   (see #3 and #6). For multi-edit calls, check *each* change individually.

For brand-new pages (`notion-create-pages`) there's nothing to fetch first, but you still
verify after, and you still use literal characters (#1).

## The rules

### 1. Use literal emojis and characters — never `\u` escapes

In update operations, Unicode escape sequences in `new_str` / `content` are inconsistently
parsed — often stored as literal text instead of the character. Same for `\n` (becomes a
literal `n`, lines collapse) and escaped HTML/backticks.

```text
❌  new_str = "# 🔐 GitHub & Security\n\n> ⚠️ Wichtig!"
    → renders as:  # ud83dudd10 GitHub & Securityn> ⚠ufe0f Wichtig!

✅  new_str = "# 🔐 GitHub & Security\n\n> ⚠️ Wichtig!"
    → use the real emoji, a real newline in the string
```

Reliability by tool: `create_pages` parses escapes fine; `replace_content` and
`insert_content` are reliably broken; `update_content` is inconsistent. **Rule for all of
them: put literal emojis/special characters straight into the source string.** Don't hand-roll
`\u` escapes even where they happen to work — it keeps every call consistent.

### 2. Notion rewrites URLs — re-fetch before relying on a URL in old_str

After a write, Notion transforms some links, e.g. `https://skills.sh/` is stored as
`[skills.sh](http://skills.sh)`. A later `update_content` whose `old_str` contains the
*original* URL won't match. This is the #1 reason a search-replace silently skips. Always
fetch first (core loop #1) so your `old_str` uses the stored form.

### 3. Multi-edit `content_updates` fail silently per-entry

When a single call has several search-replace operations, an entry whose `old_str` doesn't
match exactly is **skipped without error** — the call still returns success and applies the
entries that *did* match. Classic symptom: you bump a counter in a heading ("Rules (8)" →
"(9)") and that text edit lands, but a related edit (often a table row, see #6) is skipped →
"title says 9, table shows 8."

Mitigation: keep edits small, and after any multi-edit call re-fetch and confirm each change
landed (core loop #3). Don't trust the success return.

### 4. `replace_content` deletes child pages unless you re-include them

If a page has child pages and you call `replace_content` without referencing them, Notion
refuses with a clear error:

> This operation would delete N child page(s). To proceed, either include these items in
> new_str using `<page url="...">` tags, OR set `allow_deleting_content: true`.

Before `replace_content` on a page that may have children: fetch it, collect every child-page
URL, and embed them as `<page url="..."/>` tags in `new_str`. Only set
`allow_deleting_content: true` if the user explicitly wants those children gone — deletion is
hard to reverse, so confirm first.

### 5. Toggles (`<details>`) can't nest page-blocks — inline links only

A `<page url="..."/>` tag inside `<details>...</details>` triggers a validation error. Inside
a toggle, link to other pages with inline markdown only: `[Title](url)`.

### 6. Edit table rows in native `<tr>/<td>` form, not pipe-markdown

On write, Notion converts markdown pipe tables (`| a | b |`) into **native table blocks**. On
fetch they come back as `<table>` with `<tr>`/`<td>` cells. A later `update_content` whose
`old_str` is a *pipe-format* row will never match → silently skipped (this is a specific case
of #3). Plain text (headings, paragraphs, blockquotes) matches fine; only table rows bite.

To add/change a row, fetch first to get the canonical `<tr>/<td>` form, use the existing row
as the anchor, and append the new row:

```text
old_str:
<tr>
<td>research-routing.md</td>
<td>Purpose …</td>
</tr>

new_str:
<tr>
<td>research-routing.md</td>
<td>Purpose …</td>
</tr>
<tr>
<td>search-discipline.md</td>
<td>New purpose …</td>
</tr>
```

## Pre-write checklist

- [ ] Editing existing page? **Fetched it first** to get the canonical backing text.
- [ ] Content uses **literal emojis + real newlines**, no `\u` escapes.
- [ ] `old_str` strings match the **fetched form** (rewritten URLs, native table rows).
- [ ] `replace_content` on a page with children? **Child pages re-included** as `<page url="..."/>`.
- [ ] Links inside `<details>` toggles are **inline `[Title](url)`**, not page-blocks.
- [ ] Table-row edits use **native `<tr>/<td>`**, not pipe-markdown.
- [ ] After writing: **re-fetched and verified** every change landed (especially multi-edits + tables).
