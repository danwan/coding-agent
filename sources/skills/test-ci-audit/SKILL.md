---
name: test-ci-audit
description: >
  Audit and fix a repository's test strategy, CI, and GitHub enforcement
  against our test/CI standard — coverage on the cheapest sufficient level,
  enforced merge gates (rulesets, required checks), and CI that survives
  daily use. Use whenever the user asks to audit/verify/check tests or CI,
  bring a repo up to test standard, add missing tests or CI, set up GitHub
  rulesets or branch protection, or asks "sind die Tests aktuell", "Tests
  prüfen", "CI einrichten", "Repo auf Standard bringen", "test audit",
  "check github config" — even if they only mention one aspect (just tests,
  just CI, or just branch protection), since the three are audited together.
---

# Test- und CI-Audit

Prüft ein Repository gegen unseren Test-/CI-Standard und bringt es auf Wunsch
dorthin. Zwei Modi:

- **audit** (Default) — nur lesen, priorisierter Befundbericht. Auch wenn der
  User „fix" sagt: das Audit läuft immer zuerst, der Fix arbeitet dessen
  Befunde ab.
- **fix** — Befunde in Prioritätsreihenfolge beheben (ein Draft-PR pro Repo,
  Rulesets direkt per API).

Der vollständige Prüfstandard steht in `references/audit-standard.md` — **lies
ihn vor Phase 1**, er ist die Autorität für Prinzipien (P1–P24), Prüfkatalog,
Anti-Patterns, Berichtsvorlage und Reifegrade. Diese SKILL.md ist nur der
Ablauf drumherum.

## Schritt 0 — Zugriff klären (immer zuerst)

Der Dateibaum allein reicht nicht: Rulesets, Required Checks, Bypass-Rollen und
Lauf-Historie liegen hinter der GitHub-API. Prüfe, ob `gh` authentifiziert ist
(`gh auth status`) und das Repo ein GitHub-Remote hat. Fehlt der Zugriff, laufen
Datei-Prüfungen normal weiter, aber jede API-gestützte Prüfung wird im Bericht
als **„nicht prüfbar"** ausgewiesen — nie stillschweigend ausgelassen, nie als
„nicht vorhanden" gewertet.

## Modus audit

1. **Inventar erheben:** `scripts/inventory.sh <owner/repo>` im Repo-Root
   ausführen — sammelt Workflows, Job-Namen, Rulesets, Branch-Protection,
   letzte Läufe, Testdatei-Verteilung und Stack-Signaturen in einem Durchlauf.
   Was das Script nicht abdeckt (Runner-Configs im Detail, Coverage-Schwellen,
   Commit-Stichprobe für P3), liest du gezielt nach.
2. **Phasen 2–5** aus `references/audit-standard.md`: Risikomodell →
   Abdeckungsmatrix → Vollzugsprüfung → Ökonomieprüfung. Halte dich an die
   dortigen Regeln: kein Befund ohne Beleg, N/A ist ein legitimes Ergebnis,
   Stack-Signaturen vor stack-spezifischen Forderungen prüfen.
3. **Bericht** nach der Vorlage in Abschnitt 7 des Standards. Reifegrad zuletzt
   vergeben. Hart priorisieren: drei Befunde, die diese Woche behoben werden,
   schlagen dreißig, die niemand liest.

## Modus fix

Nur nach einem Audit (frisch aus dieser Session oder vom User mitgebracht).
Reihenfolge ist nicht verhandelbar — sie folgt der Schadenshöhe:

1. **Gate-Defekte** (Blocker/Hoch): Pfadfilter-Deadlocks, weiche Prüfschritte,
   falsche Required-Check-Namen, fehlender Branch-Schutz.
2. **Abdeckungslücken**: fehlende CI, ungetestete Kernrisiken — neue Tests
   folgen den Konventionen des Repos (Runner, Ablageort, Naming), nicht denen
   eines anderen Projekts.
3. **Ökonomie**: Worker/Timeouts/Caching/Doppel-Läufe.
4. **Kosmetik** zuletzt, und nur wenn billig.

Bau-Vorlagen (Standard-`ci.yml`-Muster, Ruleset-JSON + `gh api`-Aufrufe,
Nightly-Konstruktion, Stack-Besonderheiten für Next.js/Vercel, Convex,
SQLite/Drizzle, Python/uv/Modal, statische Sites) stehen in
`references/remediation.md` — lies die Datei, bevor du Workflows oder Rulesets
schreibst, statt sie aus dem Kopf zu bauen.

Arbeitsregeln im Fix-Modus:

- **Ein Draft-PR pro Repo** für alle Datei-Änderungen; Rulesets/Protection
  laufen nicht durch den PR, sondern direkt per `gh api` — aber erst, nachdem
  die Required Checks auf `main` mindestens einmal grün gelaufen sind, sonst
  baut man den Pfadfilter-Deadlock in neu.
- Jede Ruleset-Anlage protokolliert die zurückgegebene ID (Rollback:
  `gh api -X DELETE repos/<owner>/<repo>/rulesets/<id>`).
- Bugfix-Charakter? Erst der fehlschlagende Test, dann der Fix (P3).
- Nach dem Fix: betroffene Prüfungen erneut ausführen (CI-Lauf, Ruleset-GET)
  und im Abschlussbericht Befund → Maßnahme → Verifikationsbeleg mappen.
  Nicht behobene Befunde bleiben ausgewiesen, mit Grund.

## Grenzen

- Nichts kaufen, keine externen Dienste abonnieren, keine Org-Settings ändern —
  solche Befunde nur berichten.
- Bei Monorepos mit mehreren Teilprojekten: je Teilprojekt eine eigene Zeile in
  Matrix/Jobs (P18), aber ein gemeinsamer Bericht.
- Läuft das Audit in fremden Repos (nicht des Users): Fix-Modus nur nach
  expliziter Bestätigung, Audit bleibt read-only.
