
#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Instalador OpenCode + OpenChamber + GitHub CLI para Termux
# Ubuntu mediante proot-distro
#
# Caracteristicas:
# - Instalacion idempotente y conservacion de datos
# - Node.js 24.14+
# - OpenCode y OpenChamber
# - GitHub CLI integrado en Ubuntu
# - OpenChamber exclusivamente en localhost
# - Wrappers con argumentos y directorio de trabajo preservados
# - Gestion de OpenChamber y registros
# ==============================================================================

set -Eeuo pipefail
unset LD_PRELOAD

# ------------------------------------------------------------------------------
# Configuracion
# ------------------------------------------------------------------------------

PORT="${PORT:-3000}"
HOST="127.0.0.1"

UBUNTU_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"
UBUNTU_HOME="$UBUNTU_ROOT/root"

PIN_FILE="$HOME/.openchamber_pin"
LOG_FILE="$HOME/.termux-opencode-setup.log"

INSTALL_LOG="$UBUNTU_HOME/.local/share/opencode/install.log"

# ------------------------------------------------------------------------------
# Colores
# ------------------------------------------------------------------------------

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

info() {
    printf "${CYAN}%s${RESET}\n" "$*"
}

success() {
    printf "${GREEN}%s${RESET}\n" "$*"
}

warning() {
    printf "${YELLOW}%s${RESET}\n" "$*"
}

error() {
    printf "${RED}%s${RESET}\n' "$*"
}

# ------------------------------------------------------------------------------
# Registro de instalacion
# ------------------------------------------------------------------------------

mkdir -p "$HOME/.local/share"

touch "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

trap 'error "Error en la linea $LINENO. Consulta $LOG_FILE"' ERR

# ------------------------------------------------------------------------------
# Validaciones
# ------------------------------------------------------------------------------

if [ -z "${PREFIX:-}" ]; then
    echo "Este script debe ejecutarse desde Termux."
    exit 1
fi

if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro no esta instalado."
fi

# ------------------------------------------------------------------------------
# PIN persistente
# ------------------------------------------------------------------------------

if [ ! -s "$PIN_FILE" ]; then
    PIN="$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"
    PIN=$((PIN % 90000000 + 10000000))

    printf '%s\n' "$PIN" > "$PIN_FILE"
    chmod 600 "$PIN_FILE"
else
    PIN="$(cat "$PIN_FILE")"
fi

# ------------------------------------------------------------------------------
# 1. Termux
# ------------------------------------------------------------------------------

info ""
info "=== [1/6] Preparando Termux ==="

termux-wake-lock 2>/dev/null || true

export DEBIAN_FRONTEND=noninteractive

apt-get update -y </dev/null

apt-get install -y \
    proot-distro \
    curl \
    git \
    wget \
    gh \
    openssh \
    procps \
    coreutils \
    netcat-openbsd \
    </dev/null

# ------------------------------------------------------------------------------
# 2. Ubuntu
# ------------------------------------------------------------------------------

info ""
info "=== [2/6] Preparando Ubuntu ==="

if [ ! -d "$UBUNTU_ROOT" ]; then
    proot-distro install ubuntu </dev/null
else
    success "Ubuntu ya esta instalado."
fi

# ------------------------------------------------------------------------------
# 3. Instalacion dentro de Ubuntu
# ------------------------------------------------------------------------------

info ""
info "=== [3/6] Instalando Node.js, OpenCode, OpenChamber y GitHub CLI ==="

mkdir -p "$UBUNTU_HOME/tmp"

INNER_SCRIPT="$UBUNTU_ROOT/tmp/setup_inner.sh"

cat > "$INNER_SCRIPT" <<'UBUNTU_SCRIPT'
#!/bin/bash

set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

LOG="/root/.local/share/opencode/install.log"

mkdir -p "$(dirname "$LOG")"

exec > >(tee -a "$LOG") 2>&1

echo "Preparando Ubuntu..."

apt-get update -y </dev/null

apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    </dev/null

apt-get install -y \
    curl \
    git \
    unzip \
    ca-certificates \
    gnupg \
    openssh-client \
    build-essential \
    python3 \
    make \
    g++ \
    procps \
    </dev/null

# ------------------------------------------------------------------------------
# GitHub CLI oficial
# ------------------------------------------------------------------------------

if ! command -v gh >/dev/null 2>&1; then

    mkdir -p -m 755 /etc/apt/keyrings

    curl -fsSL \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg

    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list

    apt-get update -y </dev/null

    apt-get install -y gh </dev/null

fi

# ------------------------------------------------------------------------------
# Node.js 24.14+
# ------------------------------------------------------------------------------

NODE_VERSION="0"

if command -v node >/dev/null 2>&1; then
    NODE_VERSION="$(node -p 'process.versions.node')"
fi

NODE_MAJOR="${NODE_VERSION%%.*}"

NODE_MINOR="${NODE_VERSION#*.}"
NODE_MINOR="${NODE_MINOR%%.*}"

if [ "$NODE_MAJOR" -lt 24 ] ||
   { [ "$NODE_MAJOR" -eq 24 ] && [ "$NODE_MINOR" -lt 14 ]; }; then

    echo "Instalando Node.js 24..."

    curl -fsSL \
        https://deb.nodesource.com/setup_24.x \
        -o /tmp/nodesource_setup.sh

    bash /tmp/nodesource_setup.sh

    apt-get install -y nodejs </dev/null

    rm -f /tmp/nodesource_setup.sh

fi

echo "Node.js: $(node -v)"
echo "npm: $(npm -v)"

# ------------------------------------------------------------------------------
# OpenCode
# ------------------------------------------------------------------------------

if ! command -v opencode >/dev/null 2>&1; then

    echo "Instalando OpenCode..."

    npm install -g opencode-ai </dev/null

else

    echo "OpenCode ya esta instalado."

fi

# ------------------------------------------------------------------------------
# OpenChamber
# ------------------------------------------------------------------------------

if ! command -v openchamber >/dev/null 2>&1; then

    echo "Instalando OpenChamber..."

    npm install -g @openchamber/web </dev/null

else

    echo "OpenChamber ya esta instalado."

fi

# ------------------------------------------------------------------------------
# Directorios persistentes
# ------------------------------------------------------------------------------

mkdir -p \
    /root/.config/opencode \
    /root/.local/share/opencode \
    /root/.config/openchamber \
    /root/.config/gh \
    /root/.ssh \
    /root/proyectos

chmod 700 /root/.ssh

echo "Instalacion de Ubuntu completada."
UBUNTU_SCRIPT

chmod +x "$INNER_SCRIPT"

proot-distro login ubuntu \
    --shared-tmp \
    -- bash /tmp/setup_inner.sh

# ------------------------------------------------------------------------------
# 4. Wrappers Termux
# ------------------------------------------------------------------------------

info ""
info "=== [4/6] Creando comandos puente ==="

# ------------------------------------------------------------------------------
# Wrapper OpenCode
# ------------------------------------------------------------------------------

cat > "$PREFIX/bin/opencode" <<'WRAPPER_OC'
#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

unset LD_PRELOAD

CURRENT_DIR="$(pwd)"

