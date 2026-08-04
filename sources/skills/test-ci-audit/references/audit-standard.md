# Test- und CI-Audit — Agenten-Anweisung

*Repository-agnostischer Prüfstandard. Ein Agent mit Lesezugriff auf ein beliebiges Repository soll damit beurteilen können: Ist die Teststrategie für **diesen** Code angemessen, wird sie **erzwungen**, und **überlebt** sie den Alltag? Ergebnis ist ein priorisierter Befundbericht — keine pauschale Forderung nach „mehr Tests".*

---

## 0. Auftrag und Erfolgskriterium

Du prüfst nicht auf Vollständigkeit gegen eine Wunschliste, sondern auf **Passung**. Drei Leitfragen, in dieser Reihenfolge:

1. **Abdeckung** — Wird jedes reale Risiko dieses Codes auf der *billigsten dafür ausreichenden* Stufe geprüft?
2. **Vollzug** — Ist das, was grün sein muss, technisch erzwungen (Gate) statt nur empfohlen?
3. **Ökonomie** — Ist die Rückmeldung schnell und stabil genug, dass sie nicht umgangen oder abgeschaltet wird?

Ein Repo mit 40 gezielten Tests und einem funktionierenden Merge-Gate ist besser bewertet als eines mit 400 Tests, die niemand blockierend ausführt.

**Zwei harte Regeln für deine Ausgabe:**

- **Kein Befund ohne Beleg.** Jede Aussage nennt Datei, Zeile oder Kommando-Output. Was du nicht im Repo gesehen hast, existiert für den Bericht nicht.
- **Keine Empfehlung ohne Kosten.** Jede Maßnahme bekommt Aufwand (S/M/L) und die Angabe, welches Risiko sie tatsächlich senkt.

---

## 1. Vokabular: Runner ≠ Testart

Verwechsle das Werkzeug nicht mit der Kategorie. Ein *Runner* (Vitest, Jest, `node --test`, pytest, Playwright, go test) findet Testdateien, führt sie aus und meldet grün/rot. Die *Testart* beschreibt, wie viel echte Welt beteiligt ist:


| Stufe | Art                                                          | Was ist echt                                                | Was ist gemockt                               | Laufzeit      |
| ----- | ------------------------------------------------------------ | ----------------------------------------------------------- | --------------------------------------------- | ------------- |
| 1     | **Statisch** (Compiler, Linter, Typecheck, Dependency-Audit) | nichts wird ausgeführt                                      | —                                             | Sekunden      |
| 2     | **Unit**                                                     | eine Funktion/ein Modul                                     | alles Externe                                 | Millisekunden |
| 3     | **Integration / Contract**                                   | mehrere echte Schichten inkl. echter Handler-/Auth-Logik    | nur der externe Upstream                      | Sekunden      |
| 4     | **E2E**                                                      | das System durch die echte Oberfläche                       | nur Geräte-Peripherie (Kamera, Mikrofon, Uhr) | Minuten       |
| 5     | **Smoke / Explorativ**                                       | echte externe Dienste bzw. nicht-deterministische Erkundung | nichts                                        | variabel      |


Stufe 2 und 3 laufen typischerweise im selben Runner; die Grenze ist fließend und für die Bewertung unerheblich. Entscheidend ist die Zuordnung **Risiko → billigste Stufe, die es nachweist**.

**Testpyramide als Sollform:** breite Basis billiger Tests, sehr schmale Spitze. Ein Repo mit mehr E2E- als Unit-Tests ist ein Befund, kein Zufall.

---

## 2. Zielbild: fünf Stufen, zwei Gates

Nicht jede Stufe muss in jedem Repo existieren. Wenn sie existiert, gehört sie an diesen Ort:


