#!/data/data/com.termux/files/usr/bin/bash
# OpenCode + OpenChamber + GitHub CLI en Termux, dentro de Ubuntu proot-distro.
# Instalador repetible: no elimina ni reinicia la instalación de Ubuntu ni sus datos.

set -Eeuo pipefail
unset LD_PRELOAD || true

PORT="${PORT:-3000}"
HOST="127.0.0.1"
UBUNTU_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"
UBUNTU_HOME="$UBUNTU_ROOT/root"
PIN_FILE="$HOME/.openchamber_pin"
LOG_FILE="$HOME/.termux-opencode-setup.log"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

info() { printf "${CYAN}%s${RESET}\n" "$*"; }
success() { printf "${GREEN}%s${RESET}\n" "$*"; }
warning() { printf "${YELLOW}%s${RESET}\n" "$*"; }
error() { printf "${RED}%s${RESET}\n" "$*" >&2; }

mkdir -p "$HOME/.local/share"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'error "Error en la línea $LINENO. Registro: $LOG_FILE"' ERR

if [[ -z "${PREFIX:-}" || ! -d "$PREFIX" ]]; then
    error "Este instalador debe ejecutarse desde Termux."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    error "No se encuentra apt-get. Ejecuta este script desde Termux."
    exit 1
fi

if [[ ! -s "$PIN_FILE" ]]; then
    PIN="$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"
    PIN=$((PIN % 90000000 + 10000000))
    printf '%s\n' "$PIN" > "$PIN_FILE"
    chmod 600 "$PIN_FILE"
else
    PIN="$(tr -d '\r\n' < "$PIN_FILE")"
fi

info ""
info "=== [1/5] Preparando Termux ==="
termux-wake-lock 2>/dev/null || true
apt-get update -y
apt-get install -y proot-distro curl git wget gh openssh procps coreutils ca-certificates

if ! command -v proot-distro >/dev/null 2>&1; then
    error "No se pudo instalar proot-distro."
    exit 1
fi

info ""
info "=== [2/5] Preparando Ubuntu ==="
if [[ ! -d "$UBUNTU_ROOT" ]]; then
    proot-distro install ubuntu
else
    success "Ubuntu ya está instalado; se conserva su sistema de archivos."
fi

mkdir -p "$UBUNTU_ROOT/root/termux"

# El código de configuración de Ubuntu se mantiene en GitHub.
# Se transmite directamente a bash dentro de Ubuntu; no se crea un script auxiliar local.
UBUNTU_SETUP_URL="https://raw.githubusercontent.com/genesislloretramos/instalar-openchamber-en-termux/main/ubuntu/setup.sh"
curl -fsSL "$UBUNTU_SETUP_URL" | proot-distro login ubuntu --shared-tmp -- bash -s

info ""
info "=== [3/5] Creando comandos puente ==="

cat > "$PREFIX/bin/opencode" <<'WRAPPER_OC'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
unset LD_PRELOAD || true

