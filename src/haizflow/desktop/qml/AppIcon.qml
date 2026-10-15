import QtQuick
import "."

Text {
    id: root

    property string glyph: ""
    property color iconColor: Theme.textMuted
    property int iconSize: Theme.icon
    readonly property bool useFluentFont: Qt.platform.os === "windows"

    text: useFluentFont ? glyph : IconCatalog.portableGlyph(glyph)
    color: iconColor
    font.family: useFluentFont ? Theme.iconFont : "Noto Sans Symbols 2"
    font.pixelSize: iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    Accessible.ignored: true
}