| Stufe                                            | Lokal                             | CI bei Pull Request              | CI nachts / auf Zuruf                       |
| ------------------------------------------------ | --------------------------------- | -------------------------------- | ------------------------------------------- |
| 1. Format · Lint · Typecheck                     | vor dem Commit, geänderte Dateien | vollständig, **blockiert Merge** | —                                           |
| 2. Unit + Integration (ohne Live-Credentials)    | betroffene Dateien                | vollständig, **blockiert Merge** | —                                           |
| 3. E2E-**Smoke** (wenige Kern-Pfade, &lt; 5 min) | optional vor dem Push             | **blockiert Merge**              | —                                           |
| 4. E2E-**Full-Suite**                            | auf Zuruf                         | —                                | Cron + manueller Trigger, **blockiert nie** |
| 5. Explorativ / LLM / Live-Smoke                 | Hauptort                          | **nie**                          | als Bericht/Artefakt                        |


**Merge-Gate:** Branch-Schutzregel auf dem Hauptbranch — PR-Pflicht, Required Status Checks, keine Force-Pushes. Bypass ausschließlich für Repo-Admins.

**Review-Gate:** *ein* KI-Reviewer (nicht zwei, nicht drei — sonst widersprechen sie sich und niemand liest sie). Secret-Scanning und SCA/SAST laufen daneben als eigene, serverseitige Dienste, weil generische Reviewer **kein Abhängigkeitsinventar führen** und CVEs strukturell nicht finden können.

**Warum die Full-Suite nie blockiert:** Ein Required Check auf einer 25-Minuten-Suite überlebt den Alltag nicht — er wird umgangen oder abgeschaltet. Schneller Smoke als Gate, volle Regression nachts.

**Warum nicht-deterministische Tests nie blockieren:** Sie sind *Zulieferer*. Jeder bestätigte Befund wird in einen deterministischen Test übersetzt; erst der ist Gate-fähig.

---

## 3. Prüfprinzipien

Jedes Prinzip ist als Regel formuliert, gefolgt von der Begründung — du brauchst die Begründung, um berechtigte Ausnahmen zu erkennen, statt stur Konformität zu fordern.

### A. Strategie

**P1 — Risiko bestimmt die Stufe.** Leite vor der Bewertung ein Risikomodell des Repos ab: Geld- und Datumsarithmetik, Auth/Session/Berechtigungen, Datenmigrationen, Schnittstellenverträge zu externen Systemen, Layout auf definierten Zielgeräten, Nebenläufigkeit. Prüfe dann pro Risiko, ob es *irgendwo* nachgewiesen wird — und ob das die billigste ausreichende Stufe war.

**P2 — Gate-Kriterium: deterministisch und schnell.** Nur was reproduzierbar und in wenigen Minuten fertig ist, darf Merges blockieren.

**P3 — Bugfix beginnt mit dem Test.** Ein Fix startet mit einem Test, der den Fehler reproduziert und fehlschlägt. Ein Feature benennt vorab die *eine* beobachtbare Prüfung, die es beweist. Prüfbar an der Commit-Historie — aber als **Stichprobe**, nicht als Vollerhebung: nimm die letzten ~10 Commits mit Fix-Charakter (`fix:`-Präfix oder erkennbar korrigierende Message) und prüfe, ob sie Teständerungen enthalten. Mehr Historie zu klassifizieren kostet unverhältnismäßig viel Kontext für wenig zusätzliche Aussagekraft.

**P4 — „N/A" ist ein legitimes Prüfergebnis.** Eine statische Site ohne Server hat kein Rate-Limiting, keine Sessions, keine DB-Schicht. Fordere nichts für Schichten ein, die nicht existieren, und markiere sie explizit als nicht zutreffend — sonst erzeugst du genau das Rauschen, das Reviews unglaubwürdig macht.

### B. Ausführbarkeit und Hygiene

**P5 — Die Suite läuft ohne Secrets.** Tests lesen **nie** die lokale Entwicklungs-Umgebungsdatei. Wo Tests Umgebungsvariablen brauchen: eine eigene Test-ENV-Datei mit Dummy-Werten, die die Runner-Konfiguration selbst lädt. Ein zentraler Testmodus-Schalter stubbt externe Dienste (Mail, LLM, Compute-Backend, Auth). Prüfung: klont man das Repo frisch ohne jedes Secret — läuft die Suite?

