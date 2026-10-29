#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Instalador de OpenCode + OpenChamber + GitHub CLI para Termux (Ubuntu proot)
# ==============================================================================
set -euo pipefail

# Evitar SIGKILL (signal 9) en subprocesos https de APT tras actualizar termux-exec en caliente
unset LD_PRELOAD

PORT="${PORT:-3000}"
PIN="${PIN:-$(shuf -i 1000-9999 -n 1)}"
UBUNTU_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"

echo -e "\n\033[1;36m=== [1/6] Preparando entorno nativo de Termux y GitHub CLI ===\033[0m"
termux-wake-lock 2>/dev/null || true

export DEBIAN_FRONTEND=noninteractive

# Instalar dependencias base + GitHub CLI (gh) y OpenSSH en Termux
apt-get update -y </dev/null
apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  proot-distro curl git wget gh openssh procps </dev/null

echo -e "\n\033[1;36m=== [2/6] Verificando contenedor Ubuntu (proot-distro) ===\033[0m"
if [ ! -d "$UBUNTU_ROOT" ]; then
    proot-distro install ubuntu </dev/null
else
    echo "✔ Ubuntu ya está instalado. Saltando descarga de rootfs..."
fi

echo -e "\n\033[1;36m=== [3/6] Instalando Node.js 24, GitHub CLI, OpenCode y OpenChamber en Ubuntu ===\033[0m"
cat << 'UBUNTU_SCRIPT' > "$UBUNTU_ROOT/tmp/setup_inner.sh"
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y </dev/null
apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" </dev/null

apt-get install -y \
  curl git unzip ca-certificates gnupg openssh-client \
  build-essential python3 make g++ </dev/null

# Instalar GitHub CLI (gh) oficial en Ubuntu
if ! command -v gh >/dev/null 2>&1; then
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    apt-get update -y </dev/null
    apt-get install -y gh </dev/null
fi

# Instalar Node.js 24.x
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'.' -f1 | tr -d 'v')" -lt 24 ]; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - </dev/null
    apt-get install -y nodejs </dev/null
fi

# Habilitar scripts postinstall para npm 11.19+
npm config set allow-scripts "opencode-ai,node-pty" --location=user 2>/dev/null || true

npm install -g --allow-scripts=opencode-ai,node-pty opencode-ai @openchamber/web </dev/null || \
npm install -g --foreground-scripts opencode-ai @openchamber/web </dev/null

mkdir -p /root/.config/opencode /root/.local/share/opencode /root/.config/openchamber /root/.config/gh /root/.ssh
UBUNTU_SCRIPT

chmod +x "$UBUNTU_ROOT/tmp/setup_inner.sh"
proot-distro login ubuntu --shared-tmp -- bash -lc "/tmp/setup_inner.sh" </dev/null
rm -f "$UBUNTU_ROOT/tmp/setup_inner.sh"

echo -e "\n\033[1;36m=== [4/6] Creando comandos puente (wrappers) fuera de proot ===\033[0m"
cat << 'WRAPPER_OC' > "$PREFIX/bin/opencode"
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
CURRENT_DIR="$(pwd)"
exec proot-distro login ubuntu --shared-tmp --bind "$HOME:/root/termux" -- bash -lc "cd \"$CURRENT_DIR\" 2>/dev/null || cd /root; exec opencode \"\$@\""
WRAPPER_OC

cat << 'WRAPPER_OCH' > "$PREFIX/bin/openchamber"
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
CURRENT_DIR="$(pwd)"
exec proot-distro login ubuntu --shared-tmp --bind "$HOME:/root/termux" -- bash -lc "cd \"$CURRENT_DIR\" 2>/dev/null || cd /root; exec openchamber \"\$@\""
WRAPPER_OCH

chmod +x "$PREFIX/bin/opencode" "$PREFIX/bin/openchamber"

echo -e "\n\033[1;36m=== [5/6] Configurando enlaces simbólicos (Proyectos + GitHub/Git) ===\033[0m"
mkdir -p "$UBUNTU_ROOT/root/.config/opencode" \
         "$UBUNTU_ROOT/root/.local/share/opencode" \
         "$UBUNTU_ROOT/root/.config/openchamber" \
         "$UBUNTU_ROOT/root/.config/gh" \
         "$UBUNTU_ROOT/root/.ssh" \
         "$HOME/.config" "$HOME/.local/share" "$HOME/proyectos"

touch "$UBUNTU_ROOT/root/.gitconfig"

rm -rf "$HOME/ubuntu-root" \
       "$HOME/.config/opencode" \
       "$HOME/.local/share/opencode" \
       "$HOME/.config/openchamber" \
       "$HOME/.config/gh" \
       "$HOME/.ssh" \
       "$HOME/.gitconfig" \
       "$UBUNTU_ROOT/root/proyectos"

ln -s "$UBUNTU_ROOT/root" "$HOME/ubuntu-root"
ln -s "$UBUNTU_ROOT/root/.config/opencode" "$HOME/.config/opencode"
ln -s "$UBUNTU_ROOT/root/.local/share/opencode" "$HOME/.local/share/opencode"
ln -s "$UBUNTU_ROOT/root/.config/openchamber" "$HOME/.config/openchamber"
ln -s "$UBUNTU_ROOT/root/.config/gh" "$HOME/.config/gh"
ln -s "$UBUNTU_ROOT/root/.ssh" "$HOME/.ssh"
ln -s "$UBUNTU_ROOT/root/.gitconfig" "$HOME/.gitconfig"
ln -s "$HOME/proyectos" "$UBUNTU_ROOT/root/proyectos"

echo -e "\n\033[1;36m=== [6/6] Vinculación de cuenta de GitHub ===\033[0m"
if ! gh auth status >/dev/null 2>&1; then
    echo -e "\033[1;33m🔗 Inicia sesión en tu cuenta de GitHub para tus futuros proyectos:\033[0m"
    gh auth login -p https -w </dev/tty || true
fi

if gh auth status >/dev/null 2>&1; then
    gh auth setup-git
    GH_USER="$(gh api user -q '.login' 2>/dev/null || true)"
    GH_ID="$(gh api user -q '.id' 2>/dev/null || true)"
    if [ -n "$GH_USER" ] && [ -z "$(git config --global user.name || true)" ]; then
        git config --global user.name "$GH_USER"
        git config --global user.email "${GH_ID}+${GH_USER}@users.noreply.github.com"
        git config --global init.defaultBranch main
    fi
    echo -e "\033[1;32m✔ Cuenta de GitHub (@${GH_USER}) vinculada en Termux y OpenChamber.\033[0m"
fi

pkill -f "openchamber" 2>/dev/null || true

echo "$PIN" > "$HOME/.openchamber_pin"

nohup openchamber --lan --port "$PORT" --ui-password "$PIN" > "$HOME/.openchamber.log" 2>&1 &
sleep 3

echo -e "\n\033[1;32m✅ OpenChamber activo en 0.0.0.0:${PORT}\033[0m"
echo -e "🔑 Contraseña (PIN):"
echo "$PIN"
