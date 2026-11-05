#!/usr/bin/python3

import shutil
import sys

from PyQt6.QtCore import QProcess, QSettings, Qt
from PyQt6.QtGui import QFont, QIcon
from PyQt6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


class WelcomeWindow(QMainWindow):
    def __init__(self, settings):
        super().__init__()
        self.settings = settings
        self.setWindowTitle("Welcome to LAZZITE")
        self.setWindowIcon(QIcon("/usr/share/icons/hicolor/scalable/apps/lazzite.svg"))
        self.resize(760, 560)
        self.setMinimumSize(640, 480)
        self.setStyleSheet(
            """
            QWidget {
                background: #080c18;
                color: #e5e9f0;
                font-family: "Noto Sans", sans-serif;
                font-size: 14px;
            }
            QLabel#tagline { color: #57dcb7; letter-spacing: 3px; }
            QLabel#muted { color: #a9b5d1; }
            QFrame#card {
                background: #101a30;
                border: 1px solid #263653;
                border-radius: 12px;
            }
            QPushButton {
                background: #182644;
                border: 1px solid #314766;
                border-radius: 8px;
                padding: 11px 16px;
                text-align: left;
            }
            QPushButton:hover {
                border-color: #57dcb7;
                background: #1d304d;
            }
            QPushButton#primary {
                background: #57dcb7;
                border-color: #57dcb7;
                color: #080c18;
                font-weight: bold;
            }
            QPushButton#primary:hover { background: #75e8c8; }
            QCheckBox { color: #a9b5d1; }
            QCheckBox::indicator { width: 16px; height: 16px; }
            """
        )

        central = QWidget()
        layout = QVBoxLayout(central)
        layout.setContentsMargins(40, 32, 40, 28)
        layout.setSpacing(16)

        title = QLabel("LAZZITE")
        title.setFont(QFont("Noto Sans", 30, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        tagline = QLabel("FAST. CLEAN. YOURS.")
        tagline.setObjectName("tagline")
        tagline.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(tagline)

        subtitle = QLabel("Debian 13 Trixie | KDE Plasma")
        subtitle.setObjectName("muted")
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(subtitle)

        card = QFrame()
        card.setObjectName("card")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(22, 18, 22, 18)
        card_layout.setSpacing(10)

        install = QPushButton("Install LAZZITE on this computer")
        install.setObjectName("primary")
        install.clicked.connect(lambda _checked=False: self._launch("calamares-install-debian"))
        card_layout.addWidget(install)

        browse = QPushButton("Browse the web")
        browse.clicked.connect(lambda _checked=False: self._launch("firefox-esr"))
        card_layout.addWidget(browse)

        apps = QPushButton("Find and install applications")
        apps.clicked.connect(lambda _checked=False: self._launch("plasma-discover"))
        card_layout.addWidget(apps)

        settings_button = QPushButton("Open system settings")
        settings_button.clicked.connect(lambda _checked=False: self._launch("systemsettings"))
        card_layout.addWidget(settings_button)
        layout.addWidget(card)

        note = QLabel(
            "LAZZITE is a beta preview. Installation and Windows dual-boot "
            "have not yet been validated on physical hardware."
        )
        note.setObjectName("muted")
        note.setWordWrap(True)
        note.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(note)

        footer = QHBoxLayout()
        self.show_on_login = QCheckBox("Show this screen when I log in")
        self.show_on_login.setChecked(self.settings.value("showOnLogin", True, bool))
        self.show_on_login.toggled.connect(self._set_show_on_login)
        footer.addWidget(self.show_on_login)
        footer.addStretch()

        close_button = QPushButton("Close")
        close_button.setText("Continue to desktop")
        close_button.clicked.connect(self.close)
        footer.addWidget(close_button)
        layout.addLayout(footer)

        self.setCentralWidget(central)

    def _set_show_on_login(self, enabled):
        self.settings.setValue("showOnLogin", enabled)
        self.settings.sync()

    def _launch(self, command):
        executable = shutil.which(command)
        if executable is None:
            QMessageBox.critical(
                self,
                "Application unavailable",
                f"LAZZITE could not find the required application: {command}",
            )
            return

        started, _process_id = QProcess.startDetached(executable, [])
        if not started:
            QMessageBox.critical(
                self,
                "Could not start application",
                f"LAZZITE could not start: {command}",
            )


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Welcome")
    app.setOrganizationName("LAZZITE OS")
    settings = QSettings("LAZZITE OS", "Welcome")

    if "--first-run" in sys.argv and not settings.value("showOnLogin", True, bool):
        return 0

    window = WelcomeWindow(settings)
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
