# Remediation — Bau-Vorlagen für den Fix-Modus

Repo-agnostische Muster, destilliert aus unseren produktiven Repos. Immer an
die Konventionen des Ziel-Repos anpassen (Kommentarsprache, Node-Version,
Paketmanager) — die Struktur ist der Standard, nicht der Wortlaut.

## 1. Standard-`ci.yml` (Node/Next.js-Grundform)

```yaml
name: ci
on:
  pull_request:            # KEIN paths-ignore hier, wenn ein Job Required Check ist
  push:
    branches: [main]
    paths-ignore: ["**.md", "docs/**"]
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  test:                    # kurzer, stabiler Name — er wird Required-Check-Context
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npm run lint -- --max-warnings=0
      - run: npx tsc --noEmit        # entfällt, wenn `next build` unten läuft
      - run: npm test
      - run: npm run build
      - run: npm audit --omit=dev --audit-level=high   # nur bei Deploy-Ziel
```

Kernregeln (Begründungen in `audit-standard.md`, Abschnitt C):

- `paths-ignore` **nur auf `push`** — auf `pull_request` erzeugt es den
  Required-Check-Deadlock (P11).
- Kein `continue-on-error`, kein `|| true` auf Prüfschritten (P13).
- Getrennte Jobs je Sprach-Stack/Teilprojekt; Matrix-Form für gleichartige
  Teilprojekte: `strategy: { fail-fast: false, matrix: { project: [a, b] } }`
  mit `working-directory: ${{ matrix.project }}` — Required-Context heißt dann
  `test (a)`, `test (b)` (P18, P12).
- Teure Jobs nicht nach dem Merge wiederholen: `if: github.event_name != 'push'`.

## 2. Python-Job (uv)

```yaml
  python:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v7
        with: { cache-dependency-glob: uv.lock }
      - run: uv sync --all-extras
      - run: uv run ruff check .
      - run: uv run pytest -m "not integration" -q
```

- Marker trennen, was CI darf: `integration`/`slow` für alles mit
  Live-Credentials oder Netz; die Nightly fährt `-m slow`.
- `ruff target-version` an die **Laufzeit**-Umgebung binden (bei Modal: die
  Modal-Python-Version), nicht an den lokalen Interpreter.

## 3. E2E: Smoke/Full-Split + Nightly

- PR-Gate = kleines Smoke-Projekt (< 5 min); Full-Suite nachts + per
  `workflow_dispatch`; optional PR-Label (`run-e2e`) für Full im PR.
- Nightly-Cron auf **ungerader Minute** (`17 3 * * *`), volle Stunden sind auf
  gehosteten Runnern überlaufen. Immer `workflow_dispatch` daneben.
- Worker-Zahl gehört in die **Runner-Config**, nicht in die Workflow-YAML
  (P20), und ist eine Messfrage (P19): gegen einen einzelnen Dev-Server auf
  2-vCPU-Runnern ist 1 Worker meist optimal — mit Messwerten im Kommentar
  begründen. Per-Worker-Isolation (Seeds, Identitäten, Rate-Limit-Buckets vom
  Worker-Index) trotzdem verdrahten (P9).
- Warten = Health-Poll (`npx wait-on`, `curl --retry-connrefused`), nie `sleep`
  (P22). Artefakte (Screenshots/Traces/Server-Log) bei Failure hochladen (P16).
- Seeds über eine geschützte Seed-Route gegen den laufenden Server, nicht am
  Server vorbei in die DB (P10).

## 4. Ruleset auf `main` (via `gh api`)

Erst anlegen, wenn die Required-Check-Jobs auf `main` mindestens einmal grün
gelaufen sind. Contexts vorher gegen die **echten** Check-Run-Namen
verifizieren: `gh api repos/<o>/<r>/commits/<sha>/check-runs --jq
'.check_runs[].name'` — nie Job-IDs oder Workflow-Namen raten.

```json
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "rules": [
    { "type": "pull_request",
      "parameters": { "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks",
      "parameters": { "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "<job-name>" } ] } },
    { "type": "non_fast_forward" }
  ]
}
```