**P6 — Tests liegen neben dem Code**, nicht in einem gespiegelten Parallelbaum. Spiegelbäume veralten, weil Umbenennungen sie nicht mitnehmen.

**P7 — Environment nach Zweck.** Reine Logik ohne Browser-Umgebung, Komponenten mit DOM-Umgebung, Edge-/Worker-Funktionen in der passenden Laufzeit — per Config-Split oder Datei-Direktive. Ein Einheits-Environment für alles ist ein Befund.

**P8 — Contract-Tests statt echter Fremdsysteme.** Wo ein Frontend gegen ein separat deploytes Backend läuft, testet es die *Form* der Antworten gegen fixierte Beispiele — nicht das laufende Backend.

**P9 — Isolation verdrahten, auch bei einem Worker.** Test-Identitäten, Seed-Daten, Rate-Limit-Buckets und Cleanup werden vom Worker-Index abgeleitet, selbst wenn CI aktuell seriell läuft. Ohne diese Vorarbeit lässt sich die Parallelität später nie anheben.

**P10 — Testdaten über dieselbe Schnittstelle wie die App.** Seeding über eine geschützte Seed-Route gegen den laufenden Server, nicht über direkten Datenbankzugriff am Server vorbei. E2E gegen ein *isoliertes*, frisch aufgesetztes Backend — niemals gegen den Entwicklungs- oder Produktionsstand.

### C. CI-Mechanik

**P11 — Pfadfilter niemals auf Pull-Request-Trigger.** Ein Required Check, dessen Workflow wegen eines Pfadfilters gar nicht startet, lässt den PR **dauerhaft im Status „ausstehend" hängen** — der häufigste selbstgebaute Deadlock. Pfadfilter nur auf Push-Trigger. Alternativ: Jobs, die naturgemäß nur bei bestimmten Änderungen laufen, gar nicht erst als Required Check führen.

**P12 — Job-Namen sind eine API.** Die Branch-Schutzregel referenziert Job-Namen (inklusive Matrix-Expansion). Umbenennen ohne Anpassung der Regel legt jeden PR lahm. Kurze, stabile Namen wählen.

**P13 — Fail loud.** Kein „Fehler ignorieren"-Flag, kein `|| true` auf Prüfschritten, Linting mit Null-Warnungs-Toleranz. Weiche Prüfschritte landen unbemerkt kaputt auf dem Hauptbranch und niemand merkt es über Monate.

**P14 — Läufe abbrechen statt stapeln.** Nebenläufigkeits-Gruppe pro Workflow+Branch mit Abbruch laufender Läufe; Obergrenze für Fehlschläge bricht hoffnungslose Läufe früh ab. Teure Jobs laufen nicht nach dem Merge erneut — der PR hat es bereits bewiesen.

**P15 — Zeitpläne auf ungerade Minuten** (volle Stunden sind auf gehosteten Runnern überlaufen), immer mit manuellem Trigger daneben, damit niemand bis nachts auf eine Verifikation wartet.

**P16 — Artefakte bei Fehlschlag hochladen** (Screenshots, Traces, Server-Logs). Ohne sie debuggt man nächtliche Fehler blind.

**P17 — Blockierendes Dependency-Audit**, wo ein Deploy-Ziel existiert.

**P18 — Getrennte Jobs pro Sprach-Stack / Teilprojekt** statt eines Sammel-Jobs: getrennte Jobs = getrennte Required Checks = präzisere Fehlersignale.

### D. Ökonomie und Kalibrierung

