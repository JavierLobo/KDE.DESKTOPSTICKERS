#pragma once

#include <QObject>
#include <QPointF>
#include <QString>

// C++ bridge for per-window KWin window-rule management at runtime.
//
// Mirrors, in C++, the same kwriteconfig6/kreadconfig6/qdbus6 shell-out
// pattern already proven in scripts/install.sh for the (now retired) global
// multi-desktop rule -- applied per-window here instead, matched by a
// window's unique title (see StickerWindow.qml's "title" property, Task 3)
// in addition to the app's shared wmclass, since a KWin rule otherwise
// can't distinguish between this app's own multiple windows.
class KWinBridge : public QObject
{
    Q_OBJECT

public:
    explicit KWinBridge(QObject *parent = nullptr);

    // Removes any KWin rule associated with a sticker id from the active
    // rules list (both the "all desktops" pin rule and the position rule,
    // added in later tasks, share one rule group id per sticker:
    // "kdestickers-sticker-<id>"). Safe to call even if no rule exists for
    // that id -- a no-op in that case. Called when a sticker is deleted.
    Q_INVOKABLE void removeRules(const QString &stickerId) const;

    // Applies or removes the per-sticker "all desktops" (pin) rule. Pinning
    // writes a title+wmclass-matched Force rule (see setPinned()'s .cpp
    // comments for the exact keys); the rule alone is sufficient because
    // KWin applies desktopsrule=Force live to any already-open matching
    // window, not just on next creation (Task 5 spike finding). Unpinning
    // requires an extra live-window step beyond just removing the rule --
    // see unpinLiveWindow() below for why.
    Q_INVOKABLE void setPinned(const QString &stickerId, const QString &windowTitle, bool pinned) const;

    // Writes (or overwrites) the per-sticker position rule: a
    // title+wmclass-matched Apply (positionrule=3) rule that places the
    // window at (x, y) the next time it is created. Deliberately Apply, not
    // Force (2): the Task 5 spike found Force also sets movable=false live,
    // which would make the window undraggable and break this app's core
    // drag feature. Apply only takes effect at window-creation time, so the
    // live drag that produced (x, y) keeps working via startSystemMove(),
    // and this rule only determines where the window opens next launch.
    // Shares the same rule group id as setPinned() -- see updatePositionRule's
    // .cpp comments for why that's safe.
    Q_INVOKABLE void updatePositionRule(const QString &stickerId, const QString &windowTitle, int x, int y) const;

    // Returns the window's real on-screen top-left position as KWin itself
    // reports it (frameGeometry), or QPointF(-1, -1) on failure/timeout.
    //
    // Needed because Qt cannot answer this on Wayland at all: xdg-toplevel
    // gives clients no absolute-position feedback, so Window.x/y in QML only
    // ever reflects what the app *asked* for, never where the compositor
    // actually put the window (see StickerWindow.qml's own note). KWin knows
    // the truth, and its scripting API is the only way to get at it.
    //
    // Blocking by design: runs a local QEventLoop until the KWin script calls
    // back into receiveGeometry() over D-Bus, or a 2s timeout elapses. Callers
    // are QML click handlers / persistence hooks, not per-frame code.
    //
    // Not re-entrant: because the wait is a nested event loop, timers and
    // other QML handlers keep firing while it blocks, so a second call can
    // begin before the first returns. All queries share one KWin script
    // plugin name, and the inner call would unload the outer call's script
    // out from under it. A re-entrant call therefore returns (-1, -1)
    // immediately rather than corrupting the in-flight one.
    Q_INVOKABLE QPointF queryRealGeometry(const QString &windowTitle);

    // Exposed for the KWin script (via callDBus) to call back into. Not
    // meant to be called directly from QML.
    //
    // The geometry arrives as the string "x,y" rather than as two doubles.
    // That is not a stylistic choice: KWin's callDBus() marshals an integral
    // JS number as D-Bus int32 and a fractional one as double, so the very
    // same call site produces signature "sii", "sid" or "sdd" depending on
    // where the window happens to sit. Only "sdd" would match a
    // (QString,double,double) method, and QtDBus drops a signature mismatch
    // silently -- no error, no reply, just nothing. Measured directly (see
    // Task 5 report): sending (10.5, 20.5) arrived, while (10, 20) and
    // (10, 20.5) were both dropped. Window positions are usually integral,
    // so the numeric form would fail almost always. "s" is unambiguous.
    Q_SCRIPTABLE void receiveGeometry(const QString &windowTitle, const QString &geometry);

