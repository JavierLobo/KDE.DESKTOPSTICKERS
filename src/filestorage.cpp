#include "filestorage.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
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
