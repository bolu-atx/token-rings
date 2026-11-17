# token-rings

A macOS menu bar app that shows token usage from Claude, Codex, DeepSeek, and
Muse in one ring.

The ring splits by each provider's share of today's tokens. Click the icon to
see per-provider totals, 5-hour and weekly availability, and reset times. Click
a provider row to open its usage dashboard.

## Requirements

- macOS 14 or later.
- Command Line Tools to build.
- Xcode to run the tests. `scripts/test.sh` sets `DEVELOPER_DIR` when Xcode is
  installed.

## Build and run

```bash
./scripts/build-app.sh
open dist/TokenRings.app
```

The script builds a menu bar-only app bundle at `dist/TokenRings.app`.

## Tests

```bash
./scripts/test.sh
```

## Data sources

| Provider | Tokens | Window limits |
| --- | --- | --- |
| Claude | `~/.claude/projects/**/*.jsonl` | claude-hud cache at `~/.claude/plugins/claude-hud/.usage-cache.json` |
| DeepSeek | `~/.claude/projects/**/*.jsonl` and `~/.pi/agent/sessions/**/*.jsonl` | None. DeepSeek uses API billing. |
| Codex | `~/.codex/sessions/**/*.jsonl` | `rate_limits` from the newest Codex session |
| Muse | `~/.local/share/muse/sessions/**/session.jsonl` | `muse usage --json` |

Token counts include cache reads. They measure tokens processed, not billing.

Codex and DeepSeek show `No window limits` when no limit data exists. Claude
limits appear only when the claude-hud plugin has written a usage cache.

## Privacy

All readings come from local files. The app does not read OAuth credentials or
API keys. It calls `muse usage --json`, which uses the existing Muse CLI login.
No usage data is sent anywhere else.

## Debugging

```bash
# Print current readings
swift run TokenRings --dump

# Render a large icon preview
swift run TokenRings --icon-preview /tmp/icon.png
```

## License

MIT. See [LICENSE](LICENSE).
