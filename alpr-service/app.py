"""Guard-post desktop app: live camera feed with plate detection drawn on
it, the current read, a history of past reads, and whether readings are
actually reaching the API. Replaces the bare cv2.imshow preview windows in
capture.py/detect.py with something a guard can actually read.
"""

from __future__ import annotations

import sys
import time
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import cv2
from PySide6.QtCore import QThread, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QImage, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from api_client import ApiClient, SendResult, login
from capture import Camera
from config import Config, DEFAULT_API_BASE, load_config_or_none, save_config
from plate_reader import CONFIDENCE_THRESHOLD, PlateReader

PH_TIMEZONE = ZoneInfo("Asia/Manila")

HEARTBEAT_INTERVAL_SECONDS = 15
CAMERA_RETRY_INTERVAL_SECONDS = 3
HISTORY_MAX_ROWS = 50
UI_TICK_MS = 1000

# OCR flickers between frames — a single misread character on one frame is
# normal, not a different plate. Require the same exact text this many
# consecutive frames before it's trusted enough to show or send.
CONFIRM_FRAMES = 5

# A read this unsure is closer to noise than to a real plate — treated the
# same as no plate in frame, so it can't even start a confirm streak.
MIN_CONFIDENCE_TO_CONSIDER = 0.5

GREEN = QColor("#2e7d32")
AMBER = QColor("#b26a00")
RED = QColor("#c62828")
GRAY = QColor("#666666")


class CaptureWorker(QThread):
    """Owns the camera, the model, and the network — all off the GUI
    thread, so a stalled camera or a slow API call never freezes the
    window.
    """

    frame_ready = Signal(QImage)
    plate_detected = Signal(str, float)
    send_result = Signal(SendResult)
    history_row = Signal(object, object, object, bool)  # datetime, plate, confidence, ok
    camera_error = Signal(str)
    camera_recovered = Signal()

    def __init__(self, config: Config) -> None:
        super().__init__()
        self._config = config
        self._api = ApiClient(config.api_base, config.api_key)
        self._running = True

        self._last_sent_plate: str | None = None
        self._last_send_attempt_at = 0.0

        self._pending_plate: str | None = None
        self._pending_streak = 0

    def stop(self) -> None:
        self._running = False

    def run(self) -> None:
        reader = PlateReader()

        while self._running:
            camera = self._open_camera()
            if camera is None:
                return  # stop() was called while waiting to reopen

            try:
                self._capture_loop(camera, reader)
            finally:
                camera.release()

    def _open_camera(self) -> Camera | None:
        while self._running:
            camera = Camera(self._config.camera_index, mirrored=self._config.camera_mirrored)
            try:
                camera.open()
                return camera
            except RuntimeError as exc:
                self.camera_error.emit(str(exc))
                self.msleep(CAMERA_RETRY_INTERVAL_SECONDS * 1000)
        return None

    def _capture_loop(self, camera: Camera, reader: PlateReader) -> None:
        was_lost = False

        while self._running:
            frame = camera.read_frame()

            if frame is None:
                if not was_lost:
                    self.camera_error.emit("Lost the camera feed — device disconnected?")
                    was_lost = True
                self.msleep(CAMERA_RETRY_INTERVAL_SECONDS * 1000)
                return  # let run() reopen the camera fresh

            if was_lost:
                self.camera_recovered.emit()
                was_lost = False

            result = reader.read(frame)
            self.frame_ready.emit(self._to_qimage(result.frame))

            plate = result.plate if result.confidence >= MIN_CONFIDENCE_TO_CONSIDER else None
            confirmed_plate = self._confirm(plate)
            if confirmed_plate is not None:
                self.plate_detected.emit(confirmed_plate, result.confidence)

            self._maybe_send(confirmed_plate, result.confidence)

    def _confirm(self, plate: str | None) -> str | None:
        """Only lets a plate through once it's read the same way several
        frames running — a single frame dropping or swapping a character is
        normal OCR flicker, not a different car."""
        if plate is None:
            self._pending_plate = None
            self._pending_streak = 0
            return None

        if plate == self._pending_plate:
            self._pending_streak += 1
        else:
            self._pending_plate = plate
            self._pending_streak = 1

        return plate if self._pending_streak >= CONFIRM_FRAMES else None

    def _maybe_send(self, plate: str | None, confidence: float) -> None:
        now = time.monotonic()

        is_new_plate = plate is not None and plate != self._last_sent_plate
        due_for_heartbeat = now - self._last_send_attempt_at >= HEARTBEAT_INTERVAL_SECONDS

        if not is_new_plate and not due_for_heartbeat:
            return

        to_send = plate if is_new_plate else None
        outcome = self._api.post_reading(to_send, confidence if is_new_plate else None)

        self._last_send_attempt_at = now
        if is_new_plate:
            self._last_sent_plate = plate

        self.send_result.emit(outcome)
        if is_new_plate:
            self.history_row.emit(datetime.now(timezone.utc), plate, confidence, outcome.ok)

    @staticmethod
    def _to_qimage(frame: cv2.typing.MatLike) -> QImage:
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        h, w, channels = rgb.shape
        # .copy() detaches the QImage from this numpy buffer, which cv2
        # reuses for the next frame the instant this loop iterates again.
        return QImage(rgb.data, w, h, channels * w, QImage.Format.Format_RGB888).copy()


