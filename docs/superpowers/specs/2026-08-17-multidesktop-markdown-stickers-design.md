# Diseño: Sticky Notes Multi-Desktop con Markdown

**Fecha:** 2026-08-17
**Estado:** Aprobado. Revisado el mismo día tras spike de Tarea 1: el mecanismo de multi-desktop original (C++/`KWindowSystem`) resultó no funcional bajo Wayland y fue reemplazado por reglas de ventana de KWin — ver sección "Multi-desktop: mecánica exacta".

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
- Plasma 6.7.4, KWin 6.7.4 bajo sesión **Wayland** (`XDG_SESSION_TYPE=wayland`)
- Qt 6.11.1 (el `qt5-base` detectado inicialmente en el sistema es un paquete legacy no usado por Plasma 6/KWin)
- KDE Frameworks 6.28 (paquete meta `kdeframeworks` no existe como tal; se usan frameworks individuales)

**Hallazgo empírico (spike de Tarea 1):** `KWindowSystem::setOnAllDesktops()` **no existe** en KF6 — se dividió en `KX11Extras`, documentada y confirmada en tiempo de ejecución como **solo-X11** (`"may only be used on X11"`). `KWaylandExtras` no tiene equivalente. Verificado con una ventana Qt6 nativa real: el estado `onAllDesktops` permanece `false` y la ventana desaparece al cambiar de escritorio virtual. Un spike de investigación posterior confirmó además que los protocolos Wayland candidatos (`org_kde_plasma_window_management`, `ext-workspace-v1`, `zkde_virtual_desktop_management_v1`) o no están expuestos por KWin 6.7.4 a clientes sin privilegios, o no están implementados en absoluto en este KWin. La única vía verificada empíricamente que funciona es una **regla de ventana de KWin** (mecanismo de compositor, no una API que la app llame) — ver "Multi-desktop: mecánica exacta".

## Decisión arquitectónica principal: de "Plasma Applet" a app standalone

El proyecto **deja de ser un plugin `Plasma/Applet`** (KPackage embebido en un Containment) y pasa a ser una **aplicación Qt6/QML nativa con autostart**, gestionada vía *System Settings → Startup and Shutdown → Autostart* (un `.desktop` file estándar freedesktop, no el sistema de "Background Services" de Plasma, que es una confusión terminológica del scaffold original).

Esto es consecuencia directa de que cada sticker necesita ser una ventana top-level independiente. Originalmente se planeó marcarla como visible en todos los escritorios vía una API C++ (`KWindowSystem::setOnAllDesktops()`), lo cual ya no aplica tras el hallazgo empírico anterior — pero el modelo de app standalone (ventanas top-level independientes, no un Plasma Applet embebido en un Containment) sigue siendo necesario y correcto, ahora por una razón distinta: es la única forma de tener múltiples ventanas de nivel superior cuyo `WM_CLASS`/app-id pueda ser objetivo de una regla de KWin.

Cambios de empaquetado:
- **Se elimina:** `metadata.json` con `KPackageStructure: Plasma/Applet` (ya no aplica)
- **Se añade:** `CMakeLists.txt` — build pasa de "copiar archivos" a "compilar binario Qt6 + desplegar QML"
- **Se añade:** `.desktop` file freedesktop estándar con `Exec=` apuntando al binario compilado, para registro en Autostart

## Arquitectura de componentes

### Lado C++ (mínimo indispensable — sin lógica de negocio)

