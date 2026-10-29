# OpenCode + OpenChamber en Termux

Instalador para Android/Termux que prepara Ubuntu mediante `proot-distro` e instala OpenCode, OpenChamber y GitHub CLI. Está pensado para ejecutarse repetidamente: actualiza los paquetes de las herramientas y conserva la instalación de Ubuntu, los proyectos y las configuraciones existentes.

> **Aviso:** Ubuntu en Termux/PRoot no es una máquina virtual ni un entorno Linux con systemd. El instalador no activa servicios de inicio de sesión de OpenChamber; sus comandos de control se ejecutan desde Termux.

## Instalación rápida

En Termux:

```bash
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && unset LD_PRELOAD && bash <(curl -fsSL https://raw.githubusercontent.com/genesislloretramos/instalar-openchamber-en-termux/main/instala.sh)
```

El script también instala/actualiza las dependencias de Termux y los paquetes dentro de Ubuntu. Requiere conexión a Internet y una sesión interactiva de Termux para el inicio de sesión de GitHub (opcional).

## Qué instala y configura

- Termux: `proot-distro`, Git, GitHub CLI, OpenSSH y utilidades.
- Ubuntu dentro de `proot-distro`; una instalación preexistente se conserva.
- Node.js 24.14 o superior, requisito actual de OpenChamber Web.
- OpenCode CLI 2 mediante npm (`@opencode/cli`), compatible con OpenChamber 2.x (mínimo OpenCode 2.0.15).
- OpenChamber Web mediante npm (`@openchamber/web`).
- GitHub CLI oficial dentro de Ubuntu y autenticación por navegador.
- Comandos puente `opencode` y `openchamber` en Termux.
- Configuración de Git para autenticación HTTPS con `gh`, solo si no existía identidad de Git previamente.

## OpenChamber: acceso local

OpenChamber queda configurado para escuchar en **127.0.0.1**, no en `0.0.0.0`. Desde el navegador del mismo móvil:

- URL: [http://127.0.0.1:3000](http://127.0.0.1:3000)
- PIN: se genera durante la primera instalación y se guarda en `~/.openchamber_pin` con permisos privados.

El PIN se conserva en las siguientes ejecuciones. No compartas el PIN ni expongas el servidor a una red pública.

## Comandos

Ejecutar desde Termux:

```bash
# OpenCode TUI; se abre en el directorio actual si está bajo $HOME de Termux
opencode

# Iniciar OpenChamber en localhost:3000
openchamber start

# Consultar estado, registros, reiniciar o detener
openchamber status
openchamber logs
openchamber restart
openchamber stop

# Elegir otro puerto para el inicio
PORT=3001 openchamber start
```

OpenChamber inicia en segundo plano con el comportamiento normal de su CLI. Para controlarlo usa los comandos puente de Termux; no ejecutes el CLI dentro de una shell Ubuntu separada si necesitas que use el mismo contexto de configuración.

## Proyectos

El instalador crea `~/proyectos` en Termux si no existe. Esa carpeta se enlaza al entorno Ubuntu durante la ejecución de los herramientas como:

```bash
cd ~/proyectos/mi-repo
opencode
```

Dentro del entorno de OpenCode, la ruta compartida es `/root/termux/proyectos/mi-repo`. También se comparte el resto de `$HOME` de Termux en `/root/termux`.

## GitHub CLI

La autenticación se realiza dentro de Ubuntu:

```bash
gh auth status
gh auth login
gh repo clone OWNER/REPO
```

Si omites el inicio de sesión durante la instalación, puedes completarlo después con `gh auth login`. La configuración de Git existente no se reemplaza; si `user.name` o `user.email` están vacíos, se completan a partir de la cuenta autenticada.

## Datos, actualizaciones y registros

El instalador no ejecuta `proot-distro reset` ni `proot-distro remove` y no borra las carpetas de configuración existentes. El paquete antiguo `opencode-ai` (OpenCode 1.x) se desinstala para evitar conflictos con el CLI 2; esto no borra la configuración de OpenCode ni los proyectos.

Ubicaciones principales:

| Elemento | Ubicación |
|---|---|
| Ubuntu rootfs | `$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu` |
| PIN OpenChamber | `~/.openchamber_pin` |
| Registro de instalación en Termux | `~/.termux-opencode-setup.log` |
| Registro de instalación en Ubuntu | `/root/.local/share/opencode/install.log` |
| Proyectos compartidos | `~/proyectos` |

Ejecutar de nuevo el comando de instalación vuelve a actualizar dependencias y herramientas, pero conserva los datos y la configuración de usuario.

## Solución de problemas

**Error de sintaxis al descargar el script**

Comprueba el archivo sin ejecutarlo:

```bash
curl -fsSL https://raw.githubusercontent.com/genesislloretramos/instalar-openchamber-en-termux/main/instala.sh -o "$TMPDIR/instala.sh"
bash -n "$TMPDIR/instala.sh"
```

**OpenChamber no responde**

```bash
openchamber status
openchamber logs
openchamber restart
```

Comprueba que estás abriendo `http://127.0.0.1:3000` en el mismo dispositivo y que Termux sigue activo.

**GitHub no está autenticado**

```bash
proot-distro login ubuntu -- gh auth login
```

## Documentación oficial

- [Termux](https://termux.dev/)
- [PRoot-Distro](https://github.com/termux/proot-distro)
- [OpenCode 2: instalación](https://opencode.ai/v2/docs/)
- [OpenChamber: instalación](https://docs.openchamber.dev/install/)
- [OpenChamber: servidor y comandos](https://docs.openchamber.dev/opencode-server/)
- [GitHub CLI: manual](https://cli.github.com/manual/)
