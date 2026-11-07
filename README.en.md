# pdfcraft-mcp-kit

> [Versión en español](README.md)

**Unofficial** integration kit to install [pdfcraft](https://github.com/storytold/pdfcraft) (a local, Rust-based PDF editor/reader) and register it as an **MCP** server in [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

> ⚠️ **Unofficial project.** Not affiliated with or endorsed by the pdfcraft authors. This kit does **not** redistribute the binary: the installer downloads the official upstream release artifacts and **verifies their integrity** before installing. See [`NOTICE`](NOTICE).

## What it does

- **Installs the pdfcraft CLI** from the latest official release (or a specific version).
- **Verifies the SHA256** of each artifact against the release's `SHA256SUMS.txt` (and, optionally, the **GPG signature**).
- Creates a **symlink** in `~/.local/bin` so it's on your PATH.
- Optional `--gui`: also installs the **AppImage** and a `.desktop` launcher.
- Optional `--mcp`: **registers the MCP** in Claude Code, prompting you for a scoped working directory (*automation root*).

## Requirements

- Linux x86_64 or aarch64.
- `curl`, `tar`, `sha256sum` (present on almost any distro).
- Optional: `gpg` (for `--verify-gpg`), `claude` (Claude Code, for `--mcp`).

> On macOS and Windows, use the upstream project's official installer.

## Install

```bash
git clone https://github.com/jaimealberto/pdfcraft-mcp-kit.git
cd pdfcraft-mcp-kit
chmod +x install.sh examples/handshake-check.sh

./install.sh                 # CLI only
./install.sh --gui           # CLI + desktop app (AppImage + launcher)
./install.sh --mcp           # CLI + MCP registration in Claude Code
./install.sh --gui --mcp     # everything
./install.sh --verify-gpg    # also verify the release's GPG signature
./install.sh --version 0.19.0
```

Optional environment variables:

| Variable | Default | Controls |
|---|---|---|
| `PDFCRAFT_PREFIX` | `~/.local/opt/pdfcraft` | Where the binary is installed |
| `PDFCRAFT_BINDIR` | `~/.local/bin` | Where the symlink is created |

## Verify it works

```bash
examples/handshake-check.sh
```

Checks that the CLI responds, that the MCP server answers an `initialize` request and (if you have `claude`) that it is registered.

## Manual MCP registration

If you'd rather not use `--mcp`, add the entry from [`examples/mcp-config.example.json`](examples/mcp-config.example.json) to the `mcpServers` section of your `~/.claude.json`, or run:

```bash
claude mcp add -s user pdfcraft -- pdfcraft-cli mcp \
  --automation-read-root  /path/to/your/workdir \
  --automation-write-root /path/to/your/workdir \
  --compact
```

- `--compact` exposes a core set of tools plus `tool_search`/`tool_call` (the full MCP has hundreds of tools; without `--compact` it would flood the context).
- After adding it live, reconnect with `/mcp` or restart Claude Code.

## 🔒 Security note — automation roots

The pdfcraft MCP can **read and write** files inside the directories you pass as *roots*. **The broader the root, the more exposed you are:**

- Pick a **scoped working directory**, not your entire `$HOME` if you can avoid it.
- `--automation-read-root` and `--automation-write-root` can point to different paths (e.g. broad read, scoped write).
- pdfcraft is alpha software: don't feed it untrusted PDFs in sensitive directories.

## License

- This kit (installer, docs, examples): **MIT** — see [`LICENSE`](LICENSE).
- pdfcraft: **MIT OR Apache-2.0**, by [storytold/pdfcraft](https://github.com/storytold/pdfcraft) — see [`NOTICE`](NOTICE).