**P19 — Parallelität ist eine Messfrage, kein Bauchgefühl.** Wenn alle Tests gegen *einen* Anwendungsserver laufen, ist dieser der Flaschenhals; mehr Worker erhöhen dann nur die Latenz pro Anfrage und treiben Tests in Timeouts. Verlange eine Messung (Durchsatz bei 1 vs. n Workern) statt einer Annahme, und prüfe, ob das Ergebnis begründet dokumentiert ist. Mehr Worker erst, wenn der Server nicht mehr der Engpass ist (Produktions-Build, ein Server je Worker, größere Runner).

**P20 — Testverhalten gehört in die Runner-Konfiguration, nicht in die Workflow-Datei.** Umgebungsvariablen in Workflows werden bei Umbauten „aufgeräumt"; die eingecheckte Config überlebt.

**P21 — Timeouts nicht aufweichen.** Der Default-Timeout ist das Frühwarnsystem für Verlangsamungen. Wer ihn hochsetzt, um Flakiness zu kaschieren, verliert das Signal. Ein hochgesetzter Timeout ohne dokumentierte Begründung ist ein Befund.

**P22 — Pollen statt schlafen.** Auf Bereitschaft warten heißt Health-Check mit Wiederholung, nie feste Wartezeit. Feste Wartezeiten sind entweder zu kurz (flaky) oder zu lang (teuer) — meistens beides.

**P23 — Coverage-Ratchet statt Wunschzahl.** Schwellwerte werden auf den *Ist-Stand* kalibriert (ruhig auf Nachkommastellen) und nur angehoben, nie gesenkt. Ergänzend 100-%-Gates auf einzelne kritische Module. Coverage-Bereich bewusst auf Logik- und Schnittstellenschichten begrenzen — die UI deckt die E2E-Suite ab. Neue Repos starten *ohne* Schwellwerte; der Ratchet kommt, sobald es Bestand zu verteidigen gibt. Eine gesenkte Schwelle in der Historie ist immer ein Befund.

**P24 — Ein einziger Verify-Entrypoint bei mehreren Laufzeiten.** In Repos mit mehreren Stacks gehört die Wahrheit in ein idempotentes Build-/Task-Skript mit Phasen-Gates, samt Dienste-Hochfahren, Health-Warten und Aufräumen bei Abbruch. Niemand soll einzelne Testbefehle aus dem Kopf zusammensuchen.

---

## 4. Audit-Verfahren

**Zugriffsvoraussetzungen — vor Phase 1 klären.** Der Dateibaum allein reicht für dieses Audit nicht: Branch-Schutz/Rulesets, Required-Check-Namen, Bypass-Rollen und die Lauf-Historie liegen hinter der Hosting-API (bei GitHub z. B. `gh api repos/<owner>/<repo>/rulesets`, `gh api repos/<owner>/<repo>/branches/<main>/protection`, `gh run list`, `gh pr checks`). Stelle vorab fest, welche dieser Quellen dir zur Verfügung stehen. Fehlt der Zugriff, weise jede betroffene Prüfung im Bericht ausdrücklich als **„nicht prüfbar"** aus — niemals stillschweigend auslassen und niemals als „nicht vorhanden" werten. Ein Audit, das Gates nicht sehen konnte, sagt das; sonst verstößt es selbst gegen „kein Befund ohne Beleg".

### Phase 1 — Inventar (nur lesen, nichts behaupten)

Erhebe, was tatsächlich da ist:

