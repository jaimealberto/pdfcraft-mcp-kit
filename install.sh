#!/usr/bin/env bash
#
# pdfcraft-mcp-kit — instalador no oficial de pdfcraft (CLI) + registro MCP
#
# Proyecto NO oficial. pdfcraft es obra de storytold/pdfcraft (MIT/Apache-2.0):
#   https://github.com/storytold/pdfcraft
# Este script solo descarga el release oficial, verifica su integridad y lo
# instala de forma cómoda. No redistribuye el binario.
#
# Uso:
#   ./install.sh                 # instala la CLI (último release, verifica SHA256)
#   ./install.sh --gui           # además, AppImage + lanzador .desktop
#   ./install.sh --mcp           # además, registra el MCP en Claude Code
#   ./install.sh --verify-gpg    # verifica también la firma GPG del release
#   ./install.sh --version 0.19.0
#   ./install.sh --help
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración (sobreescribible por entorno)
# ---------------------------------------------------------------------------
REPO="storytold/pdfcraft"
PREFIX="${PDFCRAFT_PREFIX:-$HOME/.local/opt/pdfcraft}"
BINDIR="${PDFCRAFT_BINDIR:-$HOME/.local/bin}"
APP_BASE="https://github.com/${REPO}/releases/download"
API_LATEST="https://api.github.com/repos/${REPO}/releases/latest"

DO_GUI=0
DO_MCP=0
DO_GPG=0
VERSION=""

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
c_ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
c_info() { printf '\033[1;34m•\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
c_err()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }
die()    { c_err "$*"; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Falta la herramienta requerida: $1"; }

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ---------------------------------------------------------------------------
# Parseo de argumentos
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --gui)        DO_GUI=1 ;;
    --mcp)        DO_MCP=1 ;;
    --verify-gpg) DO_GPG=1 ;;
    --version)    VERSION="${2:-}"; shift ;;
    --prefix)     PREFIX="${2:-}"; shift ;;
    --bindir)     BINDIR="${2:-}"; shift ;;
    -h|--help)    usage ;;
    *) die "Opción desconocida: $1 (usa --help)" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Detección de plataforma
# ---------------------------------------------------------------------------
OS="$(uname -s)"
[ "$OS" = "Linux" ] || die "Este instalador solo cubre Linux (detectado: $OS). En macOS/Windows usa el instalador oficial del proyecto."

case "$(uname -m)" in
  x86_64|amd64)  ARCH="x86_64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  *) die "Arquitectura no soportada por este kit: $(uname -m)" ;;
esac

need curl
need tar
need sha256sum

# ---------------------------------------------------------------------------
# Resolver versión del último release
# ---------------------------------------------------------------------------
if [ -z "$VERSION" ]; then
  c_info "Resolviendo último release de ${REPO}…"
  REL_JSON="$(curl -fsSL "$API_LATEST")" || die "No he podido consultar la API de GitHub (prueba --version X.Y.Z)"
  TAG="$(printf '%s\n' "$REL_JSON" | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
  [ -n "$TAG" ] || die "No he podido resolver el último release (¿API de GitHub limitada? prueba --version X.Y.Z)"
  VERSION="${TAG#v}"
else
  TAG="v${VERSION#v}"
  VERSION="${VERSION#v}"
fi
c_ok "Versión objetivo: ${VERSION} (tag ${TAG})"

# ---------------------------------------------------------------------------
# Descarga + verificación
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CLI_ASSET="pdfcraft-cli-${VERSION}-linux-${ARCH}.tar.gz"
SUMS="SHA256SUMS.txt"

c_info "Descargando ${CLI_ASSET}…"
curl -fsSL -o "$TMP/$CLI_ASSET" "${APP_BASE}/${TAG}/${CLI_ASSET}" || die "Fallo al descargar ${CLI_ASSET}"
curl -fsSL -o "$TMP/$SUMS"     "${APP_BASE}/${TAG}/${SUMS}"       || die "Fallo al descargar ${SUMS}"

# Verificación GPG opcional (clave de firma publicada en el release)
if [ "$DO_GPG" -eq 1 ]; then
  need gpg
  c_info "Verificando firma GPG…"
  curl -fsSL -o "$TMP/release-signing-key.asc" "${APP_BASE}/${TAG}/release-signing-key.asc"
  curl -fsSL -o "$TMP/${SUMS}.asc"             "${APP_BASE}/${TAG}/${SUMS}.asc"
  GNUPGHOME="$(mktemp -d)"; export GNUPGHOME
  gpg --quiet --import "$TMP/release-signing-key.asc"
  if gpg --quiet --verify "$TMP/${SUMS}.asc" "$TMP/$SUMS" 2>/dev/null; then
    c_ok "Firma GPG válida sobre ${SUMS}"
  else
    rm -rf "$GNUPGHOME"
    die "La firma GPG NO verifica — abortando por seguridad"
  fi
  rm -rf "$GNUPGHOME"
fi

