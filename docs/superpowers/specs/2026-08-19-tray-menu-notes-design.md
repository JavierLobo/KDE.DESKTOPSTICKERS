# Diseño: Menú de bandeja con lista de notas, cierre no destructivo, guard de instancia única

**Fecha:** 2026-08-19
**Estado:** Aprobado, pendiente de plan de implementación.
**Depende de:** `docs/superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md` (implementado y fusionado a `master`, commit `77772e8`)

## Contexto

Uso real de la app (ya fusionada a `master`, a punto de subir a un remoto público) encontró varios problemas. Dos ya se corrigieron directamente, sin necesidad de spec, por ser arreglos acotados a flujos ya existentes (commit `d51c5ae`, `master`):

- **Segundo icono de bandeja al relanzar la app**: `main.cpp` ya intentaba registrar el servicio D-Bus `org.kde.stickers` pero solo avisaba con un `qWarning()` si fallaba, sin salir. Corregido: ahora sale inmediatamente si el registro falla (single-instance guard real).
- **Scroll y solapamiento de contenido largo**: el área de edición y la vista previa Markdown no tenían `Flickable`/`ScrollView` ni `clip`, así que el contenido que no cabía se derramaba visualmente fuera del sticker en vez de hacer scroll. Corregido con `ScrollView` + `clip: true` en ambas áreas, y cambiando el área de edición de `TextEdit` a `TextArea` (que sí auto-desplaza para mantener el cursor visible).
- **Markdown**: enlaces ahora abren de verdad (`Qt.openUrlExternally`, antes interceptado por el `MouseArea` de click-para-editar) y los bloques de código ahora tienen una caja remarcada (Qt6's `Text.MarkdownText` no da ninguna por sí solo — confirmado con pruebas aisladas — se soluciona partiendo el contenido en trozos prosa/código).

Esta spec cubre lo que queda, que sí es un cambio arquitectónico: **rediseño del menú del icono de bandeja** para listar las notas existentes, más el cambio de semántica del botón "X" que ese rediseño implica.

## Requisito original y limitación técnica descubierta

El usuario pidió un menú de bandeja con: "Nuevo sticker", separador, hasta 10 notas listadas, separador, "Salir"; click en una nota la reabre; cada nota tiene una forma de eliminarla con confirmación; si hay más de 10, un submenú "Notas ->" con las demás, scrollable si hay 10+.

```Menu
Nuevo Sticker
-------------
Nota1       X
Nota2       X
...
Nota10      X
-------------
Notas -> (Abre submenu)
-------------
Salir
```

```Submenu
<Boton Fecha arriba>
-------------
Nota1       X
Nota2       X
...
NotaN       X
-------------
<Boton Fecha abajo>
```


**Investigación (spike de diseño, no de implementación) encontró una limitación real de la plataforma**: `Qt.labs.platform.Menu` anidado dentro de otro `Menu` (patrón necesario tanto para "submenú por nota con Abrir/Eliminar" como para "Notas ->") **provoca un error fatal** ("No native Menu implementation available") en una prueba aislada sobre este stack (Qt 6.11, KDE 6, Wayland) — el motor nativo de menús no está disponible para submenús anidados y cae a un `QMenu` de QtWidgets que, además, falla al establecer el grab de popup en Wayland por falta de `transientParent`. La verificación en vivo dentro de la app real fue inconclusa (el propio subsistema de menú de bandeja quedó en un estado no-responsivo tras las pruebas repetidas, recuperable con un reinicio de sesión), pero el hallazgo del crash en aislado ya es suficiente para no apostar la arquitectura a submenús anidados.

**Decisión (usuario, 2026-08-19):** ningún menú anidado, pero se conserva la navegación por páginas que pedía el diagrama de arriba — mismo menú, sin reconstruir uno anidado. Cada nota se representa como dos entradas **planas**, seguidas: "Abrir: `<título>`" y "🗑 Eliminar: `<título>`" (con confirmación). Cuando hay más notas de las que caben en una página, "▲ Anteriores" / "▼ Siguientes" son entradas **planas normales** (no un submenú) que cambian qué porción de la lista se muestra, dentro del mismo menú:

```Menu (con más de 10 notas)
Nuevo sticker
-------------
▲ Anteriores          (solo visible si no es la primera página)
-------------
Nota1          Abrir
Nota1          Eliminar
...
Nota10         Abrir
Nota10         Eliminar
-------------
▼ Siguientes           (solo visible si hay más notas)
-------------
Salir
```

Tamaño de página: 10 notas (mismo número que pedía el diseño original).

## Cambio de semántica: el botón "X"

Hoy, "X" en el header del sticker borra la nota permanentemente sin confirmación (`Manager.removeSticker` + `close()` + `destroy()`).

**Nuevo comportamiento:** "X" **solo cierra** la ventana — la nota sigue existiendo en `stickers.json` y reaparece en el menú de bandeja para reabrirla. Borrar una nota es una acción **distinta**, solo alcanzable desde el menú de bandeja ("🗑 Eliminar: `<título>`"), y **pide confirmación** antes de ejecutar el borrado.

## Arquitectura

### Registro de ventanas abiertas (`Main.qml`)

Para poder reabrir una nota sin duplicar su ventana si ya está abierta, `Main.qml` mantiene un mapa `id → instancia de StickerWindow`:

```qml
property var openWindows: ({})

function registerWindow(id, win) {
    openWindows[id] = win
}

function unregisterWindow(id) {
    delete openWindows[id]
}

function openOrFocusSticker(id) {
    var win = openWindows[id]
    if (win) {
        win.raise()
        win.requestActivate()
        return
    }
    var sticker = Manager.stickers.find(function(s) { return s.id === id })
    if (sticker) {
        createStickerWindow(sticker)
    }
}
```

`createStickerWindow(sticker)` (ya existente) se extiende para llamar `root.registerWindow(sticker.id, w)` tras crear la ventana.

`StickerWindow.qml`'s botón "X" se reescribe para llamar `mainWindow.appRoot.unregisterWindow(stickerId)` antes de `close()`/`destroy()`, y **ya no llama a `Manager.removeSticker`**.

### Lista de notas, paginación y reconstrucción del menú

`Main.qml` mantiene `property var noteList: []` (copia plana y completa de `Manager.stickers` — solo `id` y una etiqueta derivada del texto) y `property int notePage: 0`, reasignados (no mutados in-place, para que los bindings se enteren del cambio) cada vez que la lista de stickers cambia:

```qml
readonly property int notePageSize: 10

function refreshNoteList() {
    noteList = Manager.stickers.map(function(s) {
        return { id: s.id, label: noteLabel(s.text) }
    })
    var maxPage = Math.max(0, Math.ceil(noteList.length / notePageSize) - 1)
    if (notePage > maxPage) notePage = maxPage
}

function noteLabel(text) {
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/^#+\s*/, "").trim()
        if (line.length > 0) {
            return line.length > 30 ? line.substring(0, 30) + "…" : line
        }
    }
    return "Sticker"
}

function visibleNotes() {
    var start = notePage * notePageSize
    return noteList.slice(start, start + notePageSize)
}

function hasPrevPage() { return notePage > 0 }
function hasNextPage() { return (notePage + 1) * notePageSize < noteList.length }
function goPrevPage() { if (hasPrevPage()) notePage -= 1 }
function goNextPage() { if (hasNextPage()) notePage += 1 }
```

Se llama `refreshNoteList()`: en `Component.onCompleted` (tras `Manager.loadStickers()`), tras `createNewSticker()`, y tras una eliminación confirmada. Cambiar de página (`goPrevPage`/`goNextPage`) solo cambia `notePage` — la reconstrucción del menú (sección siguiente) reacciona a eso mismo, vía `visibleNotes()`.

### Menú de bandeja (plano, sin anidar, paginado)

```qml
Platform.SystemTrayIcon {
    menu: Platform.Menu {
        id: trayMenu
        Platform.MenuItem {
            text: "Nuevo sticker"
            onTriggered: root.createNewSticker(100, 100)
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: "▲ Anteriores"
            visible: root.hasPrevPage()
            onTriggered: root.goPrevPage()
        }
        Instantiator {
            model: root.visibleNotes()
            delegate: Platform.MenuItem {
                text: "Abrir: " + modelData.label
                onTriggered: root.openOrFocusSticker(modelData.id)
            }
            onObjectAdded: (index, object) => trayMenu.insertItem(index + 3, object)
            onObjectRemoved: (index, object) => trayMenu.removeItem(object)
        }
        Instantiator {
            model: root.visibleNotes()
            delegate: Platform.MenuItem {
                text: "🗑 Eliminar: " + modelData.label
                onTriggered: root.confirmDeleteSticker(modelData.id, modelData.label)
            }
            onObjectAdded: (index, object) => trayMenu.insertItem(/* después del último "Abrir" visible */, object)
            onObjectRemoved: (index, object) => trayMenu.removeItem(object)
        }
        Platform.MenuItem {
            text: "▼ Siguientes"
            visible: root.hasNextPage()
            onTriggered: root.goNextPage()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: "Salir"
            onTriggered: Qt.quit()
        }
    }
}
```

`visibleNotes()` se re-evalúa cada vez que `notePage` o `noteList` cambian (son propiedades QML observables), lo que dispara la reconstrucción de ambos `Instantiator`s con la página correspondiente — no hace falta lógica adicional para "refrescar" el menú al paginar. `▲ Anteriores`/`▼ Siguientes` usan `visible` (no se quitan/ponen dinámicamente vía `Instantiator`, son ítems fijos cuya visibilidad depende de la página actual).

(Dos `Instantiator`s separados, uno para todos los "Abrir" y otro para todos los "Eliminar", es más simple de indexar correctamente que intercalar una función de índice; la tarea de implementación decide la posición exacta de inserción del segundo grupo — debe quedar tras el último "Abrir" y antes de "▼ Siguientes".)

### Confirmación de borrado

`Qt.labs.platform.MessageDialog` (mismo módulo que `ColorDialog`, que ya funciona en producción vía el fallback de `QApplication`/Widgets establecido en `main.cpp`):

```qml
Platform.MessageDialog {
    id: deleteConfirmDialog
    property string pendingId: ""
    text: "¿Eliminar esta nota? Esta acción no se puede deshacer."
    buttons: Platform.MessageDialog.Yes | Platform.MessageDialog.No
    onYesClicked: {
        var win = root.openWindows[pendingId]
        if (win) {
            root.unregisterWindow(pendingId)
            win.close()
            win.destroy()
        }
        Manager.removeSticker(pendingId)
        root.refreshNoteList()
    }
}

function confirmDeleteSticker(id, label) {
    deleteConfirmDialog.pendingId = id
    deleteConfirmDialog.text = "¿Eliminar \"" + label + "\"? Esta acción no se puede deshacer."
    deleteConfirmDialog.open()
}
```

## Manejo de errores

- Si `Manager.stickers.find(...)` no encuentra el id en `openOrFocusSticker` (nota borrada entre que se abrió el menú y se hizo click — carrera de baja probabilidad), no pasa nada; no hay entrada de menú que reabrir.
- Si `openWindows[id]` apunta a una ventana ya destruida por otra vía (no debería ocurrir dado que toda ruta de cierre pasa por `unregisterWindow`), `win.raise()` fallaría con un objeto QML inválido — la tarea de implementación debe verificar con una prueba real si esto puede ocurrir y, si es un riesgo real, guardar de forma defensiva.

## Riesgo pendiente de verificar (spike embebido en el plan)

No se pudo confirmar en vivo, dentro de la app real, que:

1. Un menú de bandeja plano con `Instantiator` y varias entradas (hasta 20: 2 por nota, página de 10 notas) se muestra y funciona correctamente al hacer click real en el icono.
2. Cambiar de página (`▲ Anteriores`/`▼ Siguientes`) reconstruye el menú correctamente sin cerrarlo/romperlo — verificar si triggerar un `Platform.MenuItem` cuyo efecto es reconstruir el propio menú que lo contiene (vía el cambio de `notePage` → `visibleNotes()` → `Instantiator`) se comporta bien o si el menú se cierra al hacer click, obligando a reabrirlo (aceptable si es así, pero hay que confirmarlo, no asumirlo).
3. `Qt.labs.platform.MessageDialog` se muestra y responde a clicks reales sin el mismo problema de popup-grab encontrado en `Menu` anidado.

El plan de implementación debe incluir un spike temprano (antes de comprometer el resto de tareas a esta arquitectura) que verifique los tres puntos con evidencia real (build real, clicks sintéticos reales sobre el icono de bandeja ya identificado vía `qdbus6 org.kde.StatusNotifierWatcher`, capturas de pantalla) — siguiendo el mismo patrón de spike-antes-de-comprometerse usado en las dos rondas anteriores de este proyecto. Si el spike encuentra que el menú plano tampoco se muestra de forma fiable, ese es el punto de STOP-y-reportar del plan, igual que en las rondas anteriores.

## Fuera de alcance

- Reordenar o filtrar la lista de notas en el menú (se listan en el orden que ya tiene `Manager.stickers`, típicamente orden de creación).
- Editar el texto de una nota desde el menú (solo abrir/eliminar).
- Tamaño de página configurable — fijo en 10, como el diseño original.
- Indicador de página actual (ej. "página 2 de 3") — no pedido, se puede añadir después si hace falta.
