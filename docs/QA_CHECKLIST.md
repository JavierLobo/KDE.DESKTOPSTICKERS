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
- [ ] Cada sticker nuevo recibe un color aleatorio de la paleta fija de 6 tonos (no siempre el mismo)
- [ ] La cabecera del sticker muestra "#<id> | <nombre o respaldo>" a la izquierda, y los botones "+", pin, color, "✕" en ese orden a la derecha

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
- [ ] No se puede encoger por debajo de ~210×120px
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

## Cerrar (✕)

- [ ] Botón "✕" cierra la ventana del sticker
- [ ] La nota sigue presente en `~/.stickers/stickers.json` tras cerrar (no se borra)
- [ ] La nota cerrada reaparece en el menú de la bandeja, lista para reabrirse

## Eliminación (desde el Panel de Stickers)

- [ ] El menú de la bandeja lista cada nota por su nombre (o su respaldo derivado del texto), una fila por nota, sin prefijos "Abrir:"/"Eliminar:"
- [ ] Click en una fila del menú de bandeja abre o reenfoca esa nota
- [ ] "Panel de Stickers" (entre las notas y "Salir" en el menú de bandeja) abre una ventana con el listado completo
- [ ] Cada fila del Panel muestra una miniatura de color, el número (inmutable) y el nombre/respaldo
- [ ] "Abrir" en una fila del Panel abre o reenfoca esa nota
- [ ] "✎" en una fila del Panel la vuelve editable; guardar (Enter o perder el foco) cambia el nombre, persistido en `~/.stickers/stickers.json`, y se refleja en la cabecera de esa nota si su ventana está abierta
- [ ] "🗑" en una fila del Panel pide confirmación antes de borrar
- [ ] "No" en el diálogo de confirmación no borra nada
- [ ] "Sí" borra la nota de `~/.stickers/stickers.json`, cierra su ventana si estaba abierta, y la quita tanto del menú de bandeja como del Panel
- [ ] Con más de 10 notas, el menú de bandeja muestra solo las 10 modificadas más recientemente (creación, edición, renombrado, pin, color, movimiento o resize cuentan como modificación), sin controles de paginación
- [ ] Editar/renombrar una nota que no estaba entre las 10 más recientes la hace aparecer en el menú de bandeja (y desplaza a la más antigua de las 10 fuera de la lista)
- [ ] El Panel de Stickers sigue mostrando todas las notas, sin límite de 10

## Persistencia entre sesiones

- [ ] Cerrar sesión de Plasma y volver a iniciar sesión levanta la app automáticamente (autostart)
- [ ] Todos los stickers previamente creados aparecen con su texto, color, posición, tamaño y estado de pin correctos

## Salida

- [ ] Tray icon → "Salir" termina el proceso completo (verificar con `pgrep kde-stickers`)
