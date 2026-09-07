<p align="center">
  <img src="img/logo-sticker.png" alt="Desktop Stickers logo" width="120">
</p>

<h1 align="center">Desktop Stickers</h1>

<p align="center">
  <a href="LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-blue.svg"></a>
  <a href="docs/README-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="docs/README-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="docs/README-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="docs/README-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="docs/README-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="docs/README-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="docs/README-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

Sticky notes flotantes para el escritorio de KDE Plasma. Aplicación
standalone Qt6/QML (no un plasmoid) que se instala como programa normal
con autostart — cada sticker es una ventana independiente, sin
decoración, con posición y tamaño persistentes.

<p align="center">
  <img src="img/screenshot-desktop.png" alt="Stickers flotantes sobre el escritorio de KDE Plasma" width="720">
</p>

## Requisitos

- Plasma 6.x y KWin, sesión Wayland
- Qt 6.5+ (`Core`, `Gui`, `Qml`, `Quick`, `Widgets`, `DBus`)
- CMake, Bash

## Features destacadas

- Ventanas independientes, arrastrables y redimensionables, con
  posición y tamaño persistentes vía reglas de ventana de KWin
- Pin por sticker para verlo en todos los escritorios virtuales a la vez
- Edición en **Markdown completo** (tablas, código, listas, links,
  checkboxes), con vista previa renderizada al perder el foco
- Panel de Stickers para listar, abrir, renombrar y eliminar todas las
  notas sin límite

<p align="center">
  <img src="img/Desktop-stickers-markdown.png" alt="Ejemplo de sticker con Markdown renderizado: títulos, tablas y bloques de código" width="720">
</p>

## Descargas

Todas las versiones publicadas están en la página de
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
del repositorio, cada una con su código fuente y notas de la versión.

## Instalación rápida

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Guía completa (primer arranque, datos de prueba, troubleshooting):
[docs/QUICKSTART-SP.md](docs/QUICKSTART-SP.md) ·
[EN](docs/QUICKSTART-EN.md) ·
[IT](docs/QUICKSTART-IT.md) ·
[DE](docs/QUICKSTART-DE.md) ·
[RU](docs/QUICKSTART-RU.md) ·
[CN](docs/QUICKSTART-CN.md) ·
[JP](docs/QUICKSTART-JP.md)

## Reportar problemas / Contribuir

¿Encontraste un bug o tenés una sugerencia? Abrí un issue en
[GitHub Issues](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/issues).

## Desarrollo asistido por IA

Este proyecto se desarrolló con asistencia de [Claude Code](https://claude.com/claude-code)
(Anthropic), usando los modelos **Claude Sonnet 5** y **Claude Haiku 4.5**.
Reporte de consumo de tokens y costo hipotético a tarifa de API, por
modelo y por sesión: [docs/TOKEN_REPORT.md](docs/TOKEN_REPORT.md)
([versión HTML para compartir](docs/TOKEN_REPORT.html)).

## Documentación completa

- [Español](docs/README-SP.md)
- [Italiano](docs/README-IT.md)
- [English](docs/README-EN.md)
- [Deutsch](docs/README-DE.md)
- [Русский](docs/README-RU.md)
- [中文](docs/README-CN.md)
- [日本語](docs/README-JP.md)
