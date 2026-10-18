pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "."

AppDialog {
    id: root
    title: qsTr("Làm mờ logo")
    subtitle: qsTr("Kéo khung tới logo; chỉnh kích thước bên dưới. Áp dụng khi xuất video.")
    preferredWidth: 680
    maximumWidth: 760
    property real regionX: 76
    property real regionY: 14
    property real regionWidth: 23
    property real regionHeight: 9
    property string videoId: ""
    function openForVideo() {
        const value = AppController.logoBlurSettings
        videoId = AppController.selectedVideoId
        enabledCheck.checked = !!value.enabled
        regionX = value.x === undefined ? 76 : value.x
        regionY = value.y === undefined ? 14 : value.y
        regionWidth = value.width === undefined ? 23 : value.width
        regionHeight = value.height === undefined ? 9 : value.height
        open()
    }
    StudioCheckBox { id: enabledCheck; text: qsTr("Bật làm mờ vùng logo") }
    Image {
        id: frame
        Layout.fillWidth: true
        Layout.preferredHeight: 260
        source: AppController.videoThumbnailSource
        fillMode: Image.PreserveAspectFit
        Item {
            anchors.centerIn: parent
            width: frame.paintedWidth
            height: frame.paintedHeight
            Rectangle {
                x: parent.width * root.regionX / 100
                y: parent.height * root.regionY / 100
                width: parent.width * Math.min(root.regionWidth, 100-root.regionX) / 100
                height: parent.height * Math.min(root.regionHeight, 100-root.regionY) / 100
                color: "#66ffffff"
                border.color: "#ffb65c"
                border.width: 2
                MouseArea {
                    anchors.fill: parent
                    property real startX
                    property real startY
                    property real initialX
                    property real initialY
                    onPressed: mouse => {
                        const p = mapToItem(frame, mouse.x, mouse.y)
                        startX=p.x; startY=p.y
                        initialX=root.regionX; initialY=root.regionY
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        const p=mapToItem(frame, mouse.x, mouse.y)
                        root.regionX=Math.max(0,Math.min(100-root.regionWidth,initialX+(p.x-startX)/frame.paintedWidth*100))
                        root.regionY=Math.max(0,Math.min(100-root.regionHeight,initialY+(p.y-startY)/frame.paintedHeight*100))
                    }
                }
            }
        }
    }
    Repeater {
        model: [qsTr("Trái"),qsTr("Trên"),qsTr("Rộng"),qsTr("Cao")]
        RowLayout {
            id: regionRow
            required property int index
            required property string modelData
            Layout.fillWidth: true
            Text { text: regionRow.modelData; color: Theme.text; Layout.preferredWidth: 50 }
            Slider {
                Layout.fillWidth: true
                from: regionRow.index < 2 ? 0 : 1
                to: regionRow.index===0 ? 100-root.regionWidth : regionRow.index===1 ? 100-root.regionHeight : regionRow.index===2 ? 100-root.regionX : 100-root.regionY
                value: regionRow.index===0 ? root.regionX : regionRow.index===1 ? root.regionY : regionRow.index===2 ? root.regionWidth : root.regionHeight
                onMoved: {
                    if(regionRow.index===0)root.regionX=value
                    else if(regionRow.index===1)root.regionY=value
                    else if(regionRow.index===2)root.regionWidth=value
                    else root.regionHeight=value
                }
            }
            Text {
                text: Math.round(regionRow.index===0 ? root.regionX : regionRow.index===1 ? root.regionY : regionRow.index===2 ? root.regionWidth : root.regionHeight)+"%"
                color: Theme.text
                Layout.preferredWidth: 40
            }
        }
    }
    footerActions: [
        StudioButton { text: qsTr("Hủy"); onClicked: root.close() },
        StudioButton {
            text: qsTr("Lưu")
            variant: "primary"
            onClicked: {
                if(root.videoId===AppController.selectedVideoId)
                    AppController.saveLogoBlur(enabledCheck.checked,root.regionX,root.regionY,root.regionWidth,root.regionHeight)
                root.close()
            }
        }
    ]
}