c_info "Verificando SHA256…"
EXPECTED="$(awk -v f="$CLI_ASSET" '{n=$2; sub(/^\*/,"",n); if(n==f){print $1; exit}}' "$TMP/$SUMS")"
[ -n "$EXPECTED" ] || die "No encuentro el hash de ${CLI_ASSET} en ${SUMS}"
ACTUAL="$(sha256sum "$TMP/$CLI_ASSET" | awk '{print $1}')"
[ "$EXPECTED" = "$ACTUAL" ] || die "SHA256 NO coincide (esperado $EXPECTED, obtenido $ACTUAL) — abortando"
c_ok "SHA256 verificado"

# ---------------------------------------------------------------------------
# Instalar CLI
# ---------------------------------------------------------------------------
c_info "Instalando CLI en ${PREFIX}…"
mkdir -p "$PREFIX" "$BINDIR"
tar -xzf "$TMP/$CLI_ASSET" -C "$TMP"
CLI_BIN="$(find "$TMP" -type f -name 'pdfcraft-cli' -perm -u+x | head -1)"
[ -n "$CLI_BIN" ] || CLI_BIN="$(find "$TMP" -type f -name 'pdfcraft-cli' | head -1)"
[ -n "$CLI_BIN" ] || die "No encuentro el binario pdfcraft-cli dentro del tarball"
install -m 0755 "$CLI_BIN" "$PREFIX/pdfcraft-cli"
ln -sf "$PREFIX/pdfcraft-cli" "$BINDIR/pdfcraft-cli"
c_ok "CLI instalada: $BINDIR/pdfcraft-cli -> $PREFIX/pdfcraft-cli"
"$PREFIX/pdfcraft-cli" --version 2>/dev/null | head -1 || true

# ---------------------------------------------------------------------------
# GUI opcional (AppImage + lanzador)
# ---------------------------------------------------------------------------
if [ "$DO_GUI" -eq 1 ]; then
  GUI_ASSET="pdfcraft-${VERSION}-linux-${ARCH}.AppImage"
  c_info "Descargando GUI ${GUI_ASSET}…"
  curl -fsSL -o "$TMP/$GUI_ASSET" "${APP_BASE}/${TAG}/${GUI_ASSET}" || die "Fallo al descargar la AppImage"
  EXP_GUI="$(awk -v f="$GUI_ASSET" '{n=$2; sub(/^\*/,"",n); if(n==f){print $1; exit}}' "$TMP/$SUMS")"
  [ -n "$EXP_GUI" ] || die "No encuentro el hash de ${GUI_ASSET} en ${SUMS}"
  ACT_GUI="$(sha256sum "$TMP/$GUI_ASSET" | awk '{print $1}')"
  [ "$EXP_GUI" = "$ACT_GUI" ] || die "SHA256 de la AppImage NO coincide — abortando GUI"
  install -m 0755 "$TMP/$GUI_ASSET" "$PREFIX/pdfcraft.AppImage"
  ln -sf "$PREFIX/pdfcraft.AppImage" "$BINDIR/pdfcraft-gui"
  c_ok "GUI instalada: $BINDIR/pdfcraft-gui"

  DESKTOP_DIR="$HOME/.local/share/applications"
  mkdir -p "$DESKTOP_DIR"
  sed "s#__EXEC__#$PREFIX/pdfcraft.AppImage#g" "$(dirname "$0")/examples/pdfcraft.desktop" \
    > "$DESKTOP_DIR/pdfcraft.desktop" 2>/dev/null || true
  [ -f "$DESKTOP_DIR/pdfcraft.desktop" ] && c_ok "Lanzador: $DESKTOP_DIR/pdfcraft.desktop"
fi

# ---------------------------------------------------------------------------
# Registro MCP opcional en Claude Code
# ---------------------------------------------------------------------------
if [ "$DO_MCP" -eq 1 ]; then
  if ! command -v claude >/dev/null 2>&1; then
    c_warn "No encuentro el comando 'claude' (Claude Code). Salto el registro MCP."
    c_warn "Puedes registrarlo luego con el ejemplo de examples/mcp-config.example.json"
  else
    echo
    c_warn "NOTA DE SEGURIDAD — automation roots:"
    c_warn "  El MCP de pdfcraft puede LEER y ESCRIBIR ficheros dentro de los directorios"
    c_warn "  que le indiques como 'roots'. Cuanto más amplio el root, más expuesto quedas."
    c_warn "  Elige un directorio de trabajo acotado, NUNCA tu \$HOME entero si puedes evitarlo."
    echo
    DEFAULT_ROOT="$PWD"
    printf 'Directorio de trabajo (automation root) [%s]: ' "$DEFAULT_ROOT"
    read -r ROOT_IN || true
    ROOT="${ROOT_IN:-$DEFAULT_ROOT}"
    [ -d "$ROOT" ] || die "El directorio no existe: $ROOT"
    ROOT="$(cd "$ROOT" && pwd)"
    c_info "Registrando MCP 'pdfcraft' con root: $ROOT"
    claude mcp add -s user pdfcraft -- "$BINDIR/pdfcraft-cli" mcp \
      --automation-read-root "$ROOT" \
      --automation-write-root "$ROOT" \
      --compact
    c_ok "MCP registrado. Reinicia Claude Code o ejecuta /mcp para reconectar."
  fi
fi

echo
c_ok "Listo. Asegúrate de que '$BINDIR' está en tu PATH."
