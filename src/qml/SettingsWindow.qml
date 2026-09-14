import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "SettingsManager.js" as Settings
import Stickers.System as System
import Stickers.Storage as App

Window {
    id: settingsWindow
    width: 480
    height: 620
    title: "Configuración"

    property var appRoot: null

    // Local, editable copies of the settings this window reads/writes --
    // Settings.get() returns the live SettingsManager.js object by
    // reference, but QML property bindings need an actual property to bind
    // controls to and to trigger re-renders (e.g. the font preference
    // Repeater) when a value changes via a button handler rather than a
    // direct user edit.
    property var appearance: Settings.get().appearance
    property var behavior: Settings.get().behavior
    property var desktops: Settings.get().desktops

    function setAppearance(key, value) {
        appearance[key] = value
        Settings.update("appearance", key, value)
        appearanceChanged()
    }

    function setBehavior(key, value) {
        behavior[key] = value
        Settings.update("behavior", key, value)
        behaviorChanged()
    }

    function setDesktops(key, value) {
        desktops[key] = value
        Settings.update("desktops", key, value)
        desktopsChanged()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: tabBar
            Layout.fillWidth: true

            TabButton { text: "Apariencia" }
            TabButton { text: "Comportamiento" }
            TabButton { text: "Sistema" }
        }

        StackLayout {
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            // -- Apariencia --------------------------------------------------
            ScrollView {
                clip: true

                ColumnLayout {
                    width: settingsWindow.width - 24
                    spacing: 8

                    Label { text: "Color de los stickers nuevos" }

                    // checked is set ONCE at creation (not a live binding):
                    // auto-exclusive RadioButtons own `checked` imperatively
                    // among themselves, and a live "checked: appearance.x
                    // === ..." binding on every sibling fights that
                    // ownership -- each toggle re-asserts its own binding
                    // right after the group clears it, which QML reports as
                    // a binding loop. Settings.appearance only ever changes
                    // through this same UI while the window is open, so a
                    // one-time initial value is correct.
                    RadioButton {
                        text: "Aleatorio"
                        Component.onCompleted: checked = appearance.defaultColorMode === "random"
                        onCheckedChanged: if (checked) setAppearance("defaultColorMode", "random")
                    }
                    RadioButton {
                        text: "Acento del sistema"
                        Component.onCompleted: checked = appearance.defaultColorMode === "accent"
                        onCheckedChanged: if (checked) setAppearance("defaultColorMode", "accent")
                    }
                    RadioButton {
                        id: fixedColorRadio
                        text: "Color fijo"
                        Component.onCompleted: checked = appearance.defaultColorMode === "fixed"
                        onCheckedChanged: if (checked) setAppearance("defaultColorMode", "fixed")
                    }

                    ColorPalette {
                        visible: fixedColorRadio.checked
                        Layout.leftMargin: 24
                        onColorSelected: function(selectedColor) {
                            setAppearance("defaultFixedColor", selectedColor.toString())
                        }
                    }

                    Item { Layout.preferredHeight: 8 }

                    Label { text: "Fuentes preferidas (por orden; se usa la primera instalada)" }

                    Repeater {
                        id: fontPrefsRepeater
                        model: appearance.fontFamilyPreferences

                        delegate: RowLayout {
                            Layout.fillWidth: true
                            required property string modelData
                            required property int index

                            Text {
                                text: (index + 1) + "."
                                Layout.preferredWidth: 18
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: modelData
                                onEditingFinished: {
                                    var prefs = appearance.fontFamilyPreferences.slice()
                                    prefs[index] = text
                                    setAppearance("fontFamilyPreferences", prefs)
                                }
                            }
                            Button {
                                text: "↑"
                                enabled: index > 0
                                onClicked: {
                                    var prefs = appearance.fontFamilyPreferences.slice()
                                    var tmp = prefs[index - 1]
                                    prefs[index - 1] = prefs[index]
                                    prefs[index] = tmp
                                    setAppearance("fontFamilyPreferences", prefs)
                                }
                            }
                            Button {
                                text: "↓"
                                enabled: index < appearance.fontFamilyPreferences.length - 1
                                onClicked: {
                                    var prefs = appearance.fontFamilyPreferences.slice()
                                    var tmp = prefs[index + 1]
                                    prefs[index + 1] = prefs[index]
                                    prefs[index] = tmp
                                    setAppearance("fontFamilyPreferences", prefs)
                                }
                            }
                            Button {
                                text: "✕"
                                onClicked: {
                                    var prefs = appearance.fontFamilyPreferences.slice()
                                    prefs.splice(index, 1)
                                    setAppearance("fontFamilyPreferences", prefs)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            id: newFontField
                            Layout.fillWidth: true
                            placeholderText: "Nueva familia de fuente…"
                        }
                        Button {
                            text: "Añadir"
                            enabled: newFontField.text.trim().length > 0
                            onClicked: {
                                var prefs = appearance.fontFamilyPreferences.slice()
                                prefs.push(newFontField.text.trim())
                                setAppearance("fontFamilyPreferences", prefs)
                                newFontField.text = ""
                            }
                        }
                    }

                    RowLayout {
                        Label { text: "Tamaño de letra por defecto" }
                        SpinBox {
                            from: 6
                            to: 72
                            value: appearance.fontSize
                            onValueModified: setAppearance("fontSize", value)
                        }
                    }
                }
            }

            // -- Comportamiento -----------------------------------------------
            ScrollView {
                clip: true

                ColumnLayout {
                    width: settingsWindow.width - 24
                    spacing: 8

                    CheckBox {
                        text: "Mostrar la barra de herramientas Markdown por defecto"
                        checked: behavior.markdownToolbarVisibleByDefault
                        onToggled: setBehavior("markdownToolbarVisibleByDefault", checked)
                    }
                    CheckBox {
                        text: "Preguntar antes de eliminar un sticker"
                        checked: behavior.askBeforeDeleting
                        onToggled: setBehavior("askBeforeDeleting", checked)
                    }
                    CheckBox {
                        text: "Fijar los stickers nuevos en todos los escritorios"
                        checked: desktops.pinNewStickersByDefault
                        onToggled: setDesktops("pinNewStickersByDefault", checked)
                    }

                    Label { text: "Click izquierdo en el icono de la bandeja" }
                    RadioButton {
                        text: "Abrir Panel de Stickers"
                        Component.onCompleted: checked = behavior.trayLeftClickAction === "openPanel"
                        onCheckedChanged: if (checked) setBehavior("trayLeftClickAction", "openPanel")
                    }
                    RadioButton {
                        text: "Crear nota nueva"
                        Component.onCompleted: checked = behavior.trayLeftClickAction === "newSticker"
                        onCheckedChanged: if (checked) setBehavior("trayLeftClickAction", "newSticker")
                    }
                }
            }

            // -- Sistema --------------------------------------------------------
            ScrollView {
                clip: true

                ColumnLayout {
                    width: settingsWindow.width - 24
                    spacing: 8

                    CheckBox {
                        id: autostartCheck
                        text: "Iniciar Desktop Stickers con la sesión"
                        // The autostart file on disk is the source of truth
                        // (it can change outside this app -- e.g. a user
                        // deleting it by hand), not settings.json's cached
                        // copy, so the initial state reads straight from
                        // SystemIntegration rather than from `behavior`.
                        checked: System.SystemIntegration.isAutostartEnabled()
                        onToggled: {
                            var ok = System.SystemIntegration.setAutostartEnabled(checked)
                            if (ok) {
                                Settings.update("system", "autostartEnabled", checked)
                            } else {
                                checked = System.SystemIntegration.isAutostartEnabled()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Datos: " + App.FileStorage.stickersDir()
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        Button {
                            text: "Abrir carpeta"
                            onClicked: Qt.openUrlExternally("file://" + App.FileStorage.stickersDir())
                        }
                    }
                }
            }
        }
    }
}
