import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height

    // ── Colour palette ────────────────────────────────────────────────────────
    readonly property color clrBgDark:    "#080c18"
    readonly property color clrBgMid:     "#101a30"
    readonly property color clrAccentC:   "#57dcb7"
    readonly property color clrAccentP:   "#9b86ff"
    readonly property color clrText:      "#e5e9f0"
    readonly property color clrTextMuted: "#a9b5d1"
    readonly property color clrField:     "#0d1525"
    readonly property color clrBorder:    "#1e2d4a"

    // ── Background ────────────────────────────────────────────────────────────
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: clrBgDark }
        GradientStop { position: 1.0; color: clrBgMid  }
    }

    // Aurora glow — right side, cyan
    Rectangle {
        anchors.right: parent.right
        anchors.top:   parent.top
        width:  parent.width  * 0.55
        height: parent.height * 0.65
        opacity: 0.07
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.clrAccentC }
            GradientStop { position: 1.0; color: "transparent"   }
        }
    }
    // Aurora glow — right, purple
    Rectangle {
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        width:  parent.width  * 0.40
        height: parent.height * 0.50
        opacity: 0.06
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.clrAccentP }
            GradientStop { position: 1.0; color: "transparent"   }
        }
    }

    // ── Background image (SVG) ────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source:       "background.svg"
        fillMode:     Image.PreserveAspectCrop
        smooth:       true
        asynchronous: true
        opacity:      0.6
    }

    // ── Central card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  380
        height: 440
        radius: 12
        color:  Qt.rgba(0.063, 0.098, 0.188, 0.82)   // #101830 semi-transparent

        // Thin cyan border
        border.color: root.clrAccentC
        border.width: 1

        layer.enabled: true

        ColumnLayout {
            anchors {
                fill:    parent
                margins: 36
            }
            spacing: 0

            // ── Logo ──────────────────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text:  "LAZZITE"
                color: root.clrText
                font {
                    family:      "monospace"
                    pixelSize:   36
                    letterSpacing: 6
                    bold:        true
                }
            }

            // Accent underline
            Rectangle {
                Layout.alignment:    Qt.AlignHCenter
                Layout.topMargin:    6
                Layout.bottomMargin: 4
                width:  120
                height: 2
                radius: 1
                color:  root.clrAccentC
            }

            // ── Tagline ───────────────────────────────────────────────────────
            Text {
                Layout.alignment:    Qt.AlignHCenter
                Layout.bottomMargin: 28
                text:  "FAST. CLEAN. YOURS."
                color: root.clrTextMuted
                font {
                    family:      "monospace"
                    pixelSize:   11
                    letterSpacing: 2
                }
            }

            // ── Username field ────────────────────────────────────────────────
            Text {
                text:  "Username"
                color: root.clrTextMuted
                font.pixelSize: 11
                Layout.bottomMargin: 4
            }
            TextField {
                id: userField
                Layout.fillWidth:    true
                Layout.bottomMargin: 16
                text:                userModel.lastUser
                placeholderText:     "Enter username"
                placeholderTextColor: root.clrTextMuted
                color:               root.clrText
                font.pixelSize:      14
                leftPadding:         12
                rightPadding:        12
                topPadding:          10
                bottomPadding:       10
                background: Rectangle {
                    color:        root.clrField
                    radius:       6
                    border.color: userField.activeFocus
                                      ? root.clrAccentC
                                      : root.clrBorder
                    border.width: 1
                }
                KeyNavigation.tab: passField
                Keys.onReturnPressed: passField.forceActiveFocus()
            }

            // ── Password field ────────────────────────────────────────────────
            Text {
                text:  "Password"
                color: root.clrTextMuted
                font.pixelSize: 11
                Layout.bottomMargin: 4
            }
            TextField {
                id: passField
                Layout.fillWidth:    true
                Layout.bottomMargin: 24
                placeholderText:     "Enter password"
                placeholderTextColor: root.clrTextMuted
                color:               root.clrText
                echoMode:            TextInput.Password
                font.pixelSize:      14
                leftPadding:         12
                rightPadding:        12
                topPadding:          10
                bottomPadding:       10
                background: Rectangle {
                    color:        root.clrField
                    radius:       6
                    border.color: passField.activeFocus
                                      ? root.clrAccentC
                                      : root.clrBorder
                    border.width: 1
                }
                KeyNavigation.tab: loginBtn
                Keys.onReturnPressed: loginAction()
            }

            // ── Login button ──────────────────────────────────────────────────
            Button {
                id: loginBtn
                Layout.fillWidth: true
                text: "Sign In"
                font {
                    family:      "monospace"
                    pixelSize:   14
                    letterSpacing: 1
                    bold:        true
                }
                contentItem: Text {
                    text:              loginBtn.text
                    color:             root.clrBgDark
                    font:              loginBtn.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:  loginBtn.pressed
                                ? Qt.darker(root.clrAccentC, 1.15)
                                : loginBtn.hovered
                                    ? Qt.lighter(root.clrAccentC, 1.08)
                                    : root.clrAccentC
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Keys.onReturnPressed: loginAction()
                onClicked:            loginAction()
            }

            // ── Status / error message ────────────────────────────────────────
            Text {
                id: msgText
                Layout.alignment:  Qt.AlignHCenter
                Layout.topMargin:  12
                text:              ""
                color:             "#ff6b6b"
                font.pixelSize:    12
                wrapMode:          Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Session / hostname info (bottom-left) ─────────────────────────────────
    Text {
        anchors {
            bottom:       parent.bottom
            left:         parent.left
            bottomMargin: 20
            leftMargin:   24
        }
        text:  sddm.hostName
        color: root.clrTextMuted
        font {
            family:    "monospace"
            pixelSize: 12
        }
    }

    // ── Clock (bottom-right) ──────────────────────────────────────────────────
    Text {
        id: clock
        anchors {
            bottom:       parent.bottom
            right:        parent.right
            bottomMargin: 20
            rightMargin:  24
        }
        color: root.clrTextMuted
        font {
            family:    "monospace"
            pixelSize: 12
        }
        Timer {
            interval: 1000
            running:  true
            repeat:   true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm  ddd d MMM")
        }
        Component.onCompleted: text = Qt.formatDateTime(new Date(), "hh:mm  ddd d MMM")
    }

    // ── Power buttons (top-right) ─────────────────────────────────────────────
    Row {
        anchors {
            top:         parent.top
            right:       parent.right
            topMargin:   20
            rightMargin: 24
        }
        spacing: 12

        Button {
            text: "⏾"
            font.pixelSize: 18
            contentItem: Text {
                text:  parent.text
                color: root.clrTextMuted
                font:  parent.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
            }
            background: Rectangle { color: "transparent" }
            ToolTip.visible: hovered
            ToolTip.text:    "Suspend"
            onClicked: sddm.suspend()
        }
        Button {
            text: "↺"
            font.pixelSize: 18
            contentItem: Text {
                text:  parent.text
                color: root.clrTextMuted
                font:  parent.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
            }
            background: Rectangle { color: "transparent" }
            ToolTip.visible: hovered
            ToolTip.text:    "Reboot"
            onClicked: sddm.reboot()
        }
        Button {
            text: "⏻"
            font.pixelSize: 18
            contentItem: Text {
                text:  parent.text
                color: root.clrTextMuted
                font:  parent.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
            }
            background: Rectangle { color: "transparent" }
            ToolTip.visible: hovered
            ToolTip.text:    "Power off"
            onClicked: sddm.powerOff()
        }
    }

    // ── Helper: perform login ─────────────────────────────────────────────────
    function loginAction() {
        if (userField.text === "") {
            msgText.text = "Please enter a username."
            userField.forceActiveFocus()
            return
        }
        msgText.text = ""
        sddm.login(userField.text, passField.text, sessionModel.lastIndex)
    }

    // ── SDDM signals ──────────────────────────────────────────────────────────
    Connections {
        target: sddm
        function onLoginFailed() {
            msgText.text  = "Login failed. Please try again."
            passField.text = ""
            passField.forceActiveFocus()
        }
    }

    // ── Initial focus ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        if (userField.text !== "")
            passField.forceActiveFocus()
        else
            userField.forceActiveFocus()
    }
}
