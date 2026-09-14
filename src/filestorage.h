#pragma once

#include <QObject>
#include <QString>
#include <QUrl>

// Minimal C++ bridge exposing plain file-system primitives to QML/JavaScript.
//
// Why this exists: storage.js (src/code/storage.js) needs to read/write a
// JSON file under ~/.stickers and ensure that directory exists. The brief's
// original design assumed QDir/QFile/QIODevice were directly usable as QML
// types (`new QDir(...)`, `new QFile(...)`), but Qt6's QtCore QML module
// does not register those C++ classes as QML-instantiable types at all —
// only StandardPaths, Settings, SystemInformation and the *Permission types
// are exported (verified against /usr/lib/qt6/qml/QtCore/plugins.qmltypes).
// So no import statement can make `new QDir()`/`new QFile()` work from QML
// JavaScript; an actual QML-registered type is required. This singleton
// provides exactly the four file-system primitives storage.js needs, doing
// the real I/O in C++ (where QDir/QFile are of course available), while all
// JSON parsing, the sticker schema, and storage.js's public functions stay
// unchanged.
//
// Registered manually in main.cpp under its own module URI
// ("Stickers.Storage", see main.cpp) rather than via QML_ELEMENT/QML_SINGLETON
// under the app's own "StickersApp" URI: storage.js (a member of the
// StickersApp module) needs to `.import` this type, and importing your own
// containing module from one of its own member scripts creates a cyclic
// dependency ("Cyclic dependency detected between StickerManager.js and
// storage.js") that the QML engine refuses to resolve. A separate URI avoids
// the cycle entirely.
class FileStorage : public QObject
{
    Q_OBJECT

public:
    explicit FileStorage(QObject *parent = nullptr);

    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE bool ensureDir(const QString &dirPath) const;
    Q_INVOKABLE QString readFile(const QString &path) const;
    Q_INVOKABLE bool writeFile(const QString &path, const QString &content) const;

    // XDG-compliant data/config directories, replacing the old flat
    // ~/.stickers (not spec-compliant, breaks under Flatpak's sandboxed
    // filesystem view). A one-time migration from ~/.stickers runs in
    // main() before the QML engine loads -- see migrateLegacyDataDir() in
    // main.cpp -- so these are always safe to use directly from here on.
    // Resolved here in C++ via QStandardPaths::writableLocation(), which in
    // C++ returns a QString local path directly -- unlike the QML/JS-visible
    // QtCore StandardPaths singleton, whose writableLocation() returns a
    // QUrl whose string form varies ("file:///home/user" vs "file:/home/user"
    // are both observed serializations). storage.js used to strip a
    // hardcoded "file://" prefix from that QUrl's string form, which
    // silently failed to match the single-slash variant and produced a
    // bogus relative path (see git history / review notes for the "file:"
    // directory this created in the repo root).
    Q_INVOKABLE QString dataDir() const;   // $XDG_DATA_HOME/desktop-stickers -- stickers.json
    Q_INVOKABLE QString configDir() const; // $XDG_CONFIG_HOME/desktop-stickers -- settings.json

    // Converts a file:// QUrl (e.g. from Qt.labs.platform's FolderDialog)
    // to a plain local path. QUrl::toLocalFile() handles the "file://" vs
    // "file:/" and percent-encoding differences correctly -- storage.js
    // used to hand-strip a hardcoded "file://" prefix for a similar case
    // and silently produced a bogus path on the single-slash variant (see
    // getStickersDir()'s comment); this avoids repeating that mistake for
    // Settings' backup export/import folder pickers.
    Q_INVOKABLE QString toLocalFile(const QUrl &url) const;
};
