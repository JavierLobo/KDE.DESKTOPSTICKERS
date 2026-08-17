#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include "filestorage.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
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

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("StickersApp", "Main");

    return app.exec();
}
