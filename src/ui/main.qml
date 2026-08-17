import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtGraphicalEffects

Window {
    id: mainWindow
    
    width: 300
    height: 250
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WA_TranslucentBackground
    
    // Propiedades del sticker
    property string stickerId: "001"
    property string stickerText: "Nuevo sticker..."
    property string stickerColor: "#FFD700"
    property int posX: 100
    property int posY: 100
    
    x: posX
    y: posY
    
    Rectangle {
        id: stickerContainer
        anchors.fill: parent
        color: stickerColor
        radius: 8
        
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 2
            verticalOffset: 2
            radius: 8.0
            samples: 16
            color: "#000000"
            opacity: 0.2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            
            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                color: Qt.darker(stickerColor, 1.3)
                radius: 8
                
                MouseArea {
                    anchors.fill: parent
                    drag.target: mainWindow
                    drag.axis: Drag.XAndYAxis
                    
                    onReleased: {
                        // Aquí guardamos posición
                        console.log("Sticker movido a:", mainWindow.x, mainWindow.y)
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 8
                    
                    Text {
                        text: "#" + stickerId
                        color: "#333"
                        font.bold: true
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }
                    
                    Button {
                        text: "🎨"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        
                        onClicked: colorPopup.open()
                    }
                    
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        
                        onClicked: mainWindow.close()
                    }
                }
            }
            
            // Content area
            TextEdit {
                id: textArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                topPadding: 8
                leftPadding: 8
                rightPadding: 8
                bottomPadding: 8
                
                text: stickerText
                wrapMode: TextEdit.Wrap
                font.pixelSize: 12
                color: "#333"
                selectByMouse: true
                
                onTextChanged: {
                    stickerText = text
                    autoSaveTimer.restart()
                }
            }
        }
    }
    
    // Auto-save timer
    Timer {
        id: autoSaveTimer
        interval: 500
        onTriggered: {
            console.log("Auto-saving sticker:", stickerId)
            // Aquí se guardará en JSON
        }
    }
    
    // Color picker popup
    Rectangle {
        id: colorPopup
        
        property bool isOpen: false
        
        function open() {
            isOpen = true
            colorContainer.visible = true
        }
        
        function close() {
            isOpen = false
            colorContainer.visible = false
        }
        
        width: 150
        height: 200
        visible: false
        color: "#FFFFFF"
        border.width: 1
        border.color: "#CCC"
        radius: 4
        
        x: mainWindow.x + mainWindow.width - 160
        y: mainWindow.y + mainWindow.height + 5
        z: 1000
        
        Column {
            id: colorContainer
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6
            visible: false
            
            Repeater {
                model: [
                    {name: "Amarillo", hex: "#FFD700"},
                    {name: "Rosa", hex: "#FFB6C1"},
                    {name: "Azul", hex: "#87CEEB"},
                    {name: "Verde", hex: "#98FB98"},
                    {name: "Naranja", hex: "#FFB347"},
                    {name: "Púrpura", hex: "#DDA0DD"},
                    {name: "Blanco", hex: "#FFFFFF"}
                ]
                
                Rectangle {
                    width: parent.width - 16
                    height: 24
                    color: modelData.hex
                    border.width: 1
                    border.color: "#999"
                    radius: 3
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        font.pixelSize: 11
                        color: "#333"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            stickerColor = modelData.hex
                            colorPopup.close()
                            console.log("Color cambiado a:", modelData.hex)
                        }
                    }
                }
            }
        }
    }
}