    // Exposed for the KWin script started by startPositionWatch() (via
    // callDBus) to call back into whenever ANY sticker window's interactive
    // move gesture ends. Not meant to be called directly from QML.
    //
    // Real-drag testing during this task found that mainWindow.x/y in QML
    // (and therefore onXChanged/onYChanged) never change at all after a
    // window is mapped, even across a genuine startSystemMove()-driven drag
    // that KWin's own frameGeometry confirms really moved the window --
    // Wayland gives clients no absolute-position feedback, and (unlike a
    // one-time startup artifact the original MVP's code once guarded
    // against, where x/y briefly read back the requested position before
    // the Wayland QPA plugin reset its cached value) nothing ever resets/
    // updates x/y again afterward on this Qt6/KWin/Wayland stack. The
    // MouseArea's onReleased never fires either, for the same underlying
    // reason the header comment above it already documents (startSystemMove()
    // hands the whole gesture to the compositor). So there is no
    // client-side Qt/QML signal at all to hook a "the drag just ended"
    // persist trigger to.
    //
    // KWin's own Window scripting object does not have this limitation: it
    // exposes interactiveMoveResizeFinished, fired by KWin itself (not
    // routed through Wayland's client-facing protocol) exactly when an
    // interactive move/resize grab ends. Confirmed by direct signal-probing
    // during this task (connecting to a live sticker window and performing
    // a real synthetic drag): interactiveMoveResizeStarted and -Stepped both
    // fire throughout the drag, and interactiveMoveResizeFinished fires
    // exactly once at the end, with frameGeometry already updated to the
    // final position. This callback only carries windowTitle (not x/y) --
    // the receiving QML side re-reads the position via queryRealGeometry(),
    // so there's no need to marshal numbers here and no risk of the int32-
    // vs-double D-Bus signature ambiguity documented on receiveGeometry().
    Q_SCRIPTABLE void receiveMoveFinished(const QString &windowTitle);

signals:
    void geometryReported(const QString &windowTitle, double x, double y);

    // Emitted when receiveMoveFinished() is called back. windowTitle
    // identifies which sticker's drag just ended; QML listens for this and
    // compares against mainWindow.title.
    void moveFinished(const QString &windowTitle);

protected:
    // Exposed protected (not private) so later tasks in this same class
    // can add setPinned()/updatePositionRule() methods that reuse these
    // without duplicating the rules-list edit logic.
    static QString ruleGroupName(const QString &stickerId);
    void removeRuleIdFromList(const QString &ruleId) const;
    void addRuleIdToList(const QString &ruleId) const;
    bool reconfigureKWin() const;

    // Live-unsets onAllDesktops on the currently-open window matching
    // windowTitle via a fire-and-forget KWin script. Needed because
    // removing the KWin rule alone does not un-pin a window that is
    // already pinned: desktopsrule=Force sets state that persists once the
    // rule is gone (Task 5 spike finding). Must be called only after the
    // rule has been removed and KWin has reconfigured -- see setPinned().
    void unpinLiveWindow(const QString &windowTitle) const;

    // Loads a single, long-lived KWin script (kept loaded, never unloaded
    // by this class -- unlike every other script here, its whole purpose is
    // to keep listening) that connects interactiveMoveResizeFinished on
    // every current AND future sticker window (matched by caption prefix
    // "Sticker ", the format StickerWindow.qml's title property always
    // uses) to a callDBus call into receiveMoveFinished(). See
    // receiveMoveFinished()'s own comment for why this exists at all.
    // Called once, from the constructor -- idempotent by construction since
    // it only ever runs once per process, but still unloads any
    // same-named script left registered by a previous, uncleanly-exited
    // run first, matching the unload-before-load pattern used elsewhere in
    // this class.
    void startPositionWatch() const;

private:
    // Guards against the re-entrancy described on queryRealGeometry().
    bool m_geometryQueryInFlight = false;
};
