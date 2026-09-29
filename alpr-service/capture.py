"""Webcam capture — step one of the ALPR pipeline, before any plate reading
is wired in. Run directly to confirm a camera opens and frames come through;
later steps import Camera rather than touching cv2.VideoCapture directly.
"""

import argparse
import sys
import threading

import cv2

# How long read_frame waits for a new frame before calling the feed lost.
_FRAME_TIMEOUT_SECONDS = 3.0


class Camera:
    """A webcam that always hands back its newest frame.

    A background thread reads the camera as fast as it delivers and keeps
    only the latest frame. Without it, whenever plate reading is slower than
    the camera's frame rate the driver queues frames, and everything after
    it (the live video, the tap photo) falls seconds behind real time.
    """

    def __init__(self, index: int = 0, mirrored: bool = False):
        self.index = index
        # Off by default: a real gate camera has no reason to mirror its
        # feed, and mirroring would flip the plate text backwards before
        # OCR ever sees it. Only laptop webcams tend to do this, for a
        # "looking in a mirror" feel that has no place at a barrier.
        self.mirrored = mirrored
        self._cap: cv2.VideoCapture | None = None

        self._lock = threading.Lock()
        self._new_frame = threading.Condition(self._lock)
        self._frame: cv2.typing.MatLike | None = None
        self._frame_id = 0
        self._last_read_id = 0
        self._failed = False
        self._running = False
        self._thread: threading.Thread | None = None

    def open(self) -> None:
        # CAP_DSHOW avoids the multi-second stall MSMF (the Windows default
        # backend) sometimes takes on first open, and gives a clean failure
        # instead of hanging when no camera is attached.
        cap = cv2.VideoCapture(self.index, cv2.CAP_DSHOW)
        if not cap.isOpened():
            raise RuntimeError(
                f"Could not open camera {self.index}. Check it's plugged in, "
                "not in use by another app, and try a different --camera index."
            )
        # Not every driver honours this; the grab thread is what guarantees it.
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        self._cap = cap

        self._running = True
        self._thread = threading.Thread(target=self._grab_loop, daemon=True)
        self._thread.start()

    def _grab_loop(self) -> None:
        while self._running:
            ok, frame = self._cap.read()
            with self._lock:
                if not ok:
                    self._failed = True
                    self._new_frame.notify_all()
                    return
                self._frame = frame
                self._frame_id += 1
                self._new_frame.notify_all()

    def read_frame(self) -> cv2.typing.MatLike | None:
        """The newest frame not handed out yet, waiting for one if needed.
        None once the camera stops delivering."""
        with self._lock:
            got_new = self._new_frame.wait_for(
                lambda: self._failed or self._frame_id != self._last_read_id,
                timeout=_FRAME_TIMEOUT_SECONDS,
            )
            if not got_new or self._frame_id == self._last_read_id:
                return None
            self._last_read_id = self._frame_id
            frame = self._frame

        return cv2.flip(frame, 1) if self.mirrored else frame

    def resolution(self) -> tuple[int, int]:
        width = int(self._cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        return width, height

    def release(self) -> None:
        self._running = False
        if self._thread is not None:
            self._thread.join(timeout=2)
            self._thread = None
        if self._cap is not None:
            self._cap.release()
            self._cap = None

    def __enter__(self) -> "Camera":
        self.open()
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.release()


def main() -> int:
    parser = argparse.ArgumentParser(description="Preview a webcam feed.")
    parser.add_argument(
        "--camera", type=int, default=0,
        help="Capture device index (default 0 — the guard PC's primary camera).",
    )
    parser.add_argument(
        "--mirrored", action="store_true",
        help="Un-mirror the feed — set this if the preview looks like a mirror "
             "(common on laptop webcams, not expected on real gate hardware).",
    )
    args = parser.parse_args()

    try:
        camera = Camera(args.camera, mirrored=args.mirrored)
        camera.open()
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    width, height = camera.resolution()
    print(f"Camera {args.camera} opened at {width}x{height}. Press Q to quit.")

    window = "AimPark ALPR - camera preview"
    try:
        while True:
            frame = camera.read_frame()
            if frame is None:
                print("Lost the camera feed — device disconnected?", file=sys.stderr)
                break

            cv2.imshow(window, frame)

            # waitKey also pumps the window's event loop — without a call
            # here on every frame, the preview window never repaints.
            if cv2.waitKey(1) & 0xFF in (ord("q"), 27):  # 27 = Esc
                break
    finally:
        camera.release()
        cv2.destroyAllWindows()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