class AlprWindow(QMainWindow):
    def __init__(self, config: Config, signed_in_as: str | None = None) -> None:
        super().__init__()
        self._config = config
        self._signed_in_as = signed_in_as
        self._last_send_result: SendResult | None = None
        self._camera_down_since: float | None = None

        self.setWindowTitle(f"AimPark ALPR — {config.gate_label}")
        self.resize(1100, 650)
        self._build_ui()

        self._worker = CaptureWorker(config)
        self._worker.frame_ready.connect(self._on_frame)
        self._worker.plate_detected.connect(self._on_plate_detected)
        self._worker.send_result.connect(self._on_send_result)
        self._worker.history_row.connect(self._on_history_row)
        self._worker.camera_error.connect(self._on_camera_error)
        self._worker.camera_recovered.connect(self._on_camera_recovered)
        self._worker.start()

        self._tick_timer = QTimer(self)
        self._tick_timer.timeout.connect(self._tick)
        self._tick_timer.start(UI_TICK_MS)
        self._tick()  # show the clock immediately instead of a blank line for 1s

    def _build_ui(self) -> None:
        central = QWidget()
        layout = QHBoxLayout(central)

        self._video_label = QLabel("Starting camera…")
        self._video_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._video_label.setMinimumSize(640, 480)
        self._video_label.setStyleSheet("background-color: black; color: white;")
        layout.addWidget(self._video_label, stretch=3)

        sidebar = QVBoxLayout()
        layout.addLayout(sidebar, stretch=2)

        gate_label = QLabel(self._config.gate_label)
        gate_label.setStyleSheet("font-size: 18px; font-weight: bold;")
        sidebar.addWidget(gate_label)

        self._clock_label = QLabel("")
        self._clock_label.setStyleSheet(f"color: {GRAY.name()}; font-size: 12px;")
        sidebar.addWidget(self._clock_label)

        if self._signed_in_as:
            signed_in_label = QLabel(f"Signed in as {self._signed_in_as}")
            signed_in_label.setStyleSheet(f"color: {GRAY.name()}; font-size: 12px;")
            sidebar.addWidget(signed_in_label)

        self._connection_label = QLabel("Connecting…")
        self._connection_label.setStyleSheet(f"color: {GRAY.name()};")
        sidebar.addWidget(self._connection_label)

        self._reading_label = QLabel("No plate read yet")
        self._reading_label.setStyleSheet("font-size: 28px; font-weight: bold; padding: 8px 0;")
        sidebar.addWidget(self._reading_label)

        self._history_table = QTableWidget(0, 4)
        self._history_table.setHorizontalHeaderLabels(["Time", "Plate", "Confidence", "Sent"])
        self._history_table.horizontalHeader().setSectionResizeMode(
            1, QHeaderView.ResizeMode.Stretch
        )
        self._history_table.verticalHeader().setVisible(False)
        self._history_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        sidebar.addWidget(self._history_table, stretch=1)

        self._footer_label = QLabel("")
        self._footer_label.setStyleSheet(f"color: {GRAY.name()};")
        sidebar.addWidget(self._footer_label)

        self.setCentralWidget(central)

    def _on_frame(self, image: QImage) -> None:
        pixmap = QPixmap.fromImage(image).scaled(
            self._video_label.size(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )
        self._video_label.setPixmap(pixmap)

    def _on_plate_detected(self, plate: str, confidence: float) -> None:
        color = GREEN if confidence >= CONFIDENCE_THRESHOLD else AMBER
        self._reading_label.setText(f"{plate}\n{confidence:.0%} confidence")
        self._reading_label.setStyleSheet(
            f"font-size: 28px; font-weight: bold; padding: 8px 0; color: {color.name()};"
        )

    def _on_send_result(self, result: SendResult) -> None:
        self._last_send_result = result
        self._render_connection_status()

    def _on_history_row(self, at: datetime, plate: str, confidence: float, ok: bool) -> None:
        table = self._history_table
        table.insertRow(0)
        table.setItem(0, 0, QTableWidgetItem(at.astimezone().strftime("%H:%M:%S")))
        table.setItem(0, 1, QTableWidgetItem(plate))
        table.setItem(0, 2, QTableWidgetItem(f"{confidence:.0%}"))

        sent_item = QTableWidgetItem("✓" if ok else "✗")
        sent_item.setForeground(GREEN if ok else RED)
        table.setItem(0, 3, sent_item)

        while table.rowCount() > HISTORY_MAX_ROWS:
            table.removeRow(table.rowCount() - 1)

    def _on_camera_error(self, message: str) -> None:
        self._camera_down_since = time.monotonic()
        self._footer_label.setText(f"⚠ {message}")
        self._footer_label.setStyleSheet(f"color: {RED.name()};")

    def _on_camera_recovered(self) -> None:
        self._camera_down_since = None
        self._footer_label.setText("Camera live")
        self._footer_label.setStyleSheet(f"color: {GREEN.name()};")

    def _tick(self) -> None:
        now = datetime.now(PH_TIMEZONE)
        self._clock_label.setText(now.strftime("%A, %B %d, %Y — %I:%M:%S %p"))

        self._render_connection_status()

        if self._camera_down_since is not None:
            elapsed = int(time.monotonic() - self._camera_down_since)
            self._footer_label.setText(f"⚠ Feed lost {elapsed}s ago — retrying…")

    def _render_connection_status(self) -> None:
        result = self._last_send_result
        if result is None:
            self._connection_label.setText("Waiting for first send…")
            self._connection_label.setStyleSheet(f"color: {GRAY.name()};")
            return

        elapsed = max(0, int((datetime.now(timezone.utc) - result.at).total_seconds()))

        if result.ok:
            self._connection_label.setText(f"● Connected — sent {elapsed}s ago")
            self._connection_label.setStyleSheet(f"color: {GREEN.name()};")
        else:
            self._connection_label.setText(f"● No response {elapsed}s ago — {result.error}")
            self._connection_label.setStyleSheet(f"color: {RED.name()};")

    def closeEvent(self, event) -> None:  # noqa: N802 (Qt override)
        self._worker.stop()
        self._worker.wait(2000)
        super().closeEvent(event)


class SetupDialog(QDialog):
    """Shown once, the first time this app runs on a PC with no saved key —
    so setting it up means pasting a key into a box, not finding and editing
    a JSON file by hand.
    """

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("AimPark ALPR — Set up this camera")
        self.setMinimumWidth(440)

        info = QLabel(
            "Ask whoever manages your AimPark account for this camera's key "
            "— it's generated once from the admin app's Gate Devices screen. "
            "You'll only need to do this the first time this app runs on "
            "this PC."
        )
        info.setWordWrap(True)

        self._key_input = QLineEdit()
        self._key_input.setPlaceholderText("aimpark_...")

        self._gate_input = QLineEdit()
        self._gate_input.setPlaceholderText("e.g. Gate 1")

        self._api_input = QLineEdit(DEFAULT_API_BASE)

        form = QFormLayout()
        form.addRow("Device key:", self._key_input)
        form.addRow("Gate label:", self._gate_input)
        form.addRow("Server address:", self._api_input)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._on_accept)
        buttons.rejected.connect(self.reject)

        layout = QVBoxLayout(self)
        layout.addWidget(info)
        layout.addSpacing(8)
        layout.addLayout(form)
        layout.addWidget(buttons)

    def _on_accept(self) -> None:
        if not self._key_input.text().strip() or not self._gate_input.text().strip():
            QMessageBox.warning(
                self, "Missing information",
                "Please fill in both the device key and a gate label."
            )
            return
        self.accept()

    def result_config(self) -> Config:
        return Config(
            api_base=self._api_input.text().strip().rstrip("/") or DEFAULT_API_BASE,
            api_key=self._key_input.text().strip(),
            camera_index=0,
            camera_mirrored=False,
            gate_label=self._gate_input.text().strip(),
        )


