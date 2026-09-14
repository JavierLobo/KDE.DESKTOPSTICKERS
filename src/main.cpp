#include <QApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QUrl>

#include "filestorage.h"
#include "kwinbridge.h"
#include "systemintegration.h"

namespace {

// Moves a single file from an old path to a new one. Returns true if the
// file no longer needs moving afterwards -- either because the move
// succeeded, or because there was nothing to move in the first place
// (source absent: never existed, or a previous, interrupted run already
// moved it). Returns false only when a real, unresolved conflict is left
// behind (both source and destination exist), so the caller can leave the
// legacy directory alone rather than deleting data.
bool moveFileIfNeeded(const QString &from, const QString &to)
{
    if (!QFile::exists(from)) {
        return true;
    }
    if (QFile::exists(to)) {
        qWarning() << "desktop-stickers: both" << from << "and" << to << "exist;"
                   << "leaving the old one in place rather than overwriting -- resolve manually.";
        return false;
    }
    if (QFile::rename(from, to)) {
        qInfo() << "desktop-stickers: migrated" << from << "->" << to;
        return true;
    }
    qWarning() << "desktop-stickers: failed to migrate" << from << "to" << to;
    return false;
}

// One-time, silent migration off the old flat ~/.stickers (not XDG
// compliant, breaks under Flatpak's sandboxed filesystem view) onto
// separate $XDG_DATA_HOME/desktop-stickers (stickers.json) and
// $XDG_CONFIG_HOME/desktop-stickers (settings.json) directories, matching
// FileStorage::dataDir()/configDir(). Must run before anything reads or
// writes through those two methods, hence called first thing in main().
//
// Idempotent and safe to interrupt at any point:
//  - Nothing to do (returns immediately) once ~/.stickers is gone or is
//    already a symlink -- both states mean a previous run completed this.
//  - Each file is moved independently and only if its destination doesn't
//    already exist, so a run that gets killed partway through (e.g. after
//    moving stickers.json but before settings.json) simply finishes the
//    remaining file on the next launch instead of redoing or losing work.
//  - The legacy directory is only ever replaced by the compatibility
//    symlink once it is confirmed empty -- if anything unexpected is left
//    in it (a moveFileIfNeeded conflict, or a stray file this migration
//    doesn't know about), it's left alone and logged rather than deleted.
void migrateLegacyDataDir()
{
    const QString oldDir = QDir::homePath() + QStringLiteral("/.stickers");
    const QFileInfo oldInfo(oldDir);
    if (!oldInfo.exists() || oldInfo.isSymLink()) {
        return;
    }

    const QString newDataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/desktop-stickers");
    const QString newConfigDir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/desktop-stickers");
    QDir().mkpath(newDataDir);
    QDir().mkpath(newConfigDir);

    const bool stickersOk = moveFileIfNeeded(oldDir + QStringLiteral("/stickers.json"),
                                              newDataDir + QStringLiteral("/stickers.json"));
    const bool settingsOk = moveFileIfNeeded(oldDir + QStringLiteral("/settings.json"),
                                              newConfigDir + QStringLiteral("/settings.json"));
    if (!stickersOk || !settingsOk) {
        qWarning() << "desktop-stickers: legacy" << oldDir << "left in place; will retry next launch.";
        return;
    }

    const QDir remaining(oldDir);
    const QStringList leftovers = remaining.entryList(QDir::NoDotAndDotDot | QDir::AllEntries);
    if (!leftovers.isEmpty()) {
        qWarning() << "desktop-stickers: leaving" << oldDir << "in place, unexpected extra entries:" << leftovers;
        return;
    }

    if (!QDir().rmdir(oldDir)) {
        qWarning() << "desktop-stickers: could not remove now-empty" << oldDir;
        return;
    }
    if (QFile::link(newDataDir, oldDir)) {
        qInfo() << "desktop-stickers: replaced" << oldDir << "with a compatibility symlink to" << newDataDir;
    } else {
        qWarning() << "desktop-stickers: could not create a compatibility symlink at" << oldDir;
    }
}

} // namespace

