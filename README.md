# pdfcraft-mcp-kit

> [English version](README.en.md)

Kit de integración **no oficial** para instalar [pdfcraft](https://github.com/storytold/pdfcraft) (editor/lector de PDF local, escrito en Rust) y registrarlo como servidor **MCP** en [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

> ⚠️ **Proyecto no oficial.** No está afiliado ni avalado por los autores de pdfcraft. Este kit **no redistribuye** el binario: el instalador descarga los artefactos oficiales desde las releases de upstream y **verifica su integridad** antes de instalar. Ver [`NOTICE`](NOTICE).

## Qué hace

- **Instala la CLI** de pdfcraft desde el último release oficial (o una versión concreta).
- **Verifica el SHA256** de cada artefacto contra el `SHA256SUMS.txt` del release (y, opcionalmente, la **firma GPG**).
- Crea un **symlink** en `~/.local/bin` para tenerla en el PATH.
- Opcional `--gui`: instala también la **AppImage** y un lanzador `.desktop`.
- Opcional `--mcp`: **registra el MCP** en Claude Code, preguntándote por un directorio de trabajo acotado (*automation root*).

## Requisitos

- Linux x86_64 o aarch64.
- `curl`, `tar`, `sha256sum` (presentes en casi cualquier distro).
- Opcional: `gpg` (para `--verify-gpg`), `claude` (Claude Code, para `--mcp`).

> En macOS y Windows usa el instalador oficial del proyecto upstream.

## Instalación

```bash
git clone https://github.com/jaimealberto/pdfcraft-mcp-kit.git
cd pdfcraft-mcp-kit
chmod +x install.sh examples/handshake-check.sh

./install.sh                 # solo la CLI
./install.sh --gui           # CLI + app de escritorio (AppImage + lanzador)
./install.sh --mcp           # CLI + registro MCP en Claude Code
./install.sh --gui --mcp     # todo
./install.sh --verify-gpg    # verifica también la firma GPG del release
./install.sh --version 0.19.0
```

Variables de entorno opcionales:

| Variable | Default | Qué controla |
|---|---|---|
| `PDFCRAFT_PREFIX` | `~/.local/opt/pdfcraft` | Dónde se instala el binario |
| `PDFCRAFT_BINDIR` | `~/.local/bin` | Dónde se crea el symlink |

## Verificar que funciona

```bash
examples/handshake-check.sh
```

Comprueba que la CLI responde, que el servidor MCP contesta a un `initialize` y (si tienes `claude`) que está registrado.

## Registro MCP manual

Si prefieres no usar `--mcp`, añade a mano la entrada de [`examples/mcp-config.example.json`](examples/mcp-config.example.json) a la sección `mcpServers` de tu `~/.claude.json`, o ejecuta:

```bash
claude mcp add -s user pdfcraft -- pdfcraft-cli mcp \
  --automation-read-root  /ruta/a/tu/directorio-de-trabajo \
  --automation-write-root /ruta/a/tu/directorio-de-trabajo \
  --compact
```

- `--compact` expone un núcleo de tools + `tool_search`/`tool_call` (el MCP completo son cientos de tools; sin `--compact` inundaría el contexto).
- Tras añadirlo en caliente, reconecta con `/mcp` o reinicia Claude Code.

## 🔒 Nota de seguridad — automation roots

El MCP de pdfcraft puede **leer y escribir** ficheros dentro de los directorios que le pases como *roots*. **Cuanto más amplio el root, más expuesto quedas:**

- Elige un **directorio de trabajo acotado**, no tu `$HOME` entero si puedes evitarlo.
- `--automation-read-root` y `--automation-write-root` pueden apuntar a rutas distintas (p. ej. lectura amplia, escritura acotada).
- pdfcraft es software en fase alfa: no le des de comer PDFs no confiables en directorios sensibles.

## Licencia

- Este kit (instalador, docs, ejemplos): **MIT** — ver [`LICENSE`](LICENSE).
- pdfcraft: **MIT OR Apache-2.0**, de [storytold/pdfcraft](https://github.com/storytold/pdfcraft) — ver [`NOTICE`](NOTICE).
