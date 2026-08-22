# Fix the Codex ACP adapter after the codex-acp 1.6.2 upgrade

Diagnosed 2026-08-22. Root cause is known, the values are measured, the edit is
~4 lines. Nothing here is a guess. Apply when convenient.

## Symptom

`<leader>aa` chat with `adapter = { name = "codex" }` showed:

```
[acp::connect_and_authenticate] Failed to initialize
```

`codex logout` / `codex login` / restarting Neovim do not help, because the CLI
login was never the problem.

## What actually happened (two separate breakages, in order)

1. **Stale bridge binary.** CodeCompanion's `codex` adapter does not call the
   `codex` CLI. It spawns a separate binary, `codex-acp`
   (`lua/codecompanion/adapters/acp/codex.lua`, `commands.default`). That binary
   was homebrew `codex-acp` 0.15.0 while the CLI was `codex-cli` 0.149.0.
   `~/.codex/config.toml` line 2 is `model_reasoning_effort = "max"`, which the
   new CLI accepts but 0.15.0 did not, so the bridge died parsing the config
   before the ACP handshake:

   ```
   $ echo '{...initialize...}' | codex-acp
   Error: error loading config: /Users/mtkh97/.codex/config.toml:2:26:
     unknown variant `max`, expected one of `none`, `minimal`, `low`, `medium`, `high`, `xhigh`
   ```

   **Already fixed:** `brew upgrade codex-acp` -> 1.6.2 (0.15.0 -> 1.6.2, pulled a
   new `node` too). Verified: `initialize` now returns a normal result with
   `"max"` still in `config.toml`.

2. **The upgrade renamed the auth method, so the nvim config is now wrong.**
   0.15.0 advertised `authMethods` id `chatgpt`. 1.6.2 advertises `api-key` and
   `chat-gpt` (with a hyphen). `lua/plugins/codecompanion.lua` still says
   `auth_method = "chatgpt"`, and `codecompanion/acp/init.lua:227` hard-fails
   when the wanted id is not advertised, which surfaces as the same
   `Failed to initialize` line. So the error message is unchanged but the cause
   is now this, not (1).

## The edit

In `lua/plugins/codecompanion.lua`, the `adapters.acp.codex` extend block:

```lua
defaults = {
  auth_method = "chat-gpt",          -- was "chatgpt"; renamed in codex-acp 1.x
  session_config_options = {
    model = "gpt-5.6-sol",
    thought_level = "high",
  },
},
```

- `auth_method` must be exactly `chat-gpt`. The adapter's own comment
  (`adapters/acp/codex.lua:21`) already documents `"api-key"|"chat-gpt"`.
- Reasoning effort is a **session config option named `thought_level`**, not
  `model_reasoning_effort` (that is the `config.toml` spelling, a different
  surface). CodeCompanion sets it through
  `interactions/chat/acp/defaults.lua`, and warns
  `No config option with category ...` if the name is wrong.
- Do NOT keep the old commented `session_config_options = { model = "gpt-5.4" }`
  block as the reference. `gpt-5.4` still exists but is two generations back.

## Values actually advertised by codex-acp 1.6.2

Read off a live `initialize` -> `authenticate(chat-gpt)` -> `session/new` probe,
so this is what the bridge really accepts (not what the docs claim):

- `model`: `gpt-5.6-sol` (current default), `gpt-5.6-terra`, `gpt-5.6-luna`,
  `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`
- `thought_level`: `low`, `medium`, `high`, `xhigh`, `max`, `ultra`
- `mode`: `read-only`, `agent` (default), `agent-full-access`
- `collaboration_mode`: `default`, `plan`
- `model_config`: `off` (default), `on`

`gpt-5.6-sol` is available, so the wanted default needs no fallback to
`gpt-5.5`. Note the session default effort is `max` (inherited from
`config.toml`); pinning `thought_level = "high"` is a deliberate step DOWN for
everyday chat and leaves the CLI/TUI untouched.

## Verify after editing

1. Restart Neovim (the adapter is resolved once per chat).
2. `<leader>aa`, then `ga` -> the adapter row should read Codex with the model
   `gpt-5.6-sol`.
3. Send one short prompt. A reply means initialize + authenticate + session/new
   all passed.
4. If it fails again, `:CodeCompanion` log first. `Auth method X is not
   advertised by the agent; available methods: ...` means the ids moved again
   (re-run the probe); a config-parse error means `codex-acp` fell behind the CLI
   again and needs another `brew upgrade`.

## Standing gotcha

`codex-acp` and `codex` are versioned and released separately, and the bridge
reads the CLI's `~/.codex/config.toml`. Any new `config.toml` value from a CLI
update can break the older bridge, and a bridge update can rename ACP ids. When
Codex chat breaks in Neovim, test the bridge directly before touching auth:

```sh
mkfifo /tmp/acp.fifo
{ printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{"fs":{"readTextFile":true,"writeTextFile":true}},"clientInfo":{"name":"t","version":"1"}}}'; sleep 5; } > /tmp/acp.fifo &
timeout 10 codex-acp < /tmp/acp.fifo
```

Piping without holding stdin open exits immediately with no output, which looks
like a hang or a silent failure. It is just EOF.
