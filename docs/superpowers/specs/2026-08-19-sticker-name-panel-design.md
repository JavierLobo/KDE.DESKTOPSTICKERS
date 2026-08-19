# Diseño: Nombre de sticker, cabecera reordenada, Panel de Stickers

**Fecha:** 2026-08-19
**Estado:** Aprobado, pendiente de plan de implementación.
**Depende de:** `docs/superpowers/specs/2026-08-19-tray-menu-notes-design.md` (implementado y fusionado a `master`, commit `a90581f`)

## Contexto

Con el menú de bandeja paginado ya en `master`, uso real de la app (captura `img/Menu-Sticker.png` adjunta y anotada por el usuario) pidió varios ajustes más:

1. Reordenar los 4 botones de la cabecera de cada sticker.
2. Crear sticker con color aleatorio (de la paleta fija), sin ningún menú de por medio.
3. Un nombre de sticker, editable, mostrado junto al número en la cabecera.
4. Simplificar el menú de bandeja para mostrar solo el nombre por nota (sin los prefijos "Abrir:"/"🗑 Eliminar:" que sí tiene hoy).
5. Una nueva entrada de menú "Panel de Stickers" (entre la lista de notas y "Salir") que abre una ventana con el listado completo — abrir, renombrar y eliminar cada sticker desde ahí.

## Decisiones (usuario, 2026-08-19)

- **Cabecera del sticker**, orden final confirmado tras una corrección:
  ```
  [#001] | [<nombre>] ......... [+] [📍/📌] [🎨] [✕]
  ```
  Número y nombre a la izquierda (separados por "|"), botones agrupados a la derecha en ese orden — "+" primero del grupo, "✕" último.
- **Color al crear**: aleatorio entre los 6 tonos fijos de `ColorPalette.qml` (no todo el espectro RGB) — consistente con el resto de la app, sin colores ilegibles.
- **Nombre**: campo nuevo, persistido en `stickers.json`, editable por el usuario — a diferencia del número (`id`), que nunca cambia. Vacío por defecto en stickers nuevos y existentes al migrar.
- **Respaldo de visualización**: si el nombre está vacío, tanto la cabecera como el menú de bandeja y el Panel muestran la primera línea del texto (la misma lógica que ya usa hoy el menú, función `noteLabel()`) — así siempre se ve algo útil antes de renombrar explícitamente. Este respaldo es solo de visualización, nunca se escribe como si fuera el nombre real.
- **Edición del nombre**: solo desde el Panel de Stickers (acción "Renombrar"). La cabecera del sticker muestra el nombre pero no es editable directamente ahí — mantiene la cabecera simple y evita otro mecanismo de edición redundante.
- **Menú de bandeja**: una fila por nota, mostrando solo el nombre (o su respaldo) — sin prefijos, sin acción de eliminar inline. Click abre/reenfoca, igual que hoy.
- **Panel de Stickers**: acciones confirmadas — abrir/reenfocar, eliminar (con confirmación, reutilizando el mismo diálogo ya existente), renombrar (edición en línea), miniatura de color por fila.
- **El reporte de "+ abre el menú de bandeja"**: se trata como una verificación real a hacer durante la implementación del reordenamiento de botones (Tarea 2 del plan) — probablemente solapamiento visual entre la posición del sticker y el icono de bandeja en pantalla, no necesariamente un bug de código, pero se confirma o se corrige según lo que se encuentre con evidencia real, no se asume.

## Modelo de datos

`stickers.json` gana un campo por sticker:

```json
{
  "id": "001",
  "name": "",
  "text": "...",
  "color": "#FFD700",
  "x": 100, "y": 200, "width": 300, "height": 250, "pinned": false,
  "created": "...", "modified": "..."
}
```

- `name` (string): vacío (`""`) por defecto para stickers nuevos y para los ya existentes al migrar (backfill en `loadAllStickers()`, mismo patrón ya usado para `width`/`height`/`pinned`).

## Lógica de respaldo compartida

Hoy `noteLabel(text)` vive solo en `Main.qml` (deriva la primera línea no vacía del texto, sin encabezados Markdown, truncada a 30 caracteres). La cabecera del propio sticker (`StickerWindow.qml`) necesita esta misma lógica de respaldo, así que se mueve a `StickerManager.js` (ya importado por ambos archivos) como una función exportada, `Manager.displayName(sticker)`:

```js
function displayName(sticker) {
    if (sticker.name && sticker.name.length > 0) {
        return sticker.name
    }
    var lines = sticker.text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/^#+\s*/, "").trim()
        if (line.length > 0) {
            return line.length > 30 ? line.substring(0, 30) + "…" : line
        }
    }
    return "Sticker"
}
```

`Main.qml`'s `noteLabel()` desaparece; su lógica queda absorbida aquí. `refreshNoteList()` pasa a construir `noteList` con `{id, name, label, color}` donde `label = Manager.displayName(sticker)` (para mostrar) y `name` es el campo crudo (para que el Panel sepa qué precargar al renombrar — vacío si aún no se ha puesto uno, nunca el respaldo).

## Cabecera del sticker (`StickerWindow.qml`)

Nueva propiedad `property string stickerName: ""` (poblada desde `sticker.name` al crear, igual que `stickerText`/`stickerColor`). El `RowLayout` de la cabecera pasa de:

