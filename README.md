# instalar-openchamber-en-termux

Repositorio de script básico de instalación con la idea que puedas apuntar openchamber directamente a 0.0.0.0:3000 en tu propio móvil y trabajar 100% local

Para que sea todo muy fácil de instalar, este repositorio tiene un script 100% automatizado que con el comando inferior podrás ejecutar en tu termux recién instalado y automatizará la instalación de:
- instalar dependencias
- entorno Ubuntu
- instalar OpenCode
- instalar OpenChamber

## Comando ejecución en Termux
```
pkg update -y && pkg install -y curl && bash <(curl -fsSL https://raw.githubusercontent.com/genesislloretramos/instalar-openchamber-en-termux/main/instala.sh)
```