class LoginDialog(QDialog):
    """Gates the app itself, separately from the device key: the key proves
    this is a real registered camera, this proves the person in front of it
    is actually Security or Admin staff. Shown on every launch, not just the
    first — unlike the device key, who's operating it can change shift to
    shift.
    """

    def __init__(self, api_base: str) -> None:
        super().__init__()
        self._api_base = api_base
        self.full_name: str | None = None

        self.setWindowTitle("AimPark ALPR — Sign in")
        self.setMinimumWidth(360)

        info = QLabel("Only Security and Admin accounts can open this app.")
        info.setWordWrap(True)
        info.setStyleSheet(f"color: {GRAY.name()};")

        self._email_input = QLineEdit()
        self._password_input = QLineEdit()
        self._password_input.setEchoMode(QLineEdit.EchoMode.Password)

        form = QFormLayout()
        form.addRow("Email:", self._email_input)
        form.addRow("Password:", self._password_input)

        self._error_label = QLabel("")
        self._error_label.setStyleSheet(f"color: {RED.name()};")
        self._error_label.setWordWrap(True)
        self._error_label.hide()

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        self._sign_in_button = buttons.button(QDialogButtonBox.StandardButton.Ok)
        self._sign_in_button.setText("Sign in")
        buttons.accepted.connect(self._on_accept)
        buttons.rejected.connect(self.reject)

        layout = QVBoxLayout(self)
        layout.addWidget(info)
        layout.addSpacing(8)
        layout.addLayout(form)
        layout.addWidget(self._error_label)
        layout.addWidget(buttons)

    def _on_accept(self) -> None:
        email = self._email_input.text().strip()
        password = self._password_input.text()

        if not email or not password:
            self._show_error("Enter your email and password.")
            return

        self._sign_in_button.setEnabled(False)
        self._sign_in_button.setText("Signing in…")
        QApplication.processEvents()  # repaint the button before the blocking call

        result = login(self._api_base, email, password)

        self._sign_in_button.setEnabled(True)
        self._sign_in_button.setText("Sign in")

        if not result.ok:
            self._show_error(result.error or "Sign-in failed.")
            return

        self.full_name = result.full_name
        self.accept()

    def _show_error(self, message: str) -> None:
        self._error_label.setText(message)
        self._error_label.show()


def main() -> int:
    app = QApplication(sys.argv)

    config = load_config_or_none()
    if config is None:
        setup_dialog = SetupDialog()
        if setup_dialog.exec() != QDialog.DialogCode.Accepted:
            return 0
        config = setup_dialog.result_config()
        save_config(config)

    login_dialog = LoginDialog(config.api_base)
    if login_dialog.exec() != QDialog.DialogCode.Accepted:
        return 0

    window = AlprWindow(config, signed_in_as=login_dialog.full_name)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
