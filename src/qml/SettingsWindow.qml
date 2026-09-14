import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.platform as Platform
import StickersApp
import "SettingsManager.js" as Settings
import "StickerManager.js" as Manager
import Stickers.System as System
import Stickers.Storage as App

Window {
    id: settingsWindow
    width: 480
    minimumWidth: 420
    // Sized to content instead of a fixed height -- capped to 85% of the
    // screen so a long font-preference list still scrolls (via the
    // ScrollView below) rather than growing the window off-screen.
    height: Math.min(mainColumn.implicitHeight + footerRow.implicitHeight + 96,
                      (Screen.height || 1000) * 0.85)
    minimumHeight: 320
    title: I18n.t("Settings.title")

    property var appRoot: null

    // Local, editable copies of the settings this window reads/writes --
    // Settings.get() returns the live SettingsManager.js object by
    // reference, but QML property bindings need an actual property to bind
    // controls to and to trigger re-renders when a value changes via a
    // button handler rather than a direct user edit.
    property var appearance: Settings.get().appearance
    property var behavior: Settings.get().behavior
    property var desktops: Settings.get().desktops

    SystemPalette { id: pal }
    // Live binding to the system accent color, same approach as Main.qml's
    // sysPalette -- used for the "Acento del sistema" preview swatch.
    SystemPalette { id: accentPal; colorGroup: SystemPalette.Active }

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

    function previewColor() {
        if (appearance.defaultColorMode === "fixed") return appearance.defaultFixedColor
        if (appearance.defaultColorMode === "accent") return accentPal.highlight
        return Manager.RANDOM_COLORS[0]
    }

    // -- Font preference list: backed by a ListModel purely for the
    // draggable/reorderable ListView UI below; persistence stays a plain
    // string array (appearance.fontFamilyPreferences), synced both ways.
    ListModel { id: fontPrefsModel }

    function syncFontPrefsModel() {
        fontPrefsModel.clear()
        var prefs = appearance.fontFamilyPreferences
        for (var i = 0; i < prefs.length; i++) {
            fontPrefsModel.append({ family: prefs[i] })
        }
    }

    function persistFontPrefsFromModel() {
        var prefs = []
        for (var i = 0; i < fontPrefsModel.count; i++) {
            prefs.push(fontPrefsModel.get(i).family)
        }
        setAppearance("fontFamilyPreferences", prefs)
    }

    onAppearanceChanged: syncFontPrefsModel()
    Component.onCompleted: syncFontPrefsModel()

    property var allFontFamilies: System.SystemIntegration.installedFontFamilies()
    property var filteredFontFamilies: allFontFamilies

    function filterFonts(query) {
        if (!query) {
            filteredFontFamilies = allFontFamilies
            return
        }
        var q = query.toLowerCase()
        filteredFontFamilies = allFontFamilies.filter(function(f) {
            return f.toLowerCase().indexOf(q) !== -1
        })
    }

    function addFontFromCombo() {
        var name = addFontCombo.editText.trim()
        if (!name) return
        var prefs = appearance.fontFamilyPreferences.slice()
        prefs.push(name)
        setAppearance("fontFamilyPreferences", prefs)
        addFontCombo.editText = ""
        filterFonts("")
    }

    function resetSettings() {
        var defaults = Settings.resetToDefaults()
        appearance = defaults.appearance
        behavior = defaults.behavior
        desktops = defaults.desktops
        System.SystemIntegration.setAutostartEnabled(defaults.system.autostartEnabled)
        autostartCheck.checked = System.SystemIntegration.isAutostartEnabled()
    }

    // Standard dependency-free QML clipboard-copy trick: an offscreen
    // TextEdit, select-all + copy. Qt.labs.platform has no Clipboard type.
    TextEdit {
        id: clipboardHelper
        visible: false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 16

            ScrollView {
                id: scrollArea
                anchors.fill: parent
                clip: true
                // Basic style's scrollbar is a transient overlay that
                // floats ON TOP of content rather than reserving its own
                // lane -- it was covering the right edge of every row's
                // controls. AlwaysOn keeps it visibly present (matching
                // normal desktop scrollbar behavior) and, combined with
                // reserving space in mainColumn's width below, gives it a
                // real gutter instead of overlapping.
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                // ScrollView wraps its content in a Flickable whose
                // contentWidth is normally derived FROM the child's own
                // implicit width -- binding mainColumn's width to
                // `parent.width` (the Flickable) is circular and resolves
                // to mainColumn's shrink-to-fit width instead of the
                // viewport's, so every row's label column collapses to a
                // sliver and wide rows (e.g. the color segmented control)
                // get silently pushed off into unreachable horizontal
                // scroll instead of wrapping/fitting. Binding to
                // contentArea's width (computed by the OUTER Layout,
                // outside this ScrollView/Flickable) breaks the cycle.
                ColumnLayout {
                    id: mainColumn
                    // Reserve a fixed gutter for the scrollbar (its own
                    // implicit width varies slightly by style/theme, but a
                    // real OS scrollbar lane is consistently in this
                    // ballpark) so it sits beside the controls, not on top
                    // of them.
                    width: contentArea.width - 16
                    spacing: 24

                    // ---------------------------------------------------- Apariencia
                    SettingsSection {
                        title: I18n.t("Settings.appearance.title")

                        // A label-above / controls-below block rather than
                        // a SettingsRow (label-left / control-right):
                        // the segmented trio plus swatch+hex+button cluster
                        // is too wide to share a line with a full-sentence
                        // label at this window width, so it gets a Flow
                        // (wraps to a second line if it still doesn't fit,
                        // instead of silently overflowing off-screen).
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: colorBlock.implicitHeight + 20

                            ColumnLayout {
                                id: colorBlock
                                x: 12
                                y: 10
                                width: parent.width - 24
                                spacing: 8

                                Label { text: I18n.t("Settings.appearance.colorLabel") }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Row {
                                        spacing: 0
                                        Button {
                                            text: I18n.t("Settings.appearance.colorRandom")
                                            checkable: true
                                            autoExclusive: true
                                            Component.onCompleted: checked = appearance.defaultColorMode === "random"
                                            onCheckedChanged: if (checked) setAppearance("defaultColorMode", "random")
                                        }
                                        Button {
                                            text: I18n.t("Settings.appearance.colorAccent")
                                            checkable: true
                                            autoExclusive: true
                                            Component.onCompleted: checked = appearance.defaultColorMode === "accent"
                                            onCheckedChanged: if (checked) setAppearance("defaultColorMode", "accent")
                                        }
                                        Button {
                                            id: fixedColorButton
                                            text: I18n.t("Settings.appearance.colorFixed")
                                            checkable: true
                                            autoExclusive: true
                                            Component.onCompleted: checked = appearance.defaultColorMode === "fixed"
                                            onCheckedChanged: if (checked) setAppearance("defaultColorMode", "fixed")
                                        }
                                    }

                                    Row {
                                        spacing: 6
                                        Rectangle {
                                            width: 18; height: 18; radius: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: appearance.defaultFixedColor
                                            border.width: 1
                                            border.color: pal.mid
                                            opacity: fixedColorButton.checked ? 1.0 : 0.4
                                        }
                                        Label {
                                            text: appearance.defaultFixedColor
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.family: "monospace"
                                            opacity: fixedColorButton.checked ? 1.0 : 0.4
                                        }
                                        Button {
                                            text: I18n.t("Settings.appearance.chooseColor")
                                            enabled: fixedColorButton.checked
                                            onClicked: colorPopup.open()
                                            Accessible.name: I18n.t("Settings.appearance.chooseColorTooltip")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 12
                                height: 1
                                color: pal.mid
                            }
                        }

                        Item {
                            // Sub-heading for the typography group -- kept
                            // as its own labeled block (not a SettingsRow,
                            // it isn't a single-line label+control row)
                            // inside the same bordered container as the
                            // color row above.
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            implicitHeight: fontGroupHeader.implicitHeight + 12

                            ColumnLayout {
                                id: fontGroupHeader
                                x: 12
                                y: 8
                                width: parent.width - 24
                                spacing: 6
                                Label {
                                    text: I18n.t("Settings.appearance.fontsTitle")
                                    font.bold: true
                                    font.pixelSize: 13
                                }
                                Label {
                                    text: I18n.t("Settings.appearance.fontsSubtitle")
                                    font.pixelSize: 11
                                    opacity: 0.65
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ListView {
                            id: fontListView
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            implicitHeight: contentHeight
                            interactive: false
                            model: fontPrefsModel
                            spacing: 0

                            delegate: FocusScope {
                                id: fontRowScope
                                required property string family
                                required property int index
                                width: fontListView.width
                                height: 36
                                activeFocusOnTab: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: dragHandler.active ? pal.alternateBase : "transparent"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Label {
                                        text: "⠿"
                                        font.pixelSize: 16
                                        opacity: 0.5
                                        Accessible.name: I18n.tf("Settings.appearance.dragHandle", [fontRowScope.family])

                                        DragHandler {
                                            id: dragHandler
                                            target: null
                                            onTranslationChanged: {
                                                if (!active) return
                                                var newY = fontRowScope.y + translation.y
                                                var targetIndex = Math.round(newY / fontRowScope.height)
                                                targetIndex = Math.max(0, Math.min(fontListView.count - 1, targetIndex))
                                                if (targetIndex !== fontRowScope.index) {
                                                    fontPrefsModel.move(fontRowScope.index, targetIndex, 1)
                                                    persistFontPrefsFromModel()
                                                }
                                            }
                                        }
                                    }

                                    Label {
                                        text: fontRowScope.family
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        visible: !System.SystemIntegration.isFontFamilyInstalled(fontRowScope.family)
                                        text: "⚠"
                                        opacity: 0.8
                                        Accessible.name: I18n.tf("Settings.appearance.notInstalled", [fontRowScope.family])

                                        ToolTip.visible: warnHover.hovered
                                        ToolTip.text: I18n.tf("Settings.appearance.notInstalled", [fontRowScope.family])
                                        HoverHandler { id: warnHover }
                                    }

                                    Button {
                                        text: "↑"
                                        visible: fontRowScope.activeFocus
                                        implicitWidth: 26; implicitHeight: 26
                                        enabled: fontRowScope.index > 0
                                        onClicked: {
                                            fontPrefsModel.move(fontRowScope.index, fontRowScope.index - 1, 1)
                                            persistFontPrefsFromModel()
                                        }
                                        Accessible.name: I18n.tf("Settings.appearance.moveUp", [fontRowScope.family])
                                    }
                                    Button {
                                        text: "↓"
                                        visible: fontRowScope.activeFocus
                                        implicitWidth: 26; implicitHeight: 26
                                        enabled: fontRowScope.index < fontListView.count - 1
                                        onClicked: {
                                            fontPrefsModel.move(fontRowScope.index, fontRowScope.index + 1, 1)
                                            persistFontPrefsFromModel()
                                        }
                                        Accessible.name: I18n.tf("Settings.appearance.moveDown", [fontRowScope.family])
                                    }
                                    Button {
                                        icon.name: "list-remove"
                                        text: "✕"
                                        display: AbstractButton.IconOnly
                                        flat: true
                                        implicitWidth: 28; implicitHeight: 28
                                        onClicked: {
                                            fontPrefsModel.remove(fontRowScope.index)
                                            persistFontPrefsFromModel()
                                        }
                                        Accessible.name: I18n.tf("Settings.appearance.removeFont", [fontRowScope.family])
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: addFontRow.implicitHeight + 16

                            RowLayout {
                                id: addFontRow
                                x: 12
                                y: 8
                                width: parent.width - 24
                                spacing: 8

                                ComboBox {
                                    id: addFontCombo
                                    Layout.fillWidth: true
                                    editable: true
                                    model: filteredFontFamilies
                                    Accessible.name: I18n.t("Settings.appearance.searchFont")
                                    // Qt.callLater, not a direct call: reassigning
                                    // filteredFontFamilies (this ComboBox's own
                                    // model) synchronously from within its own
                                    // editTextChanged handler is exactly the
                                    // pattern QML's binding-loop detector flags --
                                    // the model swap can itself nudge editText,
                                    // re-entering this handler in the same tick.
                                    // Deferring to the next event-loop turn breaks
                                    // that synchronous cycle.
                                    onEditTextChanged: Qt.callLater(filterFonts, editText)
                                    Keys.onReturnPressed: addFontFromCombo()
                                }
                                Button {
                                    text: I18n.t("Settings.appearance.addFont")
                                    enabled: addFontCombo.editText.trim().length > 0
                                    onClicked: addFontFromCombo()
                                }
                            }
                        }

                        SettingsRow {
                            label: I18n.t("Settings.appearance.fontSizeLabel")
                            separator: false
                            SpinBox {
                                from: 6
                                to: 72
                                value: appearance.fontSize
                                onValueModified: setAppearance("fontSize", value)
                            }
                        }
                    }

                    // Live preview -- outside the bordered rows container,
                    // still part of the Apariencia section visually.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -8
                        spacing: 6

                        Label {
                            text: I18n.t("Settings.appearance.previewLabel")
                            font.pixelSize: 11
                            opacity: 0.65
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 180
                            height: 80
                            radius: 8
                            color: previewColor()

                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                text: I18n.t("Settings.appearance.previewLabel")
                                wrapMode: Text.Wrap
                                color: "#222"
                                font.family: System.SystemIntegration.resolveFontFamily(appearance.fontFamilyPreferences, "Sans Serif")
                                font.pixelSize: appearance.fontSize
                            }
                        }
                    }

                    // ------------------------------------------------- Comportamiento
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        SettingsSection {
                            title: I18n.t("Settings.behavior.title")

                            SettingsRow {
                                label: I18n.t("Settings.behavior.markdownToolbar")
                                subtitle: I18n.t("Settings.behavior.markdownToolbarSubtitle")
                                Switch {
                                    checked: behavior.markdownToolbarVisibleByDefault
                                    onToggled: setBehavior("markdownToolbarVisibleByDefault", checked)
                                }
                            }
                            SettingsRow {
                                label: I18n.t("Settings.behavior.askBeforeDeleting")
                                Switch {
                                    checked: behavior.askBeforeDeleting
                                    onToggled: setBehavior("askBeforeDeleting", checked)
                                }
                            }
                            SettingsRow {
                                label: I18n.t("Settings.behavior.pinNewStickers")
                                subtitle: I18n.t("Settings.behavior.pinNewStickersSubtitle")
                                separator: false
                                Switch {
                                    checked: desktops.pinNewStickersByDefault
                                    onToggled: setDesktops("pinNewStickersByDefault", checked)
                                }
                            }
                        }

                        // Visually separate: clicking the tray icon is a
                        // different kind of setting from the toggles above.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: trayRow.implicitHeight
                            radius: 8
                            color: "transparent"
                            border.width: 1
                            border.color: pal.mid

                            SettingsRow {
                                id: trayRow
                                width: parent.width
                                label: I18n.t("Settings.behavior.trayClickLabel")
                                separator: false

                                ComboBox {
                                    id: trayClickCombo
                                    Layout.preferredWidth: 190
                                    // Matches the tray menu's own item names
                                    // ("Panel de Stickers", "Nuevo sticker")
                                    // instead of introducing "nota" as a second
                                    // word for the same concept -- reuses
                                    // Main.trayMenu.newSticker verbatim since
                                    // that one really is the identical string.
                                    model: [I18n.t("Settings.behavior.trayClickOpenPanel"), I18n.t("Main.trayMenu.newSticker")]
                                    Component.onCompleted: currentIndex = behavior.trayLeftClickAction === "newSticker" ? 1 : 0
                                    onActivated: setBehavior("trayLeftClickAction", currentIndex === 1 ? "newSticker" : "openPanel")
                                }
                            }
                        }
                    }

                    // ------------------------------------------------------- Sistema
                    SettingsSection {
                        title: I18n.t("Settings.system.title")

                        SettingsRow {
                            label: I18n.t("Settings.system.autostart")
                            subtitle: I18n.t("Settings.system.autostartSubtitle")
                            Switch {
                                id: autostartCheck
                                // The autostart file on disk is the source
                                // of truth (it can change outside this app),
                                // not settings.json's cached copy, so the
                                // initial state reads straight from
                                // SystemIntegration.
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
                        }

                        SettingsRow {
                            label: I18n.t("Settings.system.dataFolder")

                            Label {
                                text: App.FileStorage.dataDir()
                                font.family: "monospace"
                                elide: Text.ElideMiddle
                                Layout.preferredWidth: 150

                                ToolTip.visible: dataPathHover.hovered
                                ToolTip.text: App.FileStorage.dataDir()
                                HoverHandler { id: dataPathHover }
                            }
                            Button {
                                icon.name: "edit-copy"
                                text: "⧉"
                                display: AbstractButton.IconOnly
                                flat: true
                                implicitWidth: 30; implicitHeight: 30
                                onClicked: {
                                    clipboardHelper.text = App.FileStorage.dataDir()
                                    clipboardHelper.selectAll()
                                    clipboardHelper.copy()
                                }
                                Accessible.name: I18n.t("Settings.system.copyPath")
                            }
                            Button {
                                text: I18n.t("Settings.system.openFolder")
                                onClicked: Qt.openUrlExternally("file://" + App.FileStorage.dataDir())
                                Accessible.name: I18n.t("Settings.system.openFolderTooltip")
                            }
                        }

                        SettingsRow {
                            label: I18n.t("Settings.system.backup")
                            separator: false

                            Button {
                                text: I18n.t("Settings.system.export")
                                onClicked: exportFolderDialog.open()
                                Accessible.name: I18n.t("Settings.system.exportTooltip")
                            }
                            Button {
                                text: I18n.t("Settings.system.import")
                                onClicked: importFolderDialog.open()
                                Accessible.name: I18n.t("Settings.system.importTooltip")
                            }
                        }
                    }

                    // -------------------------------------------------------- Idiomas
                    SettingsSection {
                        title: I18n.t("Settings.language.title")

                        SettingsRow {
                            label: I18n.t("Settings.language.label")
                            separator: false

                            ComboBox {
                                id: languageCombo
                                Layout.preferredWidth: 180
                                model: I18n.availableLanguages.map(function(l) {
                                    return { code: l.code, text: l.strings["Language.flag"] + "  " + l.strings["Language.name"] }
                                })
                                textRole: "text"
                                Component.onCompleted: {
                                    for (var i = 0; i < model.length; i++) {
                                        if (model[i].code === I18n.languageCode) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }
                                onActivated: I18n.setLanguage(model[currentIndex].code)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: pal.mid
        }

        RowLayout {
            id: footerRow
            Layout.fillWidth: true
            Layout.margins: 12

            Label {
                text: I18n.t("Main.tray.tooltip") + " " + Qt.application.version
                opacity: 0.6
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Button {
                text: I18n.t("Settings.footer.reset")
                flat: true
                palette.buttonText: "#e74c3c"
                onClicked: resetConfirmDialog.open()
                Accessible.name: I18n.t("Settings.footer.resetTooltip")
            }
        }
    }

    Popup {
        id: colorPopup
        x: (settingsWindow.width - width) / 2
        y: 80
        padding: 8

        ColorPalette {
            onColorSelected: function(selectedColor) {
                setAppearance("defaultFixedColor", selectedColor.toString())
                colorPopup.close()
            }
        }
    }

    Platform.MessageDialog {
        id: resetConfirmDialog
        text: I18n.t("Settings.resetConfirm.text")
        buttons: Platform.MessageDialog.Yes | Platform.MessageDialog.No
        onYesClicked: resetSettings()
    }

    Platform.MessageDialog {
        id: resultDialog
    }

    Platform.FolderDialog {
        id: exportFolderDialog
        title: I18n.t("Settings.exportDialog.title")
        onAccepted: {
            // stickers.json and settings.json now live in two separate XDG
            // directories (dataDir/configDir) -- the backup folder still
            // holds both flat, side by side, for simplicity.
            var destDir = App.FileStorage.toLocalFile(folder)
            var ok = true
            ok = App.FileStorage.writeFile(destDir + "/stickers.json", App.FileStorage.readFile(App.FileStorage.dataDir() + "/stickers.json")) && ok
            ok = App.FileStorage.writeFile(destDir + "/settings.json", App.FileStorage.readFile(App.FileStorage.configDir() + "/settings.json")) && ok
            resultDialog.text = ok ? I18n.tf("Settings.exportDialog.success", [destDir])
                                    : I18n.t("Settings.exportDialog.failure")
            resultDialog.open()
        }
    }

    Platform.FolderDialog {
        id: importFolderDialog
        title: I18n.t("Settings.importDialog.title")
        onAccepted: {
            importConfirmDialog.pendingDir = App.FileStorage.toLocalFile(folder)
            importConfirmDialog.open()
        }
    }

    Platform.MessageDialog {
        id: importConfirmDialog
        property string pendingDir: ""
        text: I18n.t("Settings.importDialog.confirm")
        buttons: Platform.MessageDialog.Yes | Platform.MessageDialog.No
        onYesClicked: {
            var srcStickers = App.FileStorage.readFile(pendingDir + "/stickers.json")
            var srcSettings = App.FileStorage.readFile(pendingDir + "/settings.json")
            var ok = true
            if (srcStickers.length > 0) ok = App.FileStorage.writeFile(App.FileStorage.dataDir() + "/stickers.json", srcStickers) && ok
            if (srcSettings.length > 0) ok = App.FileStorage.writeFile(App.FileStorage.configDir() + "/settings.json", srcSettings) && ok
            resultDialog.text = ok ? I18n.t("Settings.importDialog.success")
                                    : I18n.t("Settings.importDialog.failure")
            resultDialog.open()
        }
    }
}
