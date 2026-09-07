cmake_minimum_required(VERSION 3.16)
project(desktop-stickers VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Widgets DBus)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(desktop-stickers
    src/main.cpp
)

qt_add_qml_module(desktop-stickers
    URI StickersApp
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
        src/qml/StickerWindow.qml
        src/qml/MarkdownView.qml
        src/qml/ColorPalette.qml
        src/qml/StickerPanel.qml
    SOURCES
        src/filestorage.h
        src/filestorage.cpp
        src/kwinbridge.h
        src/kwinbridge.cpp
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
    NO_CACHEGEN
)

target_include_directories(desktop-stickers
    PRIVATE
        src
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

install(TARGETS desktop-stickers DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
