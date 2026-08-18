# QA Checklist — KDE Stickers

Verificación manual repetible del MVP. No hay tests automatizados (decisión de diseño, ver `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md`).

## Instalación

- [ ] `./scripts/install.sh` compila sin errores
- [ ] `~/.local/bin/kde-stickers` existe y es ejecutable
- [ ] `~/.config/autostart/org.kde.stickers.desktop` existe, `Exec=` apunta a una ruta real (no un placeholder)

## Creación

- [ ] Tray icon → "Nuevo sticker" crea un sticker amarillo con texto placeholder
- [ ] Botón "+" de un sticker existente crea uno nuevo con id incremental (la posición inicial la decide KWin — la posición real solo se persiste tras el primer arrastre, ver "Movimiento")
- [ ] Cada sticker creado obtiene un id incremental único

## Movimiento

- [ ] Arrastrar un sticker por su header lo mueve visualmente (vía `Window.startSystemMove()`)
- [ ] Al soltar, la posición real (no la de Qt, la reportada por KWin) se persiste en `~/.stickers/stickers.json`
- [ ] Al reiniciar la app, el sticker abre en su última posición real (vía regla de KWin por ventana, `kdestickers-sticker-<id>`)

## Pin (todos los escritorios por sticker)

- [ ] Botón 📍/📌 alterna el estado de pin visualmente
- [ ] Con pin activo (📌), el sticker es visible en todos los escritorios virtuales
- [ ] Sin pin (📍), el sticker solo existe en el escritorio donde se creó o se movió
- [ ] El estado del pin persiste en `~/.stickers/stickers.json` y sobrevive a un reinicio de la app
- [ ] Nuevo sticker creado: empieza sin pin (📍) por defecto

## Resize

- [ ] Arrastrar desde la esquina inferior derecha redimensiona el sticker visualmente
- [ ] No se puede encoger por debajo de ~150×120px
- [ ] El tamaño persiste en `~/.stickers/stickers.json` y se restaura al reiniciar la app

## Combinado: pin + movimiento + resize

- [ ] Un sticker que se pinea, se arrastra a una nueva posición y se
      redimensiona restaura los tres estados correctamente tras reiniciar la
      app (pin activo, posición real, tamaño) — sin necesidad de repetir
      ninguna de las tres acciones tras el reinicio

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
- [ ] Todos los stickers previamente creados aparecen con su texto, color, posición, tamaño y estado de pin correctos

## Salida

- [ ] Tray icon → "Salir" termina el proceso completo (verificar con `pgrep kde-stickers`)