- **Manifeste und Skripte:** Paket-/Projektdatei, definierte Test-, Lint-, Build- und Typecheck-Kommandos. Welche sind dokumentiert, welche existieren nur faktisch?
- **Runner-Konfigurationen:** Unit-Runner-Config (Environments, Setup-Dateien, Coverage-Schwellen, Pools), E2E-Config (Projekte, Worker, Timeouts, Basis-URL, Server-Start).
- **Testbestand:** Anzahl und Verteilung je Stufe. Zähle Dateien und Fälle, nicht gefühlte Größe. Prüfe die Verteilung gegen die Pyramide.
- **CI-Definitionen:** alle Workflow-Dateien — Trigger, Pfadfilter, Nebenläufigkeit, Job-Namen, Cron-Zeiten, Fehlertoleranz-Flags, Artefakt-Uploads, Caches.
- **Gates:** Branch-Schutzregeln des Hauptbranches, Liste der Required Checks, Bypass-Berechtigungen. Abgleich: Stimmen die Namen der Required Checks *exakt* mit existierenden Jobs überein?
- **Review- und Sicherheitsschicht:** Reviewer-Konfiguration, Dependency-Bot (gruppiert? Automerge nur bei aktivem Gate?), Secret-Scanning, SCA/SAST.
- **Historie:** Wann liefen die Suiten zuletzt grün? Gibt es dauerhaft rote Nightlies, die niemand mehr ansieht? Enthalten Fix-Commits Tests?

### Phase 2 — Risikomodell ableiten

Liste die 5–10 Dinge, deren Bruch in diesem Repo teuer wäre. Orientierung: Was verarbeitet Geld, Zeit/Datum oder personenbezogene Daten? Wo entscheidet Code über Zugriff? Wo gibt es Migrationen ohne Rückweg? Welche externen Verträge können sich einseitig ändern? Welche Oberflächen laufen auf fest definierter Hardware?

### Phase 3 — Abdeckungsmatrix

Kreuze Risiken gegen Stufen. Jede Zeile bekommt genau eine von vier Bewertungen:

- **gedeckt** — nachgewiesen, auf angemessener Stufe
- **überdeckt** — nachgewiesen, aber teurer als nötig (z. B. E2E prüft reine Rechenlogik) → Empfehlung: nach unten verschieben
- **Lücke** — nirgends nachgewiesen
- **N/A** — Schicht existiert nicht

### Phase 4 — Vollzugsprüfung

Für jede Prüfung, die laut Zielbild blockieren soll: Läuft sie im PR? Ist sie Required Check? Startet ihr Workflow bei *jedem* PR (Pfadfilter-Falle)? Kann sie umgangen werden?

### Phase 5 — Ökonomieprüfung

Laufzeit je Job, Flakiness-Rate, Timeout-Einstellungen, Worker-Zahl mit oder ohne Messgrundlage, Cache-Nutzung, doppelte Läufe nach Merge.

**Flakiness wird gemessen, nicht geschätzt:** die letzten ~20 Läufe je Workflow ziehen (`gh run list`) und den Anteil der Läufe zählen, die erst im Retry grün wurden bzw. vom Runner als *flaky* markiert sind. Eine Retry-Zahl > 2 in der Runner-Konfiguration ohne dokumentierte Begründung ist dabei selbst ein Befund — sie ist die Retry-Variante des aufgeweichten Timeouts (P21).

### Phase 6 — Bericht

Nach der Vorlage in Abschnitt 7. Priorisiert, belegt, mit Aufwand.

---

## 5. Prüfkatalog (Schnelldurchlauf)


