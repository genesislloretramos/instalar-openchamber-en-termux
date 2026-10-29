#!/bin/bash
set -Eeuo pipefail
unset LD_PRELOAD || true
export DEBIAN_FRONTEND=noninteractive

LOG="/root/.local/share/opencode/install.log"
mkdir -p "$(dirname "$LOG")" /root/termux
touch "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "Actualizando Ubuntu e instalando dependencias..."
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get install -y curl git unzip ca-certificates gnupg openssh-client build-essential python3 make g++ procps

# GitHub CLI: repositorio oficial de GitHub CLI.
if ! command -v gh >/dev/null 2>&1; then
    install -d -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    printf '%s\n' "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt-get update -y
    apt-get install -y gh
fi

# OpenChamber requiere Node.js 24.14 o superior.
NODE_VERSION="0"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION="$(node -p 'process.versions.node')"
fi
NODE_MAJOR="${NODE_VERSION%%.*}"
NODE_REST="${NODE_VERSION#*.}"
NODE_MINOR="${NODE_REST%%.*}"

if (( NODE_MAJOR < 24 || (NODE_MAJOR == 24 && NODE_MINOR < 14) )); then
    echo "Instalando Node.js 24 desde NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh
    bash /tmp/nodesource_setup.sh
    apt-get install -y nodejs
    rm -f /tmp/nodesource_setup.sh
fi

echo "Node: $(node -v) | npm: $(npm -v)"

# OpenChamber 2.x requiere OpenCode CLI 2.0.15 o posterior.
npm uninstall --global opencode-ai || true
npm install --global @opencode/cli@latest
npm install --global @openchamber/web

mkdir -p /root/.config/opencode /root/.local/share/opencode /root/.config/openchamber /root/.config/gh /root/.ssh /root/termux
chmod 700 /root/.ssh
echo "Entorno Ubuntu preparado."
