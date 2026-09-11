"""Live plate detection preview — a quick console/window check that the
model reads plates correctly on this camera, without the full desktop app
in app.py. Not the production tool: no history, no status, no sending to
the API, just the raw read printed to the console.
"""

import argparse
import sys

import cv2

from capture import Camera
from plate_reader import PlateReader


def main() -> int:
    parser = argparse.ArgumentParser(description="Preview live plate detection.")
    parser.add_argument(
        "--camera", type=int, default=0,
        help="Capture device index (default 0).",
    )
    parser.add_argument(
        "--mirrored", action="store_true",
        help="Un-mirror the feed — set this if the preview looks like a mirror "
             "(common on laptop webcams, not expected on real gate hardware).",
    )
    args = parser.parse_args()

    print("Loading ALPR models (first run downloads them)...")
    reader = PlateReader()

    try:
        camera = Camera(args.camera, mirrored=args.mirrored)
        camera.open()
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    print("Camera open. Hold a plate up to it. Press Q to quit.")

    window = "AimPark ALPR - plate detection preview"
    last_printed: str | None = None

    try:
        while True:
            frame = camera.read_frame()
            if frame is None:
                print("Lost the camera feed — device disconnected?", file=sys.stderr)
                break

            result = reader.read(frame)

            if result.plate and result.plate != last_printed:
                print(f"Read: {result.plate}  (confidence {result.confidence:.2f})")
                last_printed = result.plate

            cv2.imshow(window, result.frame)

            if cv2.waitKey(1) & 0xFF in (ord("q"), 27):  # 27 = Esc
                break
    finally:
        camera.release()
        cv2.destroyAllWindows()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
