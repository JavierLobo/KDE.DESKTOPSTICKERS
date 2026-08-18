# QA Checklist — KDE Stickers

Verificación manual repetible del MVP. No hay tests automatizados (decisión de diseño, ver `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`).

## Instalación

- [ ] `./scripts/install.sh` compila sin errores
- [ ] `~/.local/bin/kde-stickers` existe y es ejecutable
- [ ] `~/.config/autostart/org.kde.stickers.desktop` existe, `Exec=` apunta a una ruta real (no un placeholder)

## Creación

- [ ] Tray icon → "Nuevo sticker" crea un sticker amarillo con texto placeholder
- [ ] Botón "+" de un sticker existente crea uno nuevo desplazado (+30,+30)
- [ ] Cada sticker creado obtiene un id incremental único

## Movimiento

- [ ] Arrastrar un sticker por su header lo mueve visualmente (vía `Window.startSystemMove()`)
- [ ] `~/.stickers/stickers.json` sigue siendo válido tras arrastrar (no se corrompe a `x:0, y:0`)

**Limitación conocida y aceptada (ver spec, sección "Modelo de datos y persistencia"):** por una limitación del protocolo Wayland, la app no puede leer la posición real de una ventana tras moverla, así que la posición arrastrada **no** se persiste con precisión, y al reiniciar la app cada sticker abre en la posición que decida la política de colocación de KWin — **no** en su última posición arrastrada. Esto es intencional para este MVP, no un bug a reportar.

## Multi-desktop

- [ ] Todos los stickers son visibles al cambiar de escritorio virtual (Pager o `Ctrl+F2`/`Meta+Ctrl+Right`)
- [ ] La posición de cada sticker es la misma sin importar el escritorio activo

## Markdown

- [ ] Click en el contenido de un sticker entra en modo edición (texto plano/Markdown crudo)
- [ ] Perder el foco (click fuera) vuelve a preview renderizado
- [ ] Negrita, cursiva, listas, citas y código inline se renderizan con estilo en preview
- [ ] El texto editado se persiste en `~/.stickers/stickers.json`

## Colores

- [ ] Botón 🎨 abre la paleta de 6 colores fijos
- [ ] Seleccionar un swatch cambia el color del sticker inmediatamente y lo persiste
- [ ] El botón "+" de la paleta abre un selector de color libre y aplica/persiste el color elegido

## Eliminación

- [ ] Botón "✕" cierra la ventana del sticker
- [ ] El sticker eliminado desaparece de `~/.stickers/stickers.json`
- [ ] Al reiniciar la app, el sticker eliminado no reaparece

## Persistencia entre sesiones

- [ ] Cerrar sesión de Plasma y volver a iniciar sesión levanta la app automáticamente (autostart)
- [ ] Todos los stickers previamente creados aparecen con su texto y color correctos (la posición sigue la limitación conocida de la sección "Movimiento" arriba)

## Salida

- [ ] Tray icon → "Salir" termina el proceso completo (verificar con `pgrep kde-stickers`)
