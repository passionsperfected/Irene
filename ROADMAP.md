# IRENE — Feature Roadmap

Tracks larger feature work. Bug-level items live in `BUGS.md`. As features ship,
move them out of "Planned" into a "Shipped" section with a date.

---

## Planned

### Sprint Goals
A pane for high-level work planning across one or more sprints.

**Data model**
- `Sprint` — id, name, optional start/end dates, sort order, list of goals
- `SprintGoal` — id, title, description, DRI (Directly Responsible Individual,
  free-text name for now), status (`planned` / `in_progress` / `done` /
  `dropped`), created/modified timestamps

**Storage**
- One JSON file per sprint at `vault/sprints/<sprint-id>.json` with goals nested
  inside the sprint document. Goals are tightly bound to their sprint, so a
  single document is simpler than a directory-per-sprint layout.

**View**
- List of sprints (newest first by default; reorderable later)
- Each sprint card expands to show goals with title, DRI badge, status pill
- Inline editing for goals; sprint-level "+ Add Goal" button
- Sheet-based detail editor for the full description

**Future**
- Promote DRI from free-text to a structured `Person` record (name, email,
  avatar) once we have other modules that need it.
- Goal → ToDo conversion (drop a goal into the To Do inbox).

---

### GitHub Integration
A pane that pulls open PRs from configured repos and surfaces metrics.

**Configuration** (lives in `VaultConfiguration`)
- `apiKeys["github"]` — Personal Access Token (read-only `repo` scope is enough)
- `githubRepos: [String]` — list of `owner/name` repo identifiers

**Data**
- Pull from `GET /repos/{owner}/{repo}/pulls?state=open&per_page=100`
- For comment counts use the `comments` and `review_comments` fields on the PR
  payload — avoids an extra round trip per PR.

**Metrics shown**
- Open PR count (per repo and total)
- Average PR age (days since `created_at` for currently-open PRs)
- Average comments per PR (issue comments + review comments)
- Per-author breakdown: who has open PRs, how many

**View**
- Repo picker (chips: All / repo1 / repo2 / …)
- Summary cards: Open Count, Avg Age, Avg Comments
- Author bucket: collapsible group per author with their PRs
- Per-PR row: title, link (opens in browser), age, comment count, body preview

**Notes**
- Manual refresh button. No background polling in v1.
- If no token is configured, show an empty state with a "Configure in
  Settings" CTA.
- Errors (auth failure, rate limit) surface as an inline banner.

---

### Radar (Project Management — placeholder)
A pane reserved for future integration with a project-management service
(Linear, Jira, Asana, etc.). For now it renders a "Coming Soon" empty state so
the slot exists in the navigation.

---

### Vacation Tracker
Track accrued PTO and warn when balance is approaching the cap so the user
can plan time off proactively.

**Configuration** (in `VaultConfiguration`)
- `vacation.hoursPerCycle: Double` — how many hours accrue per pay cycle
- `vacation.payCycleType: PayCycleType` — `biweekly` / `semiMonthly` /
  `monthly`
- `vacation.anchorDate: Date` — start of a known pay cycle (for biweekly)
- `vacation.maxHours: Double` — cap above which no further accrual happens
- `vacation.startingBalance: Double` — balance as of `anchorDate`

**Data model**
- `VacationDay` — id, date, hours (default 8), note. One JSON file per day in
  `vault/vacation/`.

**Computation**
- Iterate forward from `anchorDate`, generating cycle boundaries.
- For each cycle: balance += `hoursPerCycle`, then subtract any
  `VacationDay`s falling in that cycle. Cap at `maxHours`.
- The first cycle whose ending balance would exceed `maxHours` *before*
  capping is the "you must take time off by …" cycle. The shortfall is the
  hours the user needs to burn that cycle.
- Recompute on every config or `VacationDay` change.

**View**
- Header: current balance + max + cycle length
- Warning card if a "must take by" cycle exists in the next 90 days
- Forward projection table: next ~6 cycles with accrual / used / ending
  balance / capped flag
- List of taken/upcoming `VacationDay`s with quick-add (date + hours)

**Future**
- Roll over / fiscal-year reset rules
- Sick / personal day buckets alongside vacation
- iCal export of taken days

---

## Shipped

### 2026-05-04 — Apple-internal integrations ported from prior IRENE
- **Sandbox disabled.** Required to spawn `gh` / `appleconnect`, read PEM certs at user paths, and read configs from `~/__ai/irene_configs/`. Documented in `IRENE/Resources/IRENE.entitlements`.
- **Vacation** rewritten to the pay-period model: 2026 biweekly schedule, day-off toggling on calendar grid, per-period table with At-Risk / Covered / OK status. Reads `~/__ai/irene_configs/vacation_config.json`.
- **GitHub** uses `gh auth token --hostname X` for multi-host enterprise auth. Tracks open PRs, enriches the first 25 with review state and check-runs status. Repo list managed inline in the pane.
- **Radar** integration via AppleConnect CLI (`appleconnect getToken`) + `radar-webservices.apple.com`. My-radars / all-radars filter, board picker, state grouping, priority badges. Click a radar to open in Radar.app.
- **Work LLM toggle** in Settings. When on, chat routes through Floodgate's `anthropic.claude-opus-4-6-v1` via mTLS client certificates instead of the Anthropic API key. Non-streaming today (single-chunk reply); streaming wrapper planned.

**Carry-over from earlier in this branch:** Sprint Goals pane (with DRI), Radar placeholder (now replaced), and earlier PAT-based GitHub / hours-based Vacation panes (replaced).
