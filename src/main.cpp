#include <QApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include "filestorage.h"
#include "kwinbridge.h"

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
    app.setApplicationName("kde-stickers");
    app.setOrganizationName("org.kde.stickers");
    // The Wayland app-id / X11 WM_CLASS, used by the KWin window rule
    // (installed separately, see Step 6 and Task 8) to identify which
    // windows should be forced onto all virtual desktops.
    app.setDesktopFileName("org.kde.stickers");
    // Sticker windows come and go independently; the app must only quit
    // via the tray icon's "Salir", not when the last sticker closes.
    app.setQuitOnLastWindowClosed(false);

    // Registered under its own module URI (not "StickersApp") so that
    // storage.js -- itself part of the StickersApp module -- can .import it
    // without creating a cyclic module dependency. See filestorage.h.
    qmlRegisterSingletonType<FileStorage>(
        "Stickers.Storage", 1, 0, "FileStorage",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new FileStorage(); });

    // The app is addressed on the session bus at a fixed, well-known name
    // (org.kde.stickers), both for the KWin geometry-query callback below
    // and as a single-instance guard: only one process can ever own this
    // name, so a losing registerService() call means another instance is
    // already running. Checked before constructing KWinBridge so the
    // losing instance never loads its position-watch KWin script.
    if (!QDBusConnection::sessionBus().registerService(QStringLiteral("org.kde.stickers"))) {
        qWarning() << "kde-stickers: another instance is already running"
                   << "(org.kde.stickers is already registered on the session bus); exiting."
                   << QDBusConnection::sessionBus().lastError().message();
        return 0;
    }

    // The KWin script that reads a window's real on-screen geometry
    // (KWinBridge::queryRealGeometry) reports its answer by calling back into
    // this process over D-Bus, so the app has to be addressable on the
    // session bus before any such query can be answered.
    auto *kwinBridge = new KWinBridge();
    if (!QDBusConnection::sessionBus().registerObject(
            QStringLiteral("/KWinBridge"), QStringLiteral("org.kde.stickers.KWinBridge"),
            // ExportScriptableInvokables, not ExportScriptableSlots: moc
            // classifies a Q_SCRIPTABLE member of a plain public: section as
            // an invokable *method*, not a slot, so the "Slots" flag alone
            // exports nothing at all and every callback is silently dropped.
            // Verified by introspecting the running app with each flag.
            kwinBridge, QDBusConnection::ExportScriptableInvokables)) {
        qWarning() << "kde-stickers: could not register D-Bus object /KWinBridge;"
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
    engine.loadFromModule("StickersApp", "Main");

    return app.exec();
}
