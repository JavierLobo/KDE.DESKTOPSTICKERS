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

signals:
    void geometryReported(const QString &windowTitle, double x, double y);

protected:
    // Exposed protected (not private) so later tasks in this same class
    // can add setPinned()/updatePositionRule() methods that reuse these
    // without duplicating the rules-list edit logic.
    static QString ruleGroupName(const QString &stickerId);
    void removeRuleIdFromList(const QString &ruleId) const;
    void addRuleIdToList(const QString &ruleId) const;
    bool reconfigureKWin() const;

private:
    // Guards against the re-entrancy described on queryRealGeometry().
    bool m_geometryQueryInFlight = false;
};
