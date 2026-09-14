#include "systemintegration.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QIODevice>
#include <QStandardPaths>
#include <QTextStream>

namespace {
const char *kDesktopFileName = "io.github.javierlobo.desktopstickers.desktop";
}

SystemIntegration::SystemIntegration(QObject *parent) : QObject(parent) {}

QString SystemIntegration::resolveFontFamily(const QStringList &preferredFamilies, const QString &fallback) const
{
    const QStringList installed = QFontDatabase::families();
    for (const QString &preferred : preferredFamilies) {
        for (const QString &family : installed) {
            if (family.compare(preferred, Qt::CaseInsensitive) == 0) {
                return family;
            }
        }
    }
    return fallback;
}

QStringList SystemIntegration::installedFontFamilies() const
{
    return QFontDatabase::families();
}

bool SystemIntegration::isFontFamilyInstalled(const QString &family) const
{
    const QStringList installed = QFontDatabase::families();
    for (const QString &f : installed) {
        if (f.compare(family, Qt::CaseInsensitive) == 0) {
            return true;
        }
    }
    return false;
}

QString SystemIntegration::autostartFilePath() const
{
    // GenericConfigLocation resolves $XDG_CONFIG_HOME (falling back to
    // ~/.config), unlike scripts/install.sh's hardcoded "$HOME/.config" --
    // matters on setups that override XDG_CONFIG_HOME.
    const QString configDir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    return configDir + QStringLiteral("/autostart/") + QString::fromLatin1(kDesktopFileName);
}

bool SystemIntegration::isAutostartEnabled() const
{
    return QFile::exists(autostartFilePath());
}

bool SystemIntegration::setAutostartEnabled(bool enabled) const
{
    const QString targetPath = autostartFilePath();

    if (!enabled) {
        // Not existing already is success too -- toggling off is idempotent.
        return !QFile::exists(targetPath) || QFile::remove(targetPath);
    }

    if (!QDir().mkpath(QFileInfo(targetPath).absolutePath())) {
        return false;
    }

    // Prefer copying the already-installed .desktop file: it was fixed up
    // at install time (CMake's install(CODE "sed -i ...") step, or
    // scripts/install.sh) to have a real Exec= path, so this is correct
    // for both packaged and per-user dev installs without re-deriving that
    // logic here. QStandardPaths::locate() searches XDG_DATA_DIRS
    // (/usr/share/applications, ~/.local/share/applications, ...).
    const QString installedPath = QStandardPaths::locate(
        QStandardPaths::ApplicationsLocation, QString::fromLatin1(kDesktopFileName));

    QString content;
    if (!installedPath.isEmpty()) {
        QFile installedFile(installedPath);
        if (installedFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            content = QTextStream(&installedFile).readAll();
        }
    }

    if (content.isEmpty()) {
        // Fallback: no installed .desktop file found on XDG_DATA_DIRS (e.g.
        // an unusual install layout) -- synthesize one from the currently
        // running binary's own real path, always correct for *this*
        // process regardless of how it got installed.
        content = QStringLiteral(
                      "[Desktop Entry]\n"
                      "Type=Application\n"
                      "Name=Desktop Stickers\n"
                      "Name[es]=Desktop Stickers\n"
                      "Comment=Sticky notes flotantes en el escritorio\n"
                      "Comment[es]=Sticky notes flotantes en el escritorio\n"
                      "Exec=%1\n"
                      "Icon=document-properties\n"
                      "Terminal=false\n"
                      "Categories=Utility;\n"
                      "X-KDE-autostart-phase=1\n")
                      .arg(QCoreApplication::applicationFilePath());
    }

    QFile targetFile(targetPath);
    if (!targetFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }
    QTextStream stream(&targetFile);
    stream << content;
    targetFile.close();
    return true;
}
