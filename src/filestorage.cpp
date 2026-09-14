#include "filestorage.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QStandardPaths>
#include <QTextStream>

FileStorage::FileStorage(QObject *parent) : QObject(parent) {}

bool FileStorage::exists(const QString &path) const
{
    return QFile::exists(path);
}

bool FileStorage::ensureDir(const QString &dirPath) const
{
    QDir dir(dirPath);
    if (dir.exists()) {
        return true;
    }
    return dir.mkpath(".");
}

QString FileStorage::readFile(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }
    QTextStream stream(&file);
    const QString content = stream.readAll();
    file.close();
    return content;
}

bool FileStorage::writeFile(const QString &path, const QString &content) const
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    QTextStream stream(&file);
    stream << content;
    file.close();
    return true;
}

QString FileStorage::dataDir() const
{
    // GenericDataLocation resolves $XDG_DATA_HOME (falling back to
    // ~/.local/share) without any app-name suffix, unlike AppDataLocation
    // (which, depending on whether organizationName is set, can produce a
    // nested .../io.github.javierlobo.desktopstickers/desktop-stickers
    // path) -- appending "desktop-stickers" ourselves keeps this exactly
    // the flat $XDG_DATA_HOME/desktop-stickers the redesign spec asks for.
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    return base + QStringLiteral("/desktop-stickers");
}

QString FileStorage::configDir() const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    return base + QStringLiteral("/desktop-stickers");
}

QString FileStorage::toLocalFile(const QUrl &url) const
{
    return url.toLocalFile();
}

QStringList FileStorage::listFileBaseNames(const QString &dirPath, const QString &nameFilter) const
{
    QStringList baseNames;
    const QDir dir(dirPath);
    const QStringList entries = dir.entryList(QStringList() << nameFilter, QDir::Files, QDir::Name);
    baseNames.reserve(entries.size());
    for (const QString &fileName : entries) {
        baseNames.append(QFileInfo(fileName).completeBaseName());
    }
    return baseNames;
}