CURRENT_DIR="$(pwd)"
case "$CURRENT_DIR" in
    "$HOME"/*) UBUNTU_DIR="/root/termux/${CURRENT_DIR#"$HOME"/}" ;;
    "$HOME") UBUNTU_DIR="/root/termux" ;;
    *) UBUNTU_DIR="/root" ;;
esac

exec proot-distro login ubuntu --shared-tmp --bind "$HOME:/root/termux" -- bash -c '
TARGET="$1"; shift
if [[ -d "$TARGET" ]]; then cd "$TARGET"; else cd /root; fi
exec opencode "$@"
' _ "$UBUNTU_DIR" "$@"
WRAPPER_OC

cat > "$PREFIX/bin/openchamber" <<'WRAPPER_OCH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
unset LD_PRELOAD || true

HOST="127.0.0.1"
PORT="${PORT:-3000}"
PIN_FILE="$HOME/.openchamber_pin"
if [[ ! -s "$PIN_FILE" ]]; then
    echo "No existe el PIN guardado. Vuelve a ejecutar el instalador." >&2
    exit 1
fi
PIN="$(tr -d '\r\n' < "$PIN_FILE")"

CURRENT_DIR="$(pwd)"
case "$CURRENT_DIR" in
    "$HOME"/*) UBUNTU_DIR="/root/termux/${CURRENT_DIR#"$HOME"/}" ;;
    "$HOME") UBUNTU_DIR="/root/termux" ;;
    *) UBUNTU_DIR="/root" ;;
esac

COMMAND="${1:-start}"
case "$COMMAND" in
    start)
        shift || true
        exec proot-distro login ubuntu --shared-tmp --bind "$HOME:/root/termux" -- env OPENCHAMBER_HOST="$HOST" OPENCHAMBER_UI_PASSWORD="$PIN" bash -c '
            TARGET="$1"; PORT="$2"; shift 2
            if [[ -d "$TARGET" ]]; then cd "$TARGET"; else cd /root; fi
            exec openchamber --host 127.0.0.1 --port "$PORT" --ui-password "$OPENCHAMBER_UI_PASSWORD" "$@"
        ' _ "$UBUNTU_DIR" "$PORT" "$@"
        ;;
    stop|status|restart|logs)
        shift || true
        exec proot-distro login ubuntu --shared-tmp -- env OPENCHAMBER_HOST="$HOST" OPENCHAMBER_UI_PASSWORD="$PIN" openchamber "$COMMAND" "$@"
        ;;
    *)
        exec proot-distro login ubuntu --shared-tmp --bind "$HOME:/root/termux" -- env OPENCHAMBER_HOST="$HOST" OPENCHAMBER_UI_PASSWORD="$PIN" bash -c '
            TARGET="$1"; shift
            if [[ -d "$TARGET" ]]; then cd "$TARGET"; else cd /root; fi
            exec openchamber "$@"
        ' _ "$UBUNTU_DIR" "$@"
        ;;
esac
WRAPPER_OCH

chmod 700 "$PREFIX/bin/opencode" "$PREFIX/bin/openchamber"

info ""
info "=== [4/5] Conservando configuración y proyectos ==="
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/proyectos" "$UBUNTU_HOME/.config/opencode" "$UBUNTU_HOME/.local/share/opencode" "$UBUNTU_HOME/.config/openchamber" "$UBUNTU_HOME/.config/gh" "$UBUNTU_HOME/.ssh"

# Los enlaces solo se crean si el destino no existe. Nunca se reemplazan
# archivos, carpetas ni enlaces ya presentes.
link_if_absent() {
    local source="$1" target="$2"
    if [[ -L "$target" ]]; then
        if [[ "$(readlink "$target")" == "$source" ]]; then
            return 0
        fi
        warning "Se conserva el enlace existente: $target"
        return 0
    fi
    if [[ -e "$target" ]]; then
        warning "Se conserva el destino existente: $target"
        return 0
    fi
    ln -s "$source" "$target"
}

link_if_absent "$UBUNTU_HOME" "$HOME/ubuntu-root"
link_if_absent "$UBUNTU_HOME/.config/opencode" "$HOME/.config/opencode"
link_if_absent "$UBUNTU_HOME/.local/share/opencode" "$HOME/.local/share/opencode"
link_if_absent "$UBUNTU_HOME/.config/openchamber" "$HOME/.config/openchamber"
link_if_absent "$UBUNTU_HOME/.config/gh" "$HOME/.config/gh"
link_if_absent "$UBUNTU_HOME/.ssh" "$HOME/.ssh"
link_if_absent "$UBUNTU_HOME/.gitconfig" "$HOME/.gitconfig"

if [[ ! -e "$UBUNTU_HOME/.gitconfig" ]]; then
    touch "$UBUNTU_HOME/.gitconfig"
fi

info ""
info "=== [5/5] Integrando GitHub CLI ==="
if proot-distro login ubuntu --shared-tmp -- gh auth status >/dev/null 2>&1; then
    success "GitHub CLI ya tiene una sesión autenticada."
else
    warning "GitHub CLI aún no está autenticado."
    echo "Se abrirá el flujo de autenticación web de GitHub."
    proot-distro login ubuntu --shared-tmp -- gh auth login --hostname github.com --git-protocol https --web || warning "No se completó la autenticación. Puedes hacerlo más tarde con: gh auth login"
fi

if proot-distro login ubuntu --shared-tmp -- gh auth status >/dev/null 2>&1; then
    proot-distro login ubuntu --shared-tmp -- gh auth setup-git
    GH_USER="$(proot-distro login ubuntu --shared-tmp -- gh api user -q '.login' 2>/dev/null || true)"
    GH_ID="$(proot-distro login ubuntu --shared-tmp -- gh api user -q '.id' 2>/dev/null || true)"

    if [[ -n "$GH_USER" ]] && ! proot-distro login ubuntu --shared-tmp -- git config --global user.name >/dev/null 2>&1; then
        proot-distro login ubuntu --shared-tmp -- git config --global user.name "$GH_USER"
    fi
    if [[ -n "$GH_USER" && -n "$GH_ID" ]] && ! proot-distro login ubuntu --shared-tmp -- git config --global user.email >/dev/null 2>&1; then
        proot-distro login ubuntu --shared-tmp -- git config --global user.email "${GH_ID}+${GH_USER}@users.noreply.github.com"
    fi
    proot-distro login ubuntu --shared-tmp -- git config --global init.defaultBranch main
    success "GitHub CLI y Git preparados."
fi

echo ""
success "Instalación completada."
echo "OpenCode:     opencode"
echo "OpenChamber:  openchamber start | status | logs | restart | stop"
echo "URL local:    http://${HOST}:${PORT}"
echo "PIN guardado: $PIN_FILE"
echo "Proyectos:    $HOME/proyectos (disponibles dentro de Ubuntu en /root/termux/proyectos)"
echo "Registro:     $LOG_FILE"
echo "Registro Ubuntu: $UBUNTU_HOME/.local/share/opencode/install.log"
