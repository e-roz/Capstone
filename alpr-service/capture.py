"""Webcam capture — step one of the ALPR pipeline, before any plate reading
is wired in. Run directly to confirm a camera opens and frames come through;
later steps import Camera rather than touching cv2.VideoCapture directly.
"""

import argparse
import sys

import cv2


class Camera:
    def __init__(self, index: int = 0, mirrored: bool = False):
        self.index = index
        # Off by default: a real gate camera has no reason to mirror its
        # feed, and mirroring would flip the plate text backwards before
        # OCR ever sees it. Only laptop webcams tend to do this, for a
        # "looking in a mirror" feel that has no place at a barrier.
        self.mirrored = mirrored
        self._cap: cv2.VideoCapture | None = None

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
        self._cap = cap

    def read_frame(self) -> cv2.typing.MatLike | None:
        ok, frame = self._cap.read()
        if not ok:
            return None
        return cv2.flip(frame, 1) if self.mirrored else frame

    def resolution(self) -> tuple[int, int]:
        width = int(self._cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        return width, height

    def release(self) -> None:
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