| #   | Prüfung                                            | Erwartung        | Schwere bei Verstoß |
| --- | -------------------------------------------------- | ---------------- | ------------------- |
| 1   | Suite läuft nach frischem Klon ohne Secrets        | ja               | **Blocker**         |
| 2   | Required Check hängt an Workflow mit PR-Pfadfilter | nein             | **Blocker**         |
| 3   | Required-Check-Namen ≠ existierende Job-Namen      | keine Abweichung | **Blocker**         |
| 4   | Branch-Schutz auf Hauptbranch aktiv                | ja               | **Hoch**            |
| 5   | Lint/Typecheck/Unit blockieren den Merge           | ja               | **Hoch**            |
| 6   | Fehlertoleranz-Flags auf Prüfschritten             | keine            | **Hoch**            |
| 7   | Tests lesen die Entwicklungs-ENV-Datei             | nein             | **Hoch**            |
| 8   | Nicht-deterministische Tests als Gate              | nein             | **Hoch**            |
| 9   | Serverseitiges Secret-Scanning + SCA/Dependency-Inventar aktiv | ja   | **Hoch**            |
| 10  | Full-Suite blockiert den Merge                     | nein             | **Mittel**          |
| 11  | Nightly existiert und ist manuell triggerbar       | ja               | **Mittel**          |
| 12  | Dependency-Audit blockierend (bei Deploy-Ziel)     | ja               | **Mittel**          |
| 13  | Artefakt-Upload bei Fehlschlag                     | ja               | **Mittel**          |
| 14  | Nebenläufigkeitsgruppe mit Abbruch                 | ja               | **Mittel**          |
| 15  | Teure Jobs laufen nach Merge erneut                | nein             | **Mittel**          |
| 16  | Worker-Zahl ohne Messgrundlage erhöht              | nein             | **Mittel**          |
| 17  | Feste Wartezeiten statt Health-Poll                | keine            | **Mittel**          |
| 18  | Timeout über Default ohne Begründung               | nein             | **Mittel**          |
| 19  | Coverage-Schwelle in der Historie gesenkt          | nein             | **Mittel**          |
| 20  | Testverteilung folgt der Pyramide                  | ja               | **Mittel**          |
| 21  | Tests liegen neben dem Code                        | ja               | **Niedrig**         |
| 22  | Environment je Testzweck getrennt                  | ja               | **Niedrig**         |
| 23  | Cron auf ungerader Minute                          | ja               | **Niedrig**         |
| 24  | Dependency-Bot gruppiert, Automerge nur mit Gate   | ja               | **Niedrig**         |
| 25  | Ein Verify-Entrypoint bei Mehr-Stack-Repos         | ja               | **Niedrig**         |


---

## 6. Anti-Pattern-Katalog

Erkenne diese Muster explizit — sie sind häufiger als fehlende Tests:

1. **Der stille Deadlock** — Required Check, dessen Workflow durch Pfadfilter nie startet. PR hängt ewig, Team greift zum Admin-Bypass, das Gate verliert seine Bedeutung.
2. **Der weichgespülte Prüfschritt** — Fehler-ignorieren-Flag oder `|| true`; das Häkchen ist grün, geprüft wird nichts.
3. **Das Alibi-Gate** — 25-Minuten-Suite als Required Check. Wird nach drei Wochen deaktiviert.
4. **Der aufgeweichte Timeout** — Grenzwert hochgesetzt, um Flakiness zu überdecken; damit ist jede spätere Verlangsamung unsichtbar.
5. **Die geratene Parallelität** — Worker-Zahl erhöht, obwohl ein einzelner Server der Engpass ist. Ergebnis: langsamer *und* flaky.
6. **Der Secret-Zwang** — Tests brauchen echte Credentials, laufen deshalb in CI gar nicht oder nur bei manchen Entwicklern.
7. **Die Kopfstand-Pyramide** — viel E2E, wenig Unit; jeder Fehler kostet Minuten statt Millisekunden zur Lokalisierung.
8. **Der Spiegelbaum** — separater Testbaum, der bei jeder Umbenennung leise veraltet.
9. **Der halluzinierte Anspruch** — Forderungen nach Sessions, Rate-Limits oder DB-Tests in Projekten, die keine solche Schicht haben.
10. **Das Review-Monokultur-Missverständnis** — Verlass auf einen KI-Reviewer für Dinge, die er strukturell nicht sehen kann (CVEs in Abhängigkeiten, Secrets im Verlauf, Infrastruktur-Drift).
11. **Die tote Nightly** — seit Wochen rot, niemand reagiert. Faktisch keine Regressionssicherung.
12. **Das gesenkte Ziel** — Coverage-Schwelle nach unten korrigiert, statt den Test nachzuziehen.

---

## 7. Berichtsvorlage

**Ausfüllreihenfolge ≠ Leseordnung:** Der Reifegrad wird als Letztes vergeben, nachdem alle Phasen abgeschlossen sind — er steht nur im Bericht vorn, weil der Leser das Fazit zuerst sehen will. Wer ihn zu Beginn festlegt, ankert seine eigene Analyse.

