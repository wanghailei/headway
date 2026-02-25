# Gem Refinement Design

Modernise Headway's dependency stack from pure stdlib to stdlib + battle-tested gems.

## Changes

| Step | Gem | Replaces | Impact |
|------|-----|----------|--------|
| 1 | Gemfile + Bundler | Nothing | Foundation for all other gems |
| 2 | `dotenv` | Manual `export` | Loads `.env` automatically |
| 3 | `faraday` | Raw `net/http` | Cleaner HTTP in AI clients |
| 4 | Faraday test stubs | WEBrick server | Fixes hanging tests on Ruby 4.0 |
| 5 | `zeitwerk` | `require_relative` chains | Autoloading |
| 6 | `thor` | Hand-rolled `case` CLI | Proper CLI framework |

## Order

Sequential — each step builds on the previous. Tests pass at every commit.

## Files affected

- New: `Gemfile`, `.env.example`
- Modified: `lib/headway.rb`, `lib/headway/ai_client.rb`, `lib/headway/anthropic_client.rb`, `lib/headway/runner.rb`, `bin/headway`, `test/test_helper.rb`, `test/headway/test_ai_client.rb`