int main(int argc, char *argv[])
{
    // QApplication (not QGuiApplication) is required here even though this
    // is a QML-only UI: Qt.labs.platform's ColorDialog (used by
    // ColorPalette.qml's custom-color "+" button) has no portal-backed
    // native implementation on this setup and falls back to a QtWidgets
    // dialog, which aborts at runtime ("No native ColorDialog implementation
    // available. Qt Labs Platform requires Qt Widgets on this setup.") under
    // plain QGuiApplication. Confirmed via journalctl during Task 5.
    QApplication app(argc, argv);
    app.setApplicationName("desktop-stickers");
    app.setApplicationVersion(QStringLiteral(APP_VERSION_STRING));
    app.setOrganizationName("io.github.javierlobo.desktopstickers");
    // The Wayland app-id / X11 WM_CLASS, used by the KWin window rule
    // (installed separately, see Step 6 and Task 8) to identify which
    // windows should be forced onto all virtual desktops.
    app.setDesktopFileName("io.github.javierlobo.desktopstickers");
    // Sticker windows come and go independently; the app must only quit
    // via the tray icon's "Salir", not when the last sticker closes.
    app.setQuitOnLastWindowClosed(false);

    // Must run before anything (QML included) reads through
    // FileStorage::dataDir()/configDir() -- see migrateLegacyDataDir()'s
    // own comment above for why this is safe to call unconditionally on
    // every launch.
    migrateLegacyDataDir();

    // Registered under its own module URI (not "StickersApp") so that
    // storage.js -- itself part of the StickersApp module -- can .import it
    // without creating a cyclic module dependency. See filestorage.h.
    qmlRegisterSingletonType<FileStorage>(
        "Stickers.Storage", 1, 0, "FileStorage",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new FileStorage(); });

    // Same reasoning as FileStorage above: settingsStorage.js needs to
    // .import this from within the StickersApp module, so it lives under
    // its own URI to avoid a cyclic module dependency. See systemintegration.h.
    qmlRegisterSingletonType<SystemIntegration>(
        "Stickers.System", 1, 0, "SystemIntegration",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new SystemIntegration(); });

    // The app is addressed on the session bus at a fixed, well-known name
    // (io.github.javierlobo.desktopstickers), both for the KWin geometry-query
    // callback below and as a single-instance guard: only one process can
    // ever own this name, so a losing registerService() call means another
    // instance is already running. Checked before constructing KWinBridge so
    // the losing instance never loads its position-watch KWin script.
    if (!QDBusConnection::sessionBus().registerService(QStringLiteral("io.github.javierlobo.desktopstickers"))) {
        qWarning() << "desktop-stickers: another instance is already running"
                   << "(io.github.javierlobo.desktopstickers is already registered on the session bus); exiting."
                   << QDBusConnection::sessionBus().lastError().message();
        return 0;
    }

    // The KWin script that reads a window's real on-screen geometry
    // (KWinBridge::queryRealGeometry) reports its answer by calling back into
    // this process over D-Bus, so the app has to be addressable on the
    // session bus before any such query can be answered.
    auto *kwinBridge = new KWinBridge();
    if (!QDBusConnection::sessionBus().registerObject(
            QStringLiteral("/KWinBridge"), QStringLiteral("io.github.javierlobo.desktopstickers.KWinBridge"),
            // ExportScriptableInvokables, not ExportScriptableSlots: moc
            // classifies a Q_SCRIPTABLE member of a plain public: section as
            // an invokable *method*, not a slot, so the "Slots" flag alone
            // exports nothing at all and every callback is silently dropped.
            // Verified by introspecting the running app with each flag.
            kwinBridge, QDBusConnection::ExportScriptableInvokables)) {
        qWarning() << "desktop-stickers: could not register D-Bus object /KWinBridge;"
                   << "real window positions will not be readable"
                   << QDBusConnection::sessionBus().lastError().message();
    }

    qmlRegisterSingletonType<KWinBridge>(
        "Stickers.KWin", 1, 0, "KWinBridge",
        [kwinBridge](QQmlEngine *, QJSEngine *) -> QObject * {
            // The bridge outlives the QML engine (it is also the D-Bus
            // object registered above), so ownership must stay in C++ or the
            // engine would delete it out from under the D-Bus registration.
            QQmlEngine::setObjectOwnership(kwinBridge, QQmlEngine::CppOwnership);
            return kwinBridge;
        });

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    // Not engine.loadFromModule("StickersApp", "Main"): that convenience
    // wrapper needs Qt 6.5+, and Ubuntu 24.04's own repos only have 6.4.2.
    // This is the equivalent explicit load against the same compiled QML
    // module resource path, and works from Qt 6.2 on.
    //
    // The path includes "src/qml/" because qt_add_qml_module's QML_FILES
    // aliases are computed relative to the project root, preserving the
    // source tree's own subdirectory structure -- confirmed by inspecting
    // the generated .qt/rcc/desktop-stickers_raw_qml_0.qrc, whose <file
    // alias="src/qml/Main.qml"> entry is what actually ends up compiled in,
    // not a flat "Main.qml". A previous version of this literal path (just
    // ".../StickersApp/Main.qml") silently 404'd at startup
    // ("QQmlApplicationEngine failed to load component ... No such file or
    // directory"), reproduced even on a clean build of otherwise-unmodified
    // code -- loadFromModule() would have hidden this, since it resolves
    // through the module's own qmldir type mapping instead of a literal
    // resource path.
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/StickersApp/src/qml/Main.qml")));

    return app.exec();
}
