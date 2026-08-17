# Diseño: Sticky Notes Multi-Desktop con Markdown

**Fecha:** 2026-08-17
**Estado:** Aprobado, pendiente de plan de implementación

## Contexto

El proyecto KDE Stickers existe hoy como un scaffold inicial: `metadata.json` lo declara como `Plasma/Applet`, pero `src/ui/main.qml` usa un `Window` standalone con `WindowStaysOnTopHint`, y la documentación (`QUICKSTART.md`) describe activarlo desde "Background Services" — un modelo inconsistente entre packaging y código real.

Este diseño resuelve esa inconsistencia y especifica el comportamiento completo requerido:

- Los stickers se pueden mover libremente por el escritorio
- Aparecen simultáneamente en **todos** los escritorios virtuales, con una única posición global (no hay posición "por escritorio")
- Se crean individualmente (tray icon o botón "+")
- Se persisten en `~/.stickers/stickers.json`
- El texto se escribe y visualiza en Markdown completo (tablas, código, citas, listas, etc.), alternando automáticamente entre edición (click) y preview (blur)
- El color de fondo se elige de una paleta fija o un selector libre

**Entorno de desarrollo confirmado:**
- Plasma 6.7.4, KWin bajo sesión **Wayland** (`XDG_SESSION_TYPE=wayland`)
- Qt 6.x (el `qt5-base` detectado en el sistema es un paquete legacy no usado por Plasma 6/KWin)
- KDE Frameworks 6 (paquete meta `kdeframeworks` no existe como tal; se usan frameworks individuales, en particular `KWindowSystem`)

## Decisión arquitectónica principal: de "Plasma Applet" a app standalone

El proyecto **deja de ser un plugin `Plasma/Applet`** (KPackage embebido en un Containment) y pasa a ser una **aplicación Qt6/QML nativa con autostart**, gestionada vía *System Settings → Startup and Shutdown → Autostart* (un `.desktop` file estándar freedesktop, no el sistema de "Background Services" de Plasma, que es una confusión terminológica del scaffold original).

Esto es consecuencia directa de que cada sticker necesita ser una ventana top-level independiente marcada como visible en todos los escritorios vía `KWindowSystem::setOnAllDesktops()` — una API que requiere una capa C++ mínima, y que no encaja en el modelo de contención de un Plasma Applet.

Cambios de empaquetado:
- **Se elimina:** `metadata.json` con `KPackageStructure: Plasma/Applet` (ya no aplica)
- **Se añade:** `CMakeLists.txt` — build pasa de "copiar archivos" a "compilar binario Qt6 + desplegar QML"
- **Se añade:** `.desktop` file freedesktop estándar con `Exec=` apuntando al binario compilado, para registro en Autostart

## Arquitectura de componentes

### Lado C++ (superficie mínima, un solo propósito)

| Archivo | Rol |
|---|---|
| `src/main.cpp` | Arranca `QGuiApplication` + `QQmlApplicationEngine`, registra `DesktopHelper` como singleton QML |
| `src/desktophelper.h/.cpp` | Clase `DesktopHelper` con `Q_INVOKABLE void setOnAllDesktops(QWindow*, bool)`, envuelve `KWindowSystem::setOnAllDesktops()`. Única pieza C++ del proyecto — todo lo demás es QML/JS |

`KWindowSystem` abstrae X11 y Wayland internamente (despacha a `_NET_WM_DESKTOP` en X11, al protocolo `plasma-window-management` en Wayland/KWin) — no se necesitan dos caminos de código.

### Lado QML/JS

| Componente | Rol |
|---|---|
| `src/qml/main.qml` | Entry point invisible. Contiene el `StickerManager`, un `Repeater`/instanciación dinámica que crea una `StickerWindow` por cada sticker cargado, y el `SystemTrayIcon` |
| `src/qml/StickerManager.js` | Singleton JS: carga stickers al arrancar desde `storage.js`, expone `createSticker()`, `deleteSticker(id)`, `updatePosition(id, x, y)`; mantiene el modelo que alimenta la instanciación de ventanas |
| `src/qml/StickerWindow.qml` | Ventana individual (refactor del `main.qml` actual). En `Component.onCompleted` llama a `DesktopHelper.setOnAllDesktops(this, true)`. Contiene header (id, botón color, botón "+", botón eliminar) y área de contenido |
| `src/qml/MarkdownView.qml` | `Text` con `textFormat: Text.MarkdownText` — modo preview, estilizado |
| `src/qml/ColorPalette.qml` | Fila de swatches fijos + botón "+" que abre `ColorDialog` (`Qt.labs.platform`) para color libre |
| `src/code/storage.js` | Persistencia JSON existente (`loadAllStickers`, `saveSticker`, `deleteSticker`, `newStickerId`), sin cambios de esquema |

**Flujo de arranque:** `main.cpp` → QML engine carga `main.qml` → `StickerManager` lee `~/.stickers/stickers.json` vía `storage.js` → por cada sticker instancia una `StickerWindow` (`Qt.createComponent().createObject()`) → cada ventana se auto-registra "todos los escritorios" al completarse.

## Multi-desktop: mecánica exacta

