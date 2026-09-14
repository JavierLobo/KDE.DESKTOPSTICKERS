cmake_minimum_required(VERSION 3.16)

# Overridable so CI can pass -DAPP_VERSION=<release tag> and have the
# generated .deb/.pkg.tar.zst carry the real released version instead of a
# hand-bumped default. Plain local builds (install.sh included) don't pass
# this, so they just get the fallback below.
if(NOT DEFINED APP_VERSION)
    set(APP_VERSION "1.0.0")
endif()
project(desktop-stickers VERSION ${APP_VERSION} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Widgets DBus)

qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(desktop-stickers
    src/main.cpp
)

# Every *.json file here is a language dictionary, discovered at runtime by
# I18n.qml via FileStorage.listFileBaseNames() -- but that only sees what's
# actually compiled into the binary's Qt resources. CONFIGURE_DEPENDS makes
# CMake re-glob (and thus notice a newly-dropped file) whenever the build is
# re-run, so adding a language is now just "drop <code>.json in src/i18n/,
# rebuild" -- no CMakeLists.txt edit. (CONFIGURE_DEPENDS re-globs on build,
# not on process launch -- "at app startup" isn't literally possible for
# files baked into the executable at compile time.)
file(GLOB I18N_DICTIONARIES_ABS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/i18n/*.json")
# Qt's resource system rejects absolute source paths outright (it needs a
# relative path to derive the qrc:/ alias from), so re-relativize what
# file(GLOB) hands back before this reaches RESOURCES below.
set(I18N_DICTIONARIES "")
foreach(_i18n_abs_path ${I18N_DICTIONARIES_ABS})
    file(RELATIVE_PATH _i18n_rel_path "${CMAKE_CURRENT_SOURCE_DIR}" "${_i18n_abs_path}")
    list(APPEND I18N_DICTIONARIES "${_i18n_rel_path}")
endforeach()

# `pragma Singleton` in I18n.qml itself is only a declaration of intent --
# Qt's CMake QML tooling does not scan file contents for it, it needs this
# source-file property to actually register the type as a qmldir
# `singleton` entry (confirmed: without this, I18n.qml still built and ran,
# but every "I18n.tr(...)" call failed at runtime with "Property 'tr' of
# object I18n is not a function", because plain-component registration
# doesn't give QML a live instance to call methods on the way a singleton
# does). Must be set before qt_add_qml_module() processes the file list.
set_source_files_properties(src/qml/I18n.qml PROPERTIES
    QT_QML_SINGLETON_TYPE true
)

qt_add_qml_module(desktop-stickers
    URI StickersApp
    VERSION 1.0
    # Explicit, not left to qt_standard_project_setup(REQUIRES 6.4)'s default:
    # that REQUIRES value sets CMake policy QTP0001 to OLD (pre-6.5 behavior),
    # which silently changes the module's default resource prefix from
    # "/qt/qml/StickersApp" to plain "/StickersApp" -- breaking main.cpp's
    # hardcoded engine.load(QUrl("qrc:/qt/qml/StickersApp/Main.qml")) with a
    # "No such file or directory" at startup (confirmed: this reproduces on
    # a totally clean build of unmodified main, i.e. it's a latent bug from
    # lowering REQUIRES 6.5 -> 6.4, not something introduced here). Pinning
    # RESOURCE_PREFIX explicitly keeps the path main.cpp expects regardless
    # of that policy, and works fine under Qt 6.4 too -- this argument isn't
    # gated behind QTP0001 at all.
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES
        src/qml/Main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
        src/qml/ColorPalette.qml
        src/qml/StickerPanel.qml
        src/qml/SettingsWindow.qml
        src/qml/SettingsRow.qml
        src/qml/SettingsSection.qml
        src/qml/MarkdownToolbar.qml
        src/qml/I18n.qml
    RESOURCES
        # Plain JSON data, not QML/JS -- bundled at the SAME resource path
        # QML_FILES entries get (this module's RESOURCE_PREFIX + the given
        # relative path, e.g. qrc:/qt/qml/StickersApp/src/i18n/es.json),
        # which is what I18n.qml's `i18nDir` property assumes. Globbed above
        # (I18N_DICTIONARIES) instead of listed by hand.
        ${I18N_DICTIONARIES}
    SOURCES
        src/filestorage.h
        src/filestorage.cpp
        src/kwinbridge.h
        src/kwinbridge.cpp
        src/systemintegration.h
        src/systemintegration.cpp
)

# StickerManager.js and storage.js use the classic Qt Quick script directives
# (.pragma library / .import) rather than QML_FILES entries or C++ SOURCES.
# Two things had to be fixed here:
#  1. "SOURCES" only registers files with target_sources() for the C++ build;
#     it does NOT add them to the QML module's resource system, so the QML
#     engine could never find them at qrc:/qt/qml/StickersApp/... at runtime.
#     They must be registered as QML_FILES instead.
#  2. Once registered as QML_FILES, qmlcachegen's AOT compiler tries to
#     precompile them and fails ("Unexpected token `import'") because it does
#     not understand the classic ".import"/".pragma library" directives, only
#     real ECMAScript module syntax or plain QML documents. NO_CACHEGEN tells
#     Qt to still embed them as resources but skip AOT compilation, so they
#     are parsed/interpreted at runtime the classic way instead.
qt_target_qml_sources(desktop-stickers
    QML_FILES
        src/qml/StickerManager.js
        src/code/storage.js
        src/qml/SettingsManager.js
        src/code/settingsStorage.js
    NO_CACHEGEN
)

target_include_directories(desktop-stickers
    PRIVATE
        src
)

# Exposed to QML as Qt.application.version (set via
# app.setApplicationVersion() in main.cpp) for the Settings window's footer.
target_compile_definitions(desktop-stickers
    PRIVATE
        APP_VERSION_STRING="${PROJECT_VERSION}"
)

target_link_libraries(desktop-stickers
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Widgets
        Qt6::DBus
)

include(GNUInstallDirs)

install(TARGETS desktop-stickers DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES LICENSE DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/desktop-stickers)
install(FILES data/io.github.javierlobo.desktopstickers.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

# data/*.desktop keeps the __DESKTOP_STICKERS_BIN__ placeholder that
# scripts/install.sh substitutes for its own (per-user, ~/.local/bin) install
# flow. Packaging installs system-wide instead, so resolve it here to the
# real install path rather than duplicating this fixup in every packaging
# script (PKGBUILD, CPack, ...).
install(CODE "
    execute_process(COMMAND sed -i
        \"s|Exec=__DESKTOP_STICKERS_BIN__|Exec=${CMAKE_INSTALL_FULL_BINDIR}/desktop-stickers|\"
        \"\$ENV{DESTDIR}${CMAKE_INSTALL_FULL_DATADIR}/applications/io.github.javierlobo.desktopstickers.desktop\")
")

set(CPACK_PACKAGE_NAME "desktop-stickers")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_CONTACT "Javier Lobo <franciscojavier.lobo@gmail.com>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Floating sticky notes for the KDE Plasma desktop")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/JavierLobo/KDE.DESKTOPSTICKERS")
set(CPACK_GENERATOR "DEB")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Javier Lobo <franciscojavier.lobo@gmail.com>")
set(CPACK_DEBIAN_PACKAGE_SECTION "utils")
# Pinned instead of autodetected: autodetection needs dpkg in PATH, and
# silently falls back to i386 if it's missing from the build environment.
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
# Runtime CLI tools called via QProcess (kwinbridge.cpp) that shlibdeps can't
# see, since they're not linked, just exec'd: kreadconfig6/kwriteconfig6
# (libkf6config-bin) and qdbus6 (qdbus-qt6). Verified against Debian
# trixie's Contents index — see chat for why it has to be trixie, not
# bookworm/Ubuntu noble.
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libkf6config-bin, qdbus-qt6")
include(CPack)