| Archivo | Rol |
|---|---|
| `src/main.cpp` | Arranca `QApplication` (no `QGuiApplication`: `Qt.labs.platform`'s `ColorDialog` no tiene implementación nativa vía portal en este sistema y cae a un diálogo basado en QtWidgets, que requiere `QApplication`) + `QQmlApplicationEngine`. Llama `setDesktopFileName("org.kde.stickers")` para fijar el app-id Wayland que la regla de KWin usa para identificar las ventanas de la app. Sin lógica de negocio propia — el único bootstrap estándar de una app Qt6/QML, más el registro del singleton `FileStorage` (ver fila siguiente) |
| `src/filestorage.h`/`.cpp` | Singleton QML (`FileStorage`) que expone primitivas de sistema de archivos (`exists`, `ensureDir`, `readFile`, `writeFile`, `stickersDir`) a `storage.js`. Necesario porque el módulo QML `QtCore` de Qt6 no registra `QDir`/`QFile`/`QIODevice` como tipos instanciables desde QML — solo `StandardPaths` (y similares) están expuestos — así que ninguna sentencia `import` permite hacer `new QDir()`/`new QFile()` desde JavaScript de QML. Esta clase hace la I/O real en C++, donde `QDir`/`QFile` sí están disponibles |

No existe ninguna dependencia de `KF6::WindowSystem` — la Tarea 1 original incluía un `DesktopHelper` envolviendo `KWindowSystem`, descartado tras el hallazgo empírico. Sí existe una clase C++ custom (`FileStorage`, ver tabla arriba), pero no por motivos de multi-desktop: es un puente mínimo de I/O de archivos para `storage.js`, sin ninguna lógica de negocio propia.

### Lado QML/JS

| Componente | Rol |
|---|---|
| `src/qml/Main.qml` | Entry point invisible (nombre con mayúscula inicial: requisito de `qt_add_qml_module`/`loadFromModule` para que el archivo sea cargable como tipo del módulo). Contiene el `StickerManager`, instanciación dinámica de una `StickerWindow` por cada sticker cargado, y el `SystemTrayIcon` |
| `src/qml/StickerManager.js` | Singleton JS: carga stickers al arrancar desde `storage.js`, expone `createSticker()`, `deleteSticker(id)`, `updatePosition(id, x, y)`; mantiene el modelo que alimenta la instanciación de ventanas |
| `src/qml/StickerWindow.qml` | Ventana individual (refactor del `main.qml` actual). Sin registro de "todos los escritorios" en el propio QML — es automático vía la regla de KWin aplicada por `WM_CLASS`. Contiene header (id, botón color, botón "+", botón eliminar) y área de contenido |
| `src/qml/MarkdownView.qml` | `Text` con `textFormat: Text.MarkdownText` — modo preview, estilizado |
| `src/qml/ColorPalette.qml` | Fila de swatches fijos + botón "+" que abre `ColorDialog` (`Qt.labs.platform`) para color libre |
| `src/code/storage.js` | Persistencia JSON existente (`loadAllStickers`, `saveSticker`, `deleteSticker`, `newStickerId`), sin cambios de esquema |

**Flujo de arranque:** `main.cpp` → QML engine carga `Main.qml` → `StickerManager` lee `~/.stickers/stickers.json` vía `storage.js` → por cada sticker instancia una `StickerWindow` (`Qt.createComponent().createObject()`). Cada ventana nace ya con el `WM_CLASS`/app-id compartido de la app, así que la regla de KWin (aplicada una vez, a nivel de compositor) la cubre automáticamente sin que el código QML tenga que hacer nada por ventana.

## Multi-desktop: mecánica exacta

1. Cada `StickerWindow` es una ventana top-level física independiente — no hay ventana "padre" oculta ni sincronización de estado entre ventanas, porque es la *misma* ventana la que se muestra sin importar el escritorio activo
2. El mecanismo es una **regla de ventana de KWin** (el mismo sistema detrás de *System Settings → Window Management → Window Rules*), almacenada en `~/.config/kwinrulesrc`, que fuerza `desktopsrule=Force` (valor `2`) con `desktops` vacío para cualquier ventana cuyo `wmclass` coincida con el app-id de la aplicación (`org.kde.stickers`, fijado vía `QApplication::setDesktopFileName()` en `main.cpp`)
3. La regla se aplica **a nivel de compositor**, no vía una llamada que la app haga sobre sí misma — por eso cubre automáticamente cualquier ventana que la app cree (todos los stickers, presentes y futuros) sin necesidad de código QML/C++ adicional
4. La instalación de la regla ocurre una vez, al instalar la app (`scripts/install.sh`, ver Plan de implementación), escribiendo la sección correspondiente en `kwinrulesrc` y disparando `org.kde.KWin.reconfigure` por D-Bus para que KWin la recargue sin reiniciar sesión
5. **Verificado empíricamente** (spikes de Tarea 1 e investigación posterior) sobre una ventana Qt6 nativa Wayland real en este KWin 6.7.4: sin la regla, `onAllDesktops=false` y la ventana desaparece al cambiar de escritorio; con la regla activa (aplicada en caliente vía `reconfigure`, sin reiniciar el proceso de la ventana), `onAllDesktops=true` y la ventana permanece visible en todos los escritorios virtuales
6. **Caveat conocido:** esto es un archivo de configuración local de KWin, no una API que la app controle en tiempo de ejecución — si el usuario borra o edita manualmente esa regla desde *System Settings*, el comportamiento se pierde hasta reinstalar. Aceptable para el MVP; no se implementa detección/reparación automática

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
- Cambio de posición (ver limitación conocida abajo) → `StickerManager.updatePosition(id, x, y)` → `storage.js.saveSticker()`
- Blur del `TextEdit` (fin de edición) → `storage.js.saveSticker()` con el texto actualizado
- Selección de color → `storage.js.saveSticker()` inmediato
- Creación → `storage.js.saveSticker()` con valores por defecto
- Eliminación → `storage.js.deleteSticker(id)` **antes** de cerrar la ventana (fix de bug: hoy el botón "✕" solo hace `mainWindow.close()` sin persistir el borrado)

**Limitación conocida y aceptada — posición no persiste entre sesiones (hallazgo empírico, Tarea 3):**

En Qt6 sobre esta pila KWin/Wayland, `Window.x`/`Window.y` **nunca refleja la posición real en pantalla**, ni siquiera tras un movimiento exitoso dirigido por el compositor (`Window.startSystemMove()`, verificado que sí mueve la ventana de verdad vía introspección de KWin). Es una limitación del propio protocolo Wayland: los eventos `configure` de `xdg-toplevel` no llevan posición, y ningún protocolo estándar informa a un cliente de sus coordenadas absolutas. Se suma a otro hallazgo previo (Tarea 2): KWin tampoco respeta la posición inicial solicitada por el cliente al crear una ventana (aplica su propia política de colocación).

**Consecuencia aceptada para el MVP:**
- Arrastrar un sticker **sí lo mueve visualmente** de forma real (confirmado con evidencia del compositor)
- La posición arrastrada **no se puede leer de vuelta** para persistirla correctamente — el valor guardado en el JSON no refleja necesariamente dónde quedó el sticker en pantalla
- Al reiniciar la app, cada sticker abre en la posición que KWin decida (su política de colocación), no en su última posición arrastrada
- **Decisión del usuario (2026-08-18):** aceptar esta limitación tal cual, sin forzar XWayland ni investigar un bridge de auto-introspección vía D-Bus/KWin scripting — ambas alternativas quedan documentadas como posibles mejoras futuras, no perseguidas en este MVP
- El campo `x`/`y` del esquema JSON se mantiene (no se elimina), ya que sigue siendo útil como valor inicial/best-effort y no rompe nada mantenerlo

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
- **Botón "+"** en el header de cada `StickerWindow`: pide crear un sticker con offset +30,+30 respecto a la posición QML del originador (`mainWindow.x`/`y`). En la práctica, por la limitación conocida de posición descrita abajo, esa lectura vale `0,0` en el momento del click en este stack Wayland, así que el offset persistido es siempre `{x: 30, y: 30}` independientemente de dónde esté realmente el sticker originador en pantalla — y la posición real en la que aparece la ventana nueva la decide la política de colocación de KWin, no estas coordenadas (ver "Modelo de datos y persistencia")
- Ambos llaman a `StickerManager.createSticker()`: genera ID (`storage.js.newStickerId()`), persiste valores por defecto, instancia dinámicamente la nueva `StickerWindow`. No hay paso adicional de registro multi-desktop por sticker — la nueva ventana ya nace con el `WM_CLASS`/app-id compartido de la app, así que la regla de KWin la cubre automáticamente (ver "Multi-desktop: mecánica exacta")

**Fuera de alcance del MVP (diferido a V2):** atajo de teclado global para crear stickers — requiere registrar shortcuts globales del sistema, complejidad no crítica para el MVP.

**Eliminación:**
- Botón "✕" → `StickerManager.deleteSticker(id)` (persiste el borrado) → cierra la ventana
- Sin diálogo de confirmación en el MVP (YAGNI)

## Manejo de errores

- **JSON corrupto:** `storage.js` ya captura el error de parseo, loguea y devuelve `[]` — arranca sin stickers en vez de crashear
- **Fallo de escritura** (permisos, disco lleno): se loguea con `console.error`, no bloquea la UI; el usuario pierde ese guardado puntual (visible en `journalctl`)
- **Regla de KWin ausente o eliminada por el usuario:** no es error fatal — el sticker se comporta como ventana normal (visible solo en su escritorio de creación). No se implementa detección/reparación automática en el MVP; queda documentado como limitación conocida (ver "Multi-desktop: mecánica exacta", caveat 6)

## Testing

Sin framework de test automatizado (no se justifica para el alcance actual):

- **Spike manual inicial** (primer paso de implementación, ya ejecutado): confirmó que la API C++ original no funciona bajo Wayland y validó empíricamente el mecanismo de reemplazo (regla de KWin), verificado visualmente cambiando de escritorio virtual bajo la sesión Wayland del usuario
- **Checklist manual de QA** para el MVP completo, documentado en `docs/` como guía repetible: crear, mover, editar Markdown, cambiar color, eliminar, cambiar de escritorio, reiniciar sesión y verificar persistencia
- No se proponen tests unitarios QML/JS — sobre-ingeniería para el alcance actual

## Fuera de alcance (diferido explícitamente)

- Atajo de teclado global para crear stickers (V2)
- Diálogo de confirmación al eliminar
- Detección/reparación automática si la regla de KWin es eliminada o falla bajo algún compositor
- Multi-desktop "por escritorio" (posición distinta por desktop) — se descartó a favor de posición global única
- Envío explícito de un sticker a un escritorio específico — es innecesario dado el modelo de posición global
- Sincronización/backend avanzado (V3 del roadmap original)
- Forzar XWayland (`QT_QPA_PLATFORM=xcb`) — evaluado como alternativa durante el spike de Tarea 1 (para multi-desktop) y de nuevo en la Tarea 3 (para lectura/persistencia de posición real), descartado ambas veces a favor de soluciones nativas de Wayland (no requiere forzar un modo de compatibilidad ni depender de que XWayland siga disponible en futuras versiones de Plasma)
- Persistencia exacta de la posición de arrastre entre reinicios de la app — limitación empírica de esta pila Qt6/KWin/Wayland (ver "Modelo de datos y persistencia"), aceptada explícitamente por el usuario el 2026-08-18 en vez de perseguir XWayland o un bridge de auto-introspección D-Bus/KWin scripting
- Bridge de auto-introspección de posición vía D-Bus/KWin scripting (la app consultándose a sí misma su posición real a través del scripting de KWin) — identificado como posible solución futura durante la Tarea 3, no investigado ni implementado en este MVP
