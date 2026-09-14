#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

// C++ bridge for desktop/OS-integration primitives that neither QML/JS nor
// FileStorage's generic file I/O can provide on their own:
//  - Enumerating installed fonts (QFontDatabase has no QML-exposed
//    equivalent, same situation as QDir/QFile documented in filestorage.h).
//  - Managing the ~/.config/autostart/*.desktop entry, which needs
//    QStandardPaths (to resolve XDG_CONFIG_HOME/XDG_DATA_DIRS correctly)
//    and QCoreApplication::applicationFilePath() (to know the running
//    binary's own real path).
//
// Registered under its own module URI ("Stickers.System", see main.cpp)
// rather than under the app's own "StickersApp" URI, for the same reason
// FileStorage is: SettingsManager.js/settingsStorage.js (members of the
// StickersApp module) need to .import this type, and importing your own
// containing module from one of its own member scripts creates a cyclic
// dependency the QML engine refuses to resolve.
class SystemIntegration : public QObject
{
    Q_OBJECT

public:
    explicit SystemIntegration(QObject *parent = nullptr);

    // Returns the first entry of preferredFamilies (in order) that is
    // actually installed on the system, matched case-insensitively against
    // QFontDatabase::families(). Returns fallback if none of them are
    // installed.
    Q_INVOKABLE QString resolveFontFamily(const QStringList &preferredFamilies, const QString &fallback) const;

    // All font families installed on the system, for the Settings panel's
    // searchable font picker. Filtering by the user's typed text happens in
    // QML against this list (a few hundred entries at most -- cheap to
    // filter per keystroke without needing a C++-side query).
    Q_INVOKABLE QStringList installedFontFamilies() const;

    // Case-insensitive membership check against the same installed-font
    // list, used to flag a user-entered family that isn't actually on this
    // system.
    Q_INVOKABLE bool isFontFamilyInstalled(const QString &family) const;

    // Whether the app's autostart .desktop entry currently exists under
    // $XDG_CONFIG_HOME/autostart (or ~/.config/autostart as the default).
    Q_INVOKABLE bool isAutostartEnabled() const;

    // Creates or removes the autostart .desktop entry. Returns whether the
    // requested state was reached successfully.
    Q_INVOKABLE bool setAutostartEnabled(bool enabled) const;

private:
    QString autostartFilePath() const;
};
