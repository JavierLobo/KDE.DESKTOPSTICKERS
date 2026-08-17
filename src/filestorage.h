#pragma once

#include <QObject>
#include <QString>

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
};
