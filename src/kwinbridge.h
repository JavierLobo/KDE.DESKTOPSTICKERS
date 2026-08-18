#pragma once

#include <QObject>
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

protected:
    // Exposed protected (not private) so later tasks in this same class
    // can add setPinned()/updatePositionRule() methods that reuse these
    // without duplicating the rules-list edit logic.
    static QString ruleGroupName(const QString &stickerId);
    void removeRuleIdFromList(const QString &ruleId) const;
    void addRuleIdToList(const QString &ruleId) const;
    bool reconfigureKWin() const;
};
