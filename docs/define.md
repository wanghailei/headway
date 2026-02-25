# Headway

**Headway** is a progress oversight tool. It gives executives a continuously updated view of how things are going — what's done, what's in progress, and what needs attention.

---

## What It Is

A living report document. Not a task manager, not a project board — a **report** that stays current.

- Formatted as Markdown (`.md`)
- Structured issue-by-issue, with dates
- Updated constantly (target: every few hours)
- Accessible to anyone at any time — open the file and read

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

AI gathers information from source materials across three categories:

**Documents & files**
- Daily reports, weekly reports
- Plans, roadmaps, campaign timelines
- Google Docs, Notion pages, Markdown files, shared drives

**Project tools**
- Jira, Linear, Asana, GitHub Issues
- Any structured task or issue tracker

**Communication**
- Slack messages and threads
- Email digests
- Meeting transcripts and minutes

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
