# Pulse Chronicle

---

## The Problem — 25 February 2026

A CEO should not have to read Slack threads to know what is happening in the company.

That is the problem Pulse was built to solve. Not project management. Not task tracking. Not another dashboard with charts nobody reads. A **living report** — a newspaper for the organisation, rewritten continuously, that tells the executive exactly what matters right now: what is on track, what is at risk, what needs a decision.

The first commit landed at 11:34 AM. By midnight, the entire pipeline was running.

## Headway — Day One

The project was called **Headway** on day one. The name described progress — but the product was not about progress. It was about awareness.

The build followed a clean arc across thirteen hours:

**Morning** — scaffold, config loader, local file collector. The convention-over-configuration design: drop files into folders named by topic, date-prefix them, and the collector picks them up. No database, no API calls, no authentication. Just files on disk, organised by convention.

**Midday** — OpenAI client, synthesizer, ERB report renderer, markdown publisher. The AI pipeline: collect inputs, send them to a language model with a carefully crafted prompt, render the response into a structured report, write it to a file. Simple. Mechanical. Reliable.

**Afternoon** — multi-provider support. The OpenAI client became one of several. Faraday replaced net/http. Zeitwerk replaced require_relative chains. Thor replaced a hand-rolled case statement. The rough scaffold became a proper gem-shaped tool.

Then the pivot that defined the product: **DingTalk integration.**

DingTalk is the enterprise communication platform used by the company. It is where work happens — group chats, daily reports (日志), todo lists, shared documents, meetings. If Pulse is a newspaper, DingTalk is the newsroom.

The DingTalk client landed with token lifecycle management, pagination, and legacy API error handling. Then the collectors: Reports (日志), Todos, Meeting Notes. Then the publisher — not writing to a markdown file, but updating a living document inside DingTalk itself.

By midnight, Pulse was collecting real data from a real company's DingTalk workspace and synthesizing it into Chinese-language reports with traffic-light status indicators. Green: on track. Yellow: needs attention. Red: blocked. Checked: done.

## The Rename — 26 February 2026

On day two, Headway became **Pulse**.

The name change was precise. Headway implies forward motion — a project management concept. Pulse implies a vital sign — a continuous reading of organisational health. The CEO does not need to know that a task moved from column A to column B. The CEO needs to feel the heartbeat of the company: is it strong? Is it irregular? Does something need immediate attention?

The rename landed at commit `394c8ea`, version 0.2.0. After that, everything accelerated.

## The Bot — 26 February 2026

The second day brought the feature that transformed Pulse from a batch job into an interactive colleague.

A DingTalk Stream client connected Pulse to real-time messaging. When someone @mentions the Pulse bot in a group chat, it reads the message, detects if a DingTalk document link is shared, fetches the document content, synthesizes it against existing context, and replies directly in the conversation with a formatted report.

The bot does not wait for a scheduled run. It responds when asked. Share a document, tag the bot, get a synthesized analysis back in the same thread.

The fast path emerged — incremental document-to-report merging. Instead of re-synthesizing everything from scratch, Pulse merges new document content into the existing report, updating only the sections that changed. The report is a living document that grows richer with every input, not a snapshot that is thrown away and rebuilt.

## Two Days, One Pipeline

Fifty-seven commits across two days. The pipeline that emerged:

1. **Collect** — from DingTalk daily reports, todo lists, shared documents, and bot @mentions. Convention-based local files as a fallback for anything DingTalk does not cover.
2. **Synthesize** — two-stage AI pipeline. First pass extracts discrete issues from raw inputs. Second pass synthesizes each issue with owner, due date, status, and context.
3. **Render** — structured report with traffic-light indicators. Chinese language. Date-stamped.
4. **Publish** — to a living DingTalk document that the CEO can open at any time and see the current state of everything.

The scheduled mode runs every 48 hours. The bot mode responds in real time. Both feed the same living document.

## What Pulse Is

Pulse is not a dashboard. Dashboards require the reader to interpret data. Pulse interprets the data and presents conclusions.

Pulse is not a task manager. Task managers track what people said they would do. Pulse tracks what is actually happening — synthesized from the signals people generate in the course of doing their work: their daily reports, their chat messages, their shared documents.

Pulse is a newspaper with one reader: the person who needs to know everything without reading everything. Written by AI. Updated continuously. Always current. Always in the language the reader speaks.

The CEO opens the document. Reads for two minutes. Knows the state of the company. Goes back to the work that only a CEO can do.

That is the product.