```markdown
# Test- & CI-Audit — <Repo>

## Kurzfazit
Reifegrad: <0–4>. <Zwei Sätze: größte Stärke, größtes Risiko.>

## Ist-Aufnahme
- Stack / Laufzeiten:
- Runner und Testbestand je Stufe (Zahlen):
- CI-Jobs und Trigger:
- Required Checks laut Branch-Schutz:
- Erkennbare Deploy-Ziele:

## Risiko-Abdeckungsmatrix
| Risiko | Nachgewiesen auf Stufe | Bewertung | Beleg |
|---|---|---|---|

## Befunde
### Blocker
- **B1 — <Titel>** · Beleg: `<datei:zeile>` · Wirkung: <was passiert konkret>
  · Gegenmittel: <kleinstmöglicher Eingriff> · Aufwand: S/M/L
### Hoch / Mittel / Niedrig
(gleiche Struktur)

## Bewusst nicht bemängelt (N/A)
- <Schicht> existiert in diesem Projekt nicht — keine Anforderung.

## Empfohlene Reihenfolge
1. … (erst Gate-Defekte, dann Lücken, dann Ökonomie, zuletzt Kosmetik)

```

---

## 8. Reifegrade


| Grad                | Merkmale                                                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **0 — ungeschützt** | Keine CI oder keine Tests. Qualität hängt an Disziplin.                                                                                                                                          |
| **1 — vorhanden**   | Tests existieren und laufen lokal, CI läuft, aber nichts blockiert.                                                                                                                              |
| **2 — erzwungen**   | Lint/Typecheck/Unit sind Required Checks, Branch-Schutz aktiv, Suite läuft ohne Secrets.                                                                                                         |
| **3 — geschichtet** | Zusätzlich: E2E-Smoke im PR, Full-Suite nachts mit Artefakten, Dependency-Audit blockierend, getrennte Jobs je Stack.                                                                            |
| **4 — kalibriert**  | Zusätzlich: Coverage-Ratchet auf Ist-Stand, gemessene statt geratener Laufzeit-Parameter, explorative/LLM-Läufe als Zulieferer mit Übersetzung in deterministische Specs, ein Verify-Entrypoint. |


Grad 2 ist das Minimum für jedes Repo mit mehr als einem Mitwirkenden. Grad 3 ab dem Moment, in dem ein Deploy-Ziel existiert. Grad 4 nur, wo Bestand zu verteidigen ist — Grad-4-Mechanik in einem zwei Wochen alten Repo ist Overhead, kein Reifezeichen.

---

## 9. Kalibrierung: wann du *nicht* eskalierst

- **Junges Repo ohne Bestand:** keine Coverage-Schwellen fordern, kein Nightly-Apparat. Empfehlung: Grad 2 herstellen, Rest vertagen.
- **Reine statische Ausgabe ohne Backend:** Stufen 3–5 weitgehend N/A.
- **Ein einzelner Mitwirkender, kein Deploy:** Branch-Schutz ist nice-to-have, nicht Blocker. Die Suite ohne Secrets lauffähig zu halten bleibt trotzdem Pflicht.
- **Bewusst dokumentierte Abweichung:** Steht im Repo eine begründete Entscheidung (mit Messwerten oder Kostenargument), akzeptiere sie und vermerke sie als Abweichung *mit* Begründung — nicht als Befund.
- **Bibliothek ohne Oberfläche:** E2E entfällt; dafür steigt der Anspruch an Contract-Tests und öffentliche API-Stabilität.

Die häufigste Fehlleistung eines Audit-Agenten ist nicht, etwas zu übersehen, sondern das Team mit formal korrekten, praktisch wertlosen Forderungen zu fluten. Priorisiere hart: drei Befunde, die jemand diese Woche behebt, schlagen dreißig, die niemand liest.