```
[#001 (fillWidth)] [📍/📌] [+] [🎨] [✕]
```

a:

```
[#001] [|] [<Manager.displayName> (fillWidth)] [+] [📍/📌] [🎨] [✕]
```

El texto del nombre no necesita reaccionar a cambios en caliente de `stickerName` desde fuera de esta ventana (ver "Fuera de alcance") — se calcula una vez al crear la ventana, igual que el resto de propiedades iniciales.

## Crear sticker con color aleatorio

`StickerManager.js`'s `createSticker(originX, originY)` dejará de usar el color fijo `"#FFD700"`. Como este archivo es `.pragma library` (JS puro, sin acceso a componentes QML), se declara una constante local con los mismos 6 tonos que `ColorPalette.qml`'s `swatchColors` (duplicados intencionalmente — son datos estáticos, no vale la pena una indirección extra para 6 strings) y se elige uno al azar:

```js
var RANDOM_COLORS = ["#FFD700", "#87CEEB", "#FFB6C1", "#FFA07A", "#98FB98", "#DDA0DD"]

function randomColor() {
    return RANDOM_COLORS[Math.floor(Math.random() * RANDOM_COLORS.length)]
}
```

`createSticker` usa `randomColor()` en vez del literal fijo, y añade `name: ""` al registro nuevo.

## Menú de bandeja (`Main.qml`)

`noteMenuModel()` deja de producir pares `{kind: "open"|"delete", ...}` — vuelve a un modelo de una entrada por nota, ya que eliminar ya no vive aquí:

```js
function noteMenuModel() {
    return root.visibleNotes()  // ya son {id, name, label, color}
}
```

El `Instantiator` único pasa a tener un solo tipo de `MenuItem`:

```qml
delegate: Platform.MenuItem {
    text: modelData.label
    onTriggered: root.openOrFocusSticker(modelData.id)
}
```

Se quita el diálogo de confirmación de borrado *de este punto* (sigue existiendo, pero ahora lo dispara el Panel, no el menú de bandeja).

## Panel de Stickers — nuevo archivo `StickerPanel.qml`

Ventana QML normal (no un `Qt.labs.platform.Menu`/`Dialog` — evita por completo el problema ya confirmado de que los submenús/diálogos nativos anidados son frágiles en este stack), declarada como hija estática del `Item` raíz de `Main.qml` (una sola instancia, nunca se recrea — a diferencia de las ventanas de sticker, que sí son dinámicas por necesidad):

```qml
StickerPanel {
    id: stickerPanel
    visible: false
    appRoot: root
}
```

`Main.qml` gana `function openStickerPanel() { stickerPanel.show(); stickerPanel.raise(); stickerPanel.requestActivate() }`, y el menú de bandeja gana una nueva entrada, entre la lista de notas y "Salir":

```qml
Platform.MenuItem {
    text: "Panel de Stickers"
    onTriggered: root.openStickerPanel()
}
```

**Contenido de la ventana**: una lista (una fila por sticker, usando `root.noteList` — ya reactiva) con:

- Miniatura de color (`Rectangle` pequeño, `color: modelData.color`)
- `#<id>` (fijo, no editable)
- Nombre o su respaldo (`modelData.label`) — se convierte en un `TextField` editable al pulsar "✎ Renombrar" en esa fila, precargado con `modelData.name` (el campo crudo, vacío si no se ha puesto ninguno — nunca el respaldo, para no confundir "aún no tiene nombre" con "el nombre es tal cual el texto")
- Botón "Abrir" → `appRoot.openOrFocusSticker(modelData.id)`
- Botón "✎ Renombrar" → activa el modo edición de esa fila; al perder el foco o pulsar Enter, `Manager.updateName(modelData.id, nuevoNombre)` + `appRoot.refreshNoteList()`
- Botón "🗑 Eliminar" → `appRoot.confirmDeleteSticker(modelData.id, modelData.label)` (reutiliza el diálogo de confirmación ya existente y probado en `Main.qml`, sin duplicar esa lógica)

## Manejo de errores

- Un nombre vacío al renombrar (el usuario borra todo el texto y pulsa Enter) es válido — equivale a "quitar el nombre", volviendo al respaldo derivado del texto. No hace falta un caso especial: `Manager.updateName(id, "")` ya produce ese resultado con la misma lógica de respaldo.
- Igual que el resto de acciones del Panel, si el sticker fue eliminado por otra vía justo antes de que una acción de fila se dispare (carrera de baja probabilidad), las funciones reutilizadas (`openOrFocusSticker`, `confirmDeleteSticker`) ya manejan el caso de id-no-encontrado sin lanzar error.

## Fuera de alcance

- Sincronización en caliente del nombre entre una ventana de sticker ya abierta y una edición hecha desde el Panel mientras tanto — igual que el resto de campos (color, tamaño, pin) hoy, cada ventana de sticker es autónoma y solo refleja cambios hechos por su propia interacción; un rename hecho desde el Panel se verá la próxima vez que se abra esa ventana, no en caliente. Consistente con el comportamiento ya existente para todos los demás campos, no una limitación nueva de esta feature.
- Reordenar, buscar o filtrar la lista del Panel — se listan en el orden que ya tiene `Manager.stickers` (orden de creación), igual que el menú de bandeja.
- Editar el nombre directamente desde la cabecera del sticker — solo desde el Panel (decisión explícita, ver arriba).
