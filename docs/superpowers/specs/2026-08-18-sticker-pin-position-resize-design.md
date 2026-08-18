# Diseño: Posición Persistente, Pin por Sticker y Resize

**Fecha:** 2026-08-18
**Estado:** Implementado.
**Depende de:** `docs/superpowers/specs/2026-08-17-multidesktop-markdown-stickers-design.md` (spec original, ya implementado y fusionado a `master`)

## Contexto

El MVP original (spec del 2026-08-17) aceptó dos limitaciones tras investigación exhaustiva:

1. La posición de un sticker arrastrado **no se persiste** entre reinicios de la app — `Window.x`/`Window.y` nunca refleja la posición real bajo este Qt6/KWin/Wayland (Tarea 3, hallazgo empírico).
2. "Todos los escritorios" es un comportamiento **global y automático** para toda la app, vía una regla KWin estática (`kdestickers-alldesktops`, por `WM_CLASS`) instalada una vez.

El usuario ahora pide reabrir ambas limitaciones como requisitos duros, más una feature nueva:

- La posición **debe** persistir en `stickers.json` entre reinicios
- "Todos los escritorios" pasa de automático-global a **opt-in por sticker**, vía un botón tipo pin, persistido en `stickers.json`
- Sin pin, el sticker existe solo en el escritorio donde se creó o se movió (comportamiento nativo de una ventana Wayland normal)
- Los stickers deben poder **redimensionarse** arrastrando desde la esquina inferior derecha

## Filosofía de diseño (heredada del spec original)

La lección del proyecto original fue: **no pelear contra Wayland, dejar que KWin haga el trabajo.** El mecanismo de "todos los escritorios" que sí funciona es una regla de compositor (`kwinrulesrc` + `reconfigure`), no una API que la app llame sobre sí misma. Este diseño extiende esa misma filosofía a granularidad por-ventana, en vez de introducir un mecanismo nuevo y distinto.

## Modelo de datos

`stickers.json` gana dos campos por sticker:

```json
{
  "id": "001",
  "text": "Contenido en Markdown",
  "color": "#FFD700",
  "x": 100,
  "y": 200,
  "width": 300,
  "height": 250,
  "pinned": false,
  "created": "2026-08-17T10:30:00Z",
  "modified": "2026-08-17T15:45:00Z"
}
```

- `pinned` (bool): si el sticker está en todos los escritorios. **Default `false`** para stickers nuevos y para los ya existentes al migrar (comportamiento más conservador que el MVP actual, decisión explícita del usuario 2026-08-18).
- `width`/`height` (int): tamaño del sticker, persistido tras resize. Mínimo ~150×120px (que quepa el header con sus botones), sin máximo.

## Arquitectura: de regla global a reglas por-ventana

**Se desinstala** la regla global `kdestickers-alldesktops` (por `WM_CLASS`) — ya no tiene sentido con pin por sticker, forzaría todos los escritorios sin importar el estado individual.

**Cada `StickerWindow` obtiene un título único**, ej. `kde-stickers-sticker-<id>` (vía `Window.title`), para que KWin pueda identificarla individualmente entre las demás ventanas de la misma app (que comparten `WM_CLASS`).

**Simplificación clave:** un sticker **sin pin** no necesita ninguna regla — ese es el comportamiento nativo de una ventana Wayland (vive en el escritorio donde nació o fue movida). Solo se escribe una regla cuando el pin está activo.

### Mecánica del pin

1. Usuario pulsa 📌 en el header → `Manager.updatePinned(stickerId, true)`
2. Persiste `pinned: true` en `stickers.json`
3. `KWinBridge.setPinned(stickerId, windowTitle, true)`:
   - Escribe una regla `kdestickers-sticker-<id>` matching `wmclass=org.kde.stickers` **y** `title=<windowTitle>` (ambos, para identificar esa ventana concreta), con `desktopsrule=Force`, `desktops` vacío
   - Llama `reconfigure`
4. Al despinnear: se borra esa regla específica + `reconfigure`
5. Al eliminar un sticker pinneado: se borra su regla también (evita reglas huérfanas)

### Mecánica de posición persistente

En vez de que la app intente fijar `Window.x`/`y` (no funciona), se aplica la misma filosofía que el pin: **la app escribe una regla de posición, y deja que KWin coloque la ventana.**

1. Usuario arrastra el sticker (mecanismo ya existente, `Window.startSystemMove()`)
2. Al asentarse el arrastre (mismo patrón de debounce que ya existe), la app lee la **posición real** de su propia ventana consultando a KWin (Qt no la tiene — ver siguiente sección)
3. Con ese valor real: persiste `x`/`y` en `stickers.json` **y** escribe/actualiza una regla `positionrule=Force` con esas coordenadas para esa ventana, + `reconfigure`
4. Al relanzar la app, la ventana se crea y KWin la coloca ahí según la regla — la app no necesita "poner" la ventana en ningún sitio, igual que ya no lo hace para todos-los-escritorios

