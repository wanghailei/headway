# Headway — Technical Architecture

See [define.md](define.md) for product definition.

---

## Language: Ruby

Ruby is the primary language. It excels at text processing and template generation — exactly what report synthesis requires. AI integration is HTTP API calls, which Ruby handles well.

## Core Loop

Headway is a **scheduled job**, not a web server. It runs a simple cycle:

```
┌─────────────────────────────────────────────────┐
│                  Every N hours                   │
│                                                  │
│  1. Collect   ─→  Pull from data sources (APIs)  │
│  2. Synthesize ─→  Call LLM to write the report  │
│  3. Publish   ─→  Push to targets (DingTalk, .md)│
│  4. Sleep     ─→  Wait for next cycle            │
│                                                  │
└─────────────────────────────────────────────────┘
```

## AI Provider

Configurable via environment variables. Uses the OpenAI-compatible API format — switching providers is just a base URL and API key change.

| Provider | Notes |
|---|---|
| **OpenAI** | Default for development. General-purpose, strong English, widely tested. |
| **DeepSeek** | For China deployment — low latency, good quality, cost-effective. |
| **Qwen (通义千问)** | Alibaba ecosystem alignment (same as DingTalk), strong Chinese language support. |

**Development starts with OpenAI.** Once the core loop works, benchmark against DeepSeek and Qwen on real reports to choose the production provider for the Chinese subsidiary.

## Where It Runs

| Environment | Purpose |
|---|---|
| **Local machine** | Development and staging. Run manually or via cron to test the full cycle. |
| **Alibaba Cloud** | Production. Scheduled job via ECS + cron, or Function Compute for serverless. |

Deployment path: develop locally → test the full collect-synthesize-publish cycle → deploy to Alibaba Cloud when ready.

## Project Structure

```
headway/
├── docs/
│   ├── define.md            # Product definition
│   └── develop.md           # This file
├── lib/
│   ├── collectors/          # One file per data source
│   │   ├── dingtalk.rb
│   │   └── markdown_files.rb
│   ├── synthesizer.rb       # LLM prompt + report generation
│   ├── publishers/          # One file per publish target
│   │   ├── dingtalk_doc.rb
│   │   └── markdown_file.rb
│   └── headway.rb           # Orchestrator: collect → synthesize → publish
├── config/
│   └── headway.yml          # Data sources, publish targets, schedule
├── templates/
│   └── report.md.erb        # Report template
└── bin/
    └── headway               # Entry point: `bin/headway run`
```

## Dependencies

Ruby stdlib, Rails-ecosystem gems, and well-known battle-tested gems.
Tracks **Rails edge** (github/main).

### Stdlib

| Module | Purpose |
|---|---|
| `net/http` | HTTP client — calls AI APIs, DingTalk API |
| `uri` | URL parsing |
| `json` | JSON encode/decode for API requests and responses |
| `erb` | Report template rendering |
| `yaml` | Config file loading |
| `logger` | Logging |
| `fileutils` | File and directory operations |
| `openssl` | HTTPS/TLS (used automatically by `net/http`) |
| `minitest` | Testing |

### Rails-ecosystem gems

| Gem | Via Rails | Useful for |
|---|---|---|
| `thor` | railties | CLI framework |
| `zeitwerk` | railties | Autoloading |
| `concurrent-ruby` | activesupport | Scheduled loop, thread-safe operations |
| `nokogiri` | actiontext | Parsing DingTalk HTML responses |
| `puma` | default Gemfile | Test server |
| `rack` | actionpack | HTTP interface (if needed) |

### Battle-tested gems (as needed)

Famous, proven gems are allowed. Introduce only when they earn their place.
Examples: `faraday`, `dotenv`, `dry-*`, `sidekiq`, etc.

## Configuration

```yaml
# config/headway.yml
ai:
  provider: openai
  base_url: https://api.openai.com/v1
  model: gpt-4o
  # api_key via ENV: HEADWAY_AI_API_KEY

collectors:
  - type: markdown_files
    path: ./input/

publishers:
  - type: markdown_file
    path: ./output/report.md
  - type: dingtalk_doc
    doc_id: <dingtalk-doc-id>
    # credentials via ENV: DINGTALK_APP_KEY, DINGTALK_APP_SECRET

schedule:
  interval_hours: 2
```

## Environment Variables

| Variable | Purpose |
|---|---|
| `HEADWAY_AI_API_KEY` | API key for the LLM provider |
| `HEADWAY_AI_BASE_URL` | Override base URL (for DeepSeek/Qwen) |
| `DINGTALK_APP_KEY` | DingTalk enterprise app key |
| `DINGTALK_APP_SECRET` | DingTalk enterprise app secret |