case "$CURRENT_DIR" in
    "$HOME"/*)
        UBUNTU_DIR="/root/termux/${CURRENT_DIR#"$HOME"/}"
        ;;
    "$HOME")
        UBUNTU_DIR="/root/termux"
        ;;
    *)
        UBUNTU_DIR="/root"
        ;;
esac

exec proot-distro login ubuntu \
    --shared-tmp \
    --bind "$HOME:/root/termux" \
    -- bash -c '
        TARGET="$1"
        shift

        if [ -d "$TARGET" ]; then
            cd "$TARGET"
        else
            cd /root
        fi

        exec opencode "$@"
    ' _ "$UBUNTU_DIR" "$@"
WRAPPER_OC

# ------------------------------------------------------------------------------
# Wrapper OpenChamber
# ------------------------------------------------------------------------------

cat > "$PREFIX/bin/openchamber" <<'WRAPPER_OCH'
#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

unset LD_PRELOAD

HOST="127.0.0.1"
PORT="${PORT:-3000}"

PIN_FILE="$HOME/.openchamber_pin"

if [ ! -s "$PIN_FILE" ]; then
    echo "No existe el PIN. Ejecuta el instalador."
    exit 1
fi

PIN="$(cat "$PIN_FILE")"

CURRENT_DIR="$(pwd)"

case "$CURRENT_DIR" in
    "$HOME"/*)
        UBUNTU_DIR="/root/termux/${CURRENT_DIR#"$HOME"/}"
        ;;
    "$HOME")
        UBUNTU_DIR="/root/termux"
        ;;
    *)
        UBUNTU_DIR="/root"
        ;;
esac

COMMAND="${1:-start}"

case "$COMMAND" in
    start)
        shift || true

        exec proot-distro login ubuntu \
            --shared-tmp \
            --bind "$HOME:/root/termux" \
            -- env \
                OPENCHAMBER_HOST="$HOST" \
                OPENCHAMBER_UI_PASSWORD="$PIN" \
            bash -c '
                TARGET="$1"
                PORT="$2"
                shift 2

                if [ -d "$TARGET" ]; then
                    cd "$TARGET"
                else
                    cd /root
                fi

                exec openchamber \
                    --host 127.0.0.1 \
                    --port "$PORT" \
                    --ui-password "$OPENCHAMBER_UI_PASSWORD" \
                    "$@"
            ' _ "$UBUNTU_DIR" "$PORT" "$@"
        ;;

    stop|status|restart|logs)
        shift || true

        exec proot-distro login ubuntu \
            --shared-tmp \
            -- env \
                OPENCHAMBER_HOST="$HOST" \
                OPENCHAMBER_UI_PASSWORD="$PIN" \
            openchamber "$COMMAND" "$@"
        ;;

    *)
        exec proot-distro login ubuntu \
            --shared-tmp \
            --bind "$HOME:/root/termux" \
            -- env \
                OPENCHAMBER_HOST="$HOST" \
                OPENCHAMBER_UI_PASSWORD="$PIN" \
            bash -c '
                TARGET="$1"
                shift

                if [ -d "$TARGET" ]; then
                    cd "$TARGET"
                else
                    cd /root
                fi

                exec openchamber "$@"
            ' _ "$UBUNTU_DIR" "$@"
        ;;
esac
WRAPPER_OCH

chmod +x "$PREFIX/bin/opencode" "$PREFIX/bin/openchamber"

# ------------------------------------------------------------------------------
# 5. Configuracion persistente
# ------------------------------------------------------------------------------

info ""
info "=== [5/6] Configurando proyectos y configuraciones persistentes ==="

mkdir -p \
    "$HOME/.config" \
    "$HOME/.local/share" \
    "$HOME/proyectos" \
    "$UBUNTU_HOME/.config/opencode" \
    "$UBUNTU_HOME/.local/share/opencode" \
    "$UBUNTU_HOME/.config/openchamber" \
    "$UBUNTU_HOME/.config/gh" \
    "$UBUNTU_HOME/.ssh" \
    "$UBUNTU_HOME/proyectos"

# ------------------------------------------------------------------------------
# Enlaces seguros: no eliminar archivos existentes
# ------------------------------------------------------------------------------

link_persistent() {

    SOURCE="$1"
    TARGET="$2"

    if [ -L "$TARGET" ]; then

        CURRENT="$(readlink "$TARGET")"

        if [ "$CURRENT" = "$SOURCE" ]; then
            return 0
        fi

        echo "El enlace $TARGET apunta a otro destino."
        echo "No se modifica para preservar los datos."
        return 1

    fi

    if [ -e "$TARGET" ]; then

        echo "Existe $TARGET."
        echo "No se sobrescribe."

        return 0

    fi

    ln -s "$SOURCE" "$TARGET"

}

link_persistent \
    "$UBUNTU_HOME" \
    "$HOME/ubuntu-root"

link_persistent \
    "$UBUNTU_HOME/.config/opencode" \
    "$HOME/.config/opencode"

link_persistent \
    "$UBUNTU_HOME/.local/share/opencode" \
    "$HOME/.local/share/opencode"

link_persistent \
    "$UBUNTU_HOME/.config/openchamber" \
    "$HOME/.config/openchamber"

link_persistent \
    "$UBUNTU_HOME/.config/gh" \
    "$HOME/.config/gh"

link_persistent \
    "$UBUNTU_HOME/.ssh" \
    "$HOME/.ssh"

# ------------------------------------------------------------------------------
# Git
# ------------------------------------------------------------------------------

if [ ! -e "$UBUNTU_HOME/.gitconfig" ]; then
    touch "$UBUNTU_HOME/.gitconfig"
fi

link_persistent \
    "$UBUNTU_HOME/.gitconfig" \
    "$HOME/.gitconfig"

link_persistent \
    "$HOME/proyectos" \
    "$UBUNTU_HOME/proyectos"

# ------------------------------------------------------------------------------
# 6. GitHub
# ------------------------------------------------------------------------------

info ""
info "=== [6/6] Configurando GitHub ==="

if proot-distro login ubuntu \
    --shared-tmp \
    -- gh auth status >/dev/null 2>&1; then

    success "GitHub ya esta autenticado en Ubuntu."

else

    warning "GitHub no esta autenticado en Ubuntu."

    echo ""
    echo "Iniciando autenticacion de GitHub..."

    proot-distro login ubuntu \
        --shared-tmp \
        -- gh auth login -p https -w || true

fi

# ------------------------------------------------------------------------------
# Configuracion Git
# ------------------------------------------------------------------------------

if proot-distro login ubuntu \
    --shared-tmp \
    -- gh auth status >/dev/null 2>&1; then

    proot-distro login ubuntu \
        --shared-tmp \
        -- gh auth setup-git

    GH_USER="$(
        proot-distro login ubuntu \
            --shared-tmp \
            -- gh api user -q '.login' 2>/dev/null || true
    )"

    GH_ID="$(
        proot-distro login ubuntu \
            --shared-tmp \
            -- gh api user -q '.id' 2>/dev/null || true
    )"

    if [ -n "$GH_USER" ]; then

        proot-distro login ubuntu \
            --shared-tmp \
            -- git config --global user.name "$GH_USER"

        if [ -n "$GH_ID" ]; then

            proot-distro login ubuntu \
                --shared-tmp \
                -- git config --global user.email \
                "${GH_ID}+${GH_USER}@users.noreply.github.com"

        fi

        proot-distro login ubuntu \
            --shared-tmp \
            -- git config --global init.defaultBranch main

        success "GitHub configurado para @${GH_USER}."

    fi

fi

# ------------------------------------------------------------------------------
# Resultado
# ------------------------------------------------------------------------------

echo ""
success "=============================================="
success " Instalacion completada"
success "=============================================="

echo ""
echo "OpenCode:"
echo "  opencode"

echo ""
echo "OpenChamber:"
echo "  openchamber start"
echo "  openchamber status"
echo "  openchamber stop"
echo "  openchamber restart"
echo "  openchamber logs"

echo ""
echo "URL local:"
echo "  http://${HOST}:${PORT}"

echo ""
echo "PIN:"
echo "  ${PIN}"

echo ""
echo "Proyectos:"
echo "  ${HOME}/proyectos"

echo ""
echo "Registro de instalacion:"
echo "  ${LOG_FILE}"

echo ""
echo "Para detener OpenChamber:"
echo "  openchamber stop"

echo ""
echo "Para iniciar OpenChamber:"
echo "  openchamber start"

echo ""
success "Instalacion finalizada."