`gh api -X POST repos/<o>/<r>/rulesets --input ruleset.json` — die
zurückgegebene ID protokollieren (Rollback per DELETE). `strict: false` ist
Absicht: Branch muss grün sein, nicht rebased — sonst erzwingt jeder
zwischenzeitliche Merge Neuläufe aller offenen PRs. Klassische Branch
Protection nach erfolgreichem Ruleset ablösen
(`gh api -X DELETE repos/<o>/<r>/branches/main/protection`).

Actor-ID 5 = `repository_admin`. Rulesets auf privaten Repos brauchen
GitHub Pro; schlägt der POST deswegen fehl, berichten statt improvisieren.

## 5. Stack-Besonderheiten

**Next.js + Vercel** — `main` deployt Produktion, CI muss *vor* dem Merge grün
sein. `next build` in CI doppelt als Typecheck. E2E gegen Preview-Deployments:
Workflow-Trigger `deployment_status` (nur `state == success`, Environment
`Preview`); Bypass-Secrets in einer geschützten GitHub-Environment; die
Playwright-Config erzwingt HTTPS und den eigenen Host-Prefix, weil das
Bypass-Secret in Request-Headern reist.

**Convex** — deployt nie automatisch; Backend vor Frontend-Tests deployen.
Unit-Tests mit `convex-test` neben den Funktionen (`convex/*.test.ts`),
Environment `edge-runtime`, `convex-test` in Vitest inlinen
(`server.deps.inline`). CI baut ohne Deployment: `convex/_generated` ist
eingecheckt, Client fällt ohne `NEXT_PUBLIC_CONVEX_URL` auf Platzhalter
zurück. E2E gegen ein isoliertes lokales Backend aus temporärer Source-Kopie —
nie gegen Dev-/Prod-State.

**SQLite/better-sqlite3** — synchron, blockiert den Event-Loop: der eine
Dev-Server-Prozess ist der E2E-Flaschenhals (→ Worker-Messung, P19). Build mit
`DATABASE_PATH=:memory:`; Vitest mit `pool: forks` und großzügigem
testTimeout.

**Python + Modal** — Modal deployt nie automatisch; CLI-Aufrufe unattended
(`-y`). Frontend testet die *Form* der Modal-Antworten per Contract-Test gegen
fixierte Beispiele (P8), nicht das laufende Backend.

**Statische Site ohne Server** — Stufen 3–5 weitgehend N/A: kein Rate-Limiting,
keine Sessions, kein DB-Layer fordern (P4). Lint + Typecheck + Unit + Build
als ein `quality`-Job genügt.

## 6. Vitest-Konventionen

- Tests neben dem Code (P6); Environment nach Zweck via Projects-Split oder
  `// @vitest-environment`-Direktive (P7).
- `.env.test` mit Dummies, von der Config selbst geladen — nie `.env.local`
  (P5). Ein `TEST_MODE=1`-Schalter stubbt Mail/LLM/Compute/Auth.
- Coverage-Ratchet erst, wenn Bestand zu verteidigen ist: Schwellen auf
  Ist-Stand kalibrieren (Nachkommastellen), nur anheben; 100-%-Gates auf
  einzelne kritische Module; Scope auf Logik-/API-Schichten (P23).

## 7. Checkliste „neues Repo auf Standard"

1. Runner einrichten (Vitest/pytest), Tests neben den Code, `.env.test`,
   `TEST_MODE`-Stubs.
2. `ci.yml` nach Abschnitt 1/2; stabile Job-Namen.
3. Bei UI: Playwright mit realen Geräteprojekten, Smoke < 5 min, Full-Suite als
   Nightly, CI-Worker gemessen und in der Config gepinnt.
4. Ruleset nach Abschnitt 4 — erst nach dem ersten grünen `main`-Lauf.
5. Dependency-Bot gruppiert; `npm audit --audit-level=high` blockierend bei
   Deploy-Ziel; Automerge nur mit aktivem Ruleset.
6. Coverage-Ratchet vertagen, bis es Bestand gibt.