1. Cada `StickerWindow` es una ventana top-level física independiente — no hay ventana "padre" oculta ni sincronización de estado entre ventanas, porque es la *misma* ventana la que se muestra sin importar el escritorio activo
2. `Component.onCompleted: DesktopHelper.setOnAllDesktops(Window.window, true)` marca la ventana a nivel de KWin como perteneciente a todos los escritorios virtuales
3. **Riesgo conocido:** bajo Wayland, el comportamiento depende de que KWin soporte el protocolo `plasma-window-management` para la app en cuestión. Se considera altamente probable en una instalación estándar de Plasma 6.7 (es funcionalidad básica de escritorio y KWin es el compositor de referencia), pero debe **verificarse empíricamente** antes de construir el resto — ver Plan de implementación

## Modelo de datos y persistencia

Sin cambios al esquema JSON existente:

```json
{
  "stickers": [
    {
      "id": "001",
      "text": "Contenido en Markdown",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

Archivo único `~/.stickers/stickers.json` (suficiente para decenas de stickers, no se necesita un archivo por sticker).

**Puntos de guardado:**
- `onReleased` del drag del header → `StickerManager.updatePosition(id, x, y)` → `storage.js.saveSticker()`
- Blur del `TextEdit` (fin de edición) → `storage.js.saveSticker()` con el texto actualizado
- Selección de color → `storage.js.saveSticker()` inmediato
- Creación → `storage.js.saveSticker()` con valores por defecto
- Eliminación → `storage.js.deleteSticker(id)` **antes** de cerrar la ventana (fix de bug: hoy el botón "✕" solo hace `mainWindow.close()` sin persistir el borrado)

## Edición / Preview de Markdown

- **Estado por defecto:** preview (`MarkdownView.qml`)
- **Click dentro del área de contenido** → cambia a `TextEdit` con el Markdown crudo, foco automático
- **Pierde el foco** (`onActiveFocusChanged`) → guarda y vuelve a `MarkdownView`
- `TextEdit` y `MarkdownView` ocupan el mismo espacio de layout, alternan por `visible` (no se destruyen, para no perder estado de cursor/selección)
- Renderizado vía `Text.MarkdownText` nativo de Qt6 (usa `md4c`, soporta tablas, código, citas, listas, encabezados, negrita/cursiva, enlaces, checkboxes — sin necesidad de parser custom)
- Sin botón de toggle manual — el mecanismo click/blur lo reemplaza completamente

## Colores

- Paleta fija de 6 swatches: `#FFD700` amarillo, `#87CEEB` celeste, `#FFB6C1` rosa (ya usados en el proyecto), más `#FFA07A` naranja claro, `#98FB98` verde menta, `#DDA0DD` malva — todos tonos pastel consistentes con la estética post-it existente
- Último elemento: `"+"` abre `ColorDialog` para color libre (hex arbitrario)
- Selección aplica el color inmediatamente y persiste vía `storage.js.saveSticker()`
- Se despliega en un `Popup` anclado al botón 🎨 del header (mismo patrón que hoy)

## Creación y eliminación

**Creación — dos entradas, mismo flujo:**
- **Tray icon** (`SystemTrayIcon`): menú contextual "Nuevo sticker" / "Salir"
- **Botón "+"** en el header de cada `StickerWindow`: crea un sticker cercano (offset +30,+30 respecto al originador)
- Ambos llaman a `StickerManager.createSticker()`: genera ID (`storage.js.newStickerId()`), persiste valores por defecto, instancia dinámicamente la nueva `StickerWindow`, aplica `setOnAllDesktops(true)`

**Fuera de alcance del MVP (diferido a V2):** atajo de teclado global para crear stickers — requiere registrar shortcuts globales del sistema, complejidad no crítica para el MVP.

**Eliminación:**
- Botón "✕" → `StickerManager.deleteSticker(id)` (persiste el borrado) → cierra la ventana
- Sin diálogo de confirmación en el MVP (YAGNI)

## Manejo de errores

- **JSON corrupto:** `storage.js` ya captura el error de parseo, loguea y devuelve `[]` — arranca sin stickers en vez de crashear
- **Fallo de escritura** (permisos, disco lleno): se loguea con `console.error`, no bloquea la UI; el usuario pierde ese guardado puntual (visible en `journalctl`)
- **`setOnAllDesktops` sin efecto:** no es error fatal — el sticker se comporta como ventana normal (visible solo en su escritorio de creación). No se implementa detección/fallback automático en el MVP; se documenta como limitación conocida si el spike revela problemas

## Testing

Sin framework de test automatizado (no se justifica para el alcance actual):

- **Spike manual inicial** (primer paso de implementación): mini-ejecutable que crea una ventana y llama a `setOnAllDesktops(true)`, verificado visualmente cambiando de escritorio virtual bajo la sesión Wayland del usuario
- **Checklist manual de QA** para el MVP completo, documentado en `docs/` como guía repetible: crear, mover, editar Markdown, cambiar color, eliminar, cambiar de escritorio, reiniciar sesión y verificar persistencia
- No se proponen tests unitarios QML/JS — sobre-ingeniería para el alcance actual

## Fuera de alcance (diferido explícitamente)

- Atajo de teclado global para crear stickers (V2)
- Diálogo de confirmación al eliminar
- Detección/fallback automático si `setOnAllDesktops` falla bajo algún compositor
- Multi-desktop "por escritorio" (posición distinta por desktop) — se descartó a favor de posición global única
- Envío explícito de un sticker a un escritorio específico — es innecesario dado el modelo de posición global
- Sincronización/backend avanzado (V3 del roadmap original)