**Punto crítico a verificar (ver spike):** ya confirmamos empíricamente en la Tarea 1 que `desktopsrule=Force` aplicado en caliente (`reconfigure`, sin recrear la ventana) funciona. `positionrule=Force` es una regla distinta y **no se ha verificado** que se comporte igual — puede que solo aplique en el momento de creación de la ventana, no en caliente. El spike lo confirma antes de comprometer la implementación completa a este enfoque.

## Componente nuevo: `KWinBridge` (C++)

Puente mínimo C++, misma filosofía que `FileStorage` (sin lógica de negocio, solo I/O de sistema que QML no puede hacer):

| Método | Rol |
|---|---|
| `queryRealGeometry(windowTitle) → {x, y}` | Lee la geometría real de una ventana propia consultando a KWin |
| `setPinned(stickerId, windowTitle, pinned: bool)` | Escribe/borra la regla de todos-los-escritorios para esa ventana + `reconfigure` |
| `updatePositionRule(stickerId, windowTitle, x, y)` | Escribe/actualiza la regla de posición para esa ventana + `reconfigure` |
| `removeRules(stickerId)` | Borra cualquier regla asociada a un sticker (llamado al eliminarlo) |

**Punto abierto, honesto — a resolver por el spike:** durante el desarrollo del MVP, cuando un agente necesitaba leer el estado real de una ventana desde fuera, se hacía cargando un script de KWin vía D-Bus (`org.kde.kwin.Scripting`) y leyendo su `console.log` desde `journalctl` — válido para verificación puntual, pero no necesariamente el mecanismo más limpio para que la propia app se consulte continuamente en producción. Alternativas a evaluar: D-Bus devolviendo el valor directamente sin pasar por logs, o el script de KWin escribiendo a un archivo temporal que la app lee. El spike determina cuál usar.

## UI

**Botón de pin (📌):** en el header, junto a 🎨 / "+" / ✕. Toggle — icono resaltado si `pinned: true`, atenuado si no. Un click alterna el estado.

**Resize:** `MouseArea` pequeño (~12×12px) en la esquina inferior derecha del sticker, cursor `Qt.SizeFDiagCursor`. Arrastra ajustando `width`/`height` del `Window` en tiempo real — esto es una operación Qt estándar sin el problema de posicionamiento absoluto de Wayland (redimensionar la propia ventana sí funciona con las APIs normales de Qt, a diferencia de reposicionarla). Al soltar, persiste `width`/`height` en `stickers.json`. Mínimo ~150×120px, sin máximo.

## Spike (paso embebido al final del plan, antes de implementar posición+pin)

Decisión explícita del usuario (2026-08-18): diseñar todo el plan ahora, pero el spike de viabilidad se ejecuta como último paso de investigación, justo antes de implementar la parte de posición+pin — mismo patrón que la Tarea 1 del proyecto original (GATE embebido, no una fase de investigación previa separada).

El spike verifica, sobre una ventana real:

1. **¿`positionrule=Force` aplicado en caliente (vía `reconfigure`, ventana ya creada) mueve realmente la ventana?** — análogo a lo ya probado para `desktopsrule`, pero no es lo mismo y no está garantizado
2. **¿Cuál es la forma más limpia de leer la geometría real desde la app en runtime?** — evaluar D-Bus directo vs. archivo temporal vs. logs, con atención a la latencia (esto se ejecuta en cada asentamiento de arrastre, no solo una vez al instalar)
3. **¿Matchear por `title` + `wmclass` en una regla identifica de forma fiable una ventana individual** entre varias del mismo proceso, sin falsos positivos/negativos?

**Si el spike falla en cualquiera de estos puntos:** es la misma señal de STOP que tuvimos con la Tarea 1 original del MVP — se detiene, se documenta el hallazgo, y se decide con el usuario el camino a seguir (aceptar una limitación parcial, evaluar XWayland, u otra alternativa) — no se improvisa una implementación sobre una base no verificada.

## Manejo de errores

- Regla huérfana (ej. si el borrado de un sticker falla a mitad de camino): se limpia en un barrido simple al reinstalar/reiniciar — cualquier regla `kdestickers-sticker-*` sin sticker correspondiente en el JSON se elimina
- Si `queryRealGeometry` falla (D-Bus no disponible, KWin no responde): no se actualiza la regla de posición ni el JSON para ese evento — se mantiene el último valor conocido, sin crashear
- Sin diálogo de confirmación para pin ni resize (YAGNI, consistente con el resto del proyecto)

## Testing

Sin framework automatizado (decisión ya establecida para todo el proyecto). Verificación manual con evidencia real (capturas, consultas a KWin, reinicios de proceso), mismo estándar que el resto del proyecto — no se acepta "debería funcionar" como evidencia, en ningún task de este plan.

## Fuera de alcance

- Resize desde otras esquinas/bordes (solo inferior-derecha, como se pidió)
- Aspect ratio fijo al redimensionar
- Animaciones de transición en pin/resize
- Deshacer/rehacer resize o pin
- Migración automática de reglas si el usuario edita `kwinrulesrc` a mano fuera de la app
