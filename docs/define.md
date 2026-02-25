# Headway

**Headway** is a progress oversight tool. It gives executives a continuously updated view of how things are going — what's done, what's in progress, and what needs attention.

---

## What It Is

A living report document. Not a task manager, not a project board — a **report** that stays current.

- Formatted as Markdown (`.md`)
- Structured issue-by-issue, with dates
- Updated constantly (target: every few hours)
- Accessible to anyone at any time — open the file and read
- Published to where teams already work (see [Publish Targets](#publish-targets))

Think of it as a newspaper for your organization's work, rewritten every hour.

## Who It's For

**Primary audience: C-suite and executives** — CEO, CTO, VP-level leaders who need a high-level pulse on everything without attending every standup or reading every Slack thread.

Executives shouldn't have to ask "how's Project X going?" The answer should already be in Headway, updated as of the last hour.

## What It Covers

Headway tracks progress across:

| Category              | Examples                                      |
|-----------------------|-----------------------------------------------|
| **Issues**            | Bugs, blockers, incidents                     |
| **Tasks**             | Discrete units of work                        |
| **Plans**             | Strategic or tactical plans in flight         |
| **Routines**          | Recurring processes and their health          |
| **Projects**          | Multi-step efforts with timelines             |
| **Experiments**       | Trials, A/B tests, exploratory work           |
| **Idea Exploration**  | Early-stage thinking being pursued            |
| **Goals**             | Measurable targets and their trajectory       |

Each item gets its own section in the report, maintained over time.

Every item carries two essential attributes:

- **Due date** — when it's expected to be done. AI tracks proximity and flags items approaching or past their deadline.
- **Assigned people** — who owns it (`@name`). Makes accountability visible at a glance.

---

## The Role of AI

AI is central to Headway. It does three things:

### 1. Collect

Headway works automatically. It gathers information from three channels — all via DingTalk, requiring minimal employee effort:

**Channel 1: DingTalk group chats (fully automatic)**

Headway scans relevant DingTalk group chats each cycle. AI reads messages and:

- Matches updates to existing tracked items
- Flags new things that should be reported (new issues, emerging blockers, etc.)
- Extracts progress signals, decisions, blockers, and deadlines
- Filters out noise (casual chat, off-topic)

No employee action required — conversations they're already having become input.

**Channel 2: Shared folder on DingTalk Docs (employee-uploaded)**

A shared folder where employees upload formal documents: meeting transcripts, weekly reports, status updates, etc. Convention over configuration — naming conventions replace config files:

```
Headway (shared folder)/
├── Project Alpha/
│   ├── 2026-02-25-weekly.md
│   ├── 2026-02-20-meeting.md
│   └── 2026-02-18-kickoff.md
├── Project Beta/
│   └── 2026-02-24-status.md
├── Login Timeout/
│   ├── 2026-02-22-report.md
│   └── 2026-02-24-resolved.md
├── Data Sync Failure/
│   └── 2026-02-25-update.md
├── Q1 Revenue Target/
│   └── 2026-02-25-update.md
├── Hiring 3 Engineers/
│   └── 2026-02-20-progress.md
└── _templates/
    ├── weekly-update.md
    ├── meeting-notes.md
    └── issue-report.md
```

### Naming conventions

**Folders:**
- Folder name = section title in the report. `Project Alpha/` becomes `### Project Alpha` in the output.
- No slugs, no IDs — use the human-readable name directly.
- Create a folder to start tracking a thing. Delete it (or prefix with `_`) to stop.

**Files:**
- `YYYY-MM-DD-<description>.md` — date first for chronological sorting.
- Description is freeform: `weekly`, `meeting`, `status`, `resolved`, etc.
- Headway reads all files in a folder to build that item's narrative.

**Special folders:**
- `_templates/` — starter templates for employees. Ignored by Headway.
- Any folder prefixed with `_` is ignored (e.g., `_archived/`, `_drafts/`).

### Convention over configuration

| Convention | Effect |
|---|---|
| Folder exists | Item appears in the report |
| Folder name | Becomes the section title |
| File date prefix | Determines chronological order |
| Folder prefixed with `_` | Ignored by Headway |
| No files updated recently | AI may flag as stale |

**Channel 3: DingTalk Todo & Task API (fully automatic)**

Headway pulls structured task data directly via the DingTalk Open API:

- Task status (pending, in-progress, completed)
- Assignees, due dates, completion dates
- Task creation and updates

This provides hard data — no interpretation needed. AI cross-references this with the softer signals from channels 1 and 2 to build the full picture.

### 2. Synthesize

AI processes what it collected and writes each issue's section:

- Extracts relevant updates from multiple sources
- Composes a coherent narrative of what happened and what's next
- Removes noise, keeps signal

### 3. Indicate Status

AI maintains the state of each item:

| Indicator | Meaning                        |
|-----------|--------------------------------|
| 🟢 Green  | On track / healthy             |
| 🟡 Yellow | Needs attention / at risk      |
| 🔴 Red    | Blocked / off track / overdue  |
| ✅ Checked | Finished / resolved           |

For finished items, AI composes a **review** — a brief summary of what was accomplished, how it went, and any lessons learned.

---

## Report Structure (Sketch)

```
# Headway Report — 2026-02-25

## Projects

### 🟢 Project Alpha
Due: 2026-03-15 · @alice @bob
Last updated: 2026-02-25 14:00
Sprint 4 is on track. Backend migration completed Monday.
Frontend integration in progress — expected done by Thursday.
No blockers.

### 🟡 Project Beta
Due: 2026-03-01 · @carol @dave
Last updated: 2026-02-25 13:00
Design review delayed by 2 days due to stakeholder availability.
Dev work can begin once designs are approved. Not yet critical,
but will turn red if not resolved by Friday.

## Issues

### ✅ Issue #42 — Login timeout
Due: 2026-02-24 · @eve
Resolved: 2026-02-24
**Review:** Root cause was connection pool exhaustion under load.
Fix deployed Monday, monitored for 24h, no recurrence. Took 3 days.

### 🔴 Issue #58 — Data sync failure
Due: 2026-02-26 · @frank @grace
Last updated: 2026-02-25 12:00
Sync between billing and analytics has been failing since Feb 23.
Team investigating — suspected schema mismatch after last migration.
Blocking: monthly revenue dashboard.

## Goals

### 🟢 Q1 Revenue Target
Due: 2026-03-31 · @vp-sales
$2.1M of $2.5M target reached (84%). On pace.

### 🟡 Hiring — 3 Engineers by March
Due: 2026-03-31 · @hiring-manager
2 of 3 offers extended. 1 accepted, 1 pending response.
Third candidate in final round. Tight but achievable.
```

---

## Publish Targets

Headway generates the report, then pushes it to where teams already read. The same report can be published to multiple targets simultaneously.

| Target | Use case |
|---|---|
| **DingTalk Doc (钉钉文档)** | Primary target for the Chinese subsidiary. Updated in-place via DingTalk Open API so employees see the latest report directly in DingTalk. |
| **Markdown file** | A `.md` file in a Git repo or shared drive — the canonical source. |
| **Other platforms** | Google Docs, Notion, Confluence, etc. — added as needed. |

### DingTalk integration

Headway connects to DingTalk via the [DingTalk Open Platform](https://open.dingtalk.com/) APIs:

1. Register an enterprise app → obtain `AppKey` / `AppSecret`
2. Authenticate → get `accessToken`
3. On each refresh cycle, update the DingTalk Doc in place using the document API
4. Employees open the doc in DingTalk at any time — always current



See [docs/develop.md](develop.md) for technical architecture and implementation details.
