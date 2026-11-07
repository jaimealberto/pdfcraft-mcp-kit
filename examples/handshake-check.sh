#!/usr/bin/env bash
#
# handshake-check.sh — comprueba que pdfcraft responde como servidor MCP.
#
# Hace tres verificaciones:
#   1) La CLI está instalada y responde a --version
#   2) El servidor MCP contesta a un 'initialize' JSON-RPC por stdio
#   3) (si existe 'claude') aparece registrado en Claude Code
#
set -euo pipefail

BIN="${PDFCRAFT_BIN:-pdfcraft-cli}"

ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m✗\033[0m %s\n' "$*"; }

# 1) CLI presente
if ! command -v "$BIN" >/dev/null 2>&1; then
  err "No encuentro '$BIN' en el PATH"
  exit 1
fi
VER="$("$BIN" --version 2>/dev/null | head -1 || true)"
ok "CLI presente: ${VER:-desconocida}"

# 2) Handshake MCP (initialize)
REQ='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"handshake-check","version":"1.0"}}}'
RESP="$(printf '%s\n' "$REQ" | timeout 10 "$BIN" mcp --compact 2>/dev/null | head -1 || true)"
if printf '%s' "$RESP" | grep -q '"result"'; then
  ok "El servidor MCP responde al 'initialize'"
else
  warn "No obtuve una respuesta 'result' al initialize (¿versión antigua o timeout?)"
  warn "Respuesta cruda: ${RESP:-<vacía>}"
fi

# 3) Registro en Claude Code
if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -qi 'pdfcraft'; then
    ok "Registrado en Claude Code (claude mcp list)"
  else
    warn "No aparece en 'claude mcp list' — regístralo con install.sh --mcp"
  fi
else
  warn "Comando 'claude' no encontrado; omito la comprobación de registro"
fi
