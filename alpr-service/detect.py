"""Live plate detection preview — runs fast-alpr on the webcam feed so you can
see what it actually reads before any of this gets wired to the API. Not the
production loop: it prints every new read to the console with no cooldown or
posting logic, purely to check the model works on this camera and these
plates.
"""

import argparse
import sys

import cv2
from fast_alpr import ALPR

from capture import Camera


def confidence_of(ocr) -> float:
    if ocr is None:
        return 0.0
    # Some OCR models return one confidence per character rather than one
    # overall value — the weakest character is what should decide whether to
    # trust the read, not the average across a mostly-clear plate.
    c = ocr.confidence
    return min(c) if isinstance(c, list) else c


def main() -> int:
    parser = argparse.ArgumentParser(description="Preview live plate detection.")
    parser.add_argument(
        "--camera", type=int, default=0,
        help="Capture device index (default 0).",
    )
    args = parser.parse_args()

    print("Loading ALPR models (first run downloads them)...")
    alpr = ALPR(
        detector_model="yolo-v9-t-384-license-plate-end2end",
        ocr_model="cct-xs-v2-global-model",
    )

    try:
        camera = Camera(args.camera)
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

            drawn = alpr.draw_predictions(frame)

            for result in drawn.results:
                if result.ocr is None:
                    continue
                plate = result.ocr.text
                if plate and plate != last_printed:
                    print(f"Read: {plate}  (confidence {confidence_of(result.ocr):.2f})")
                    last_printed = plate

            cv2.imshow(window, drawn.image)

            if cv2.waitKey(1) & 0xFF in (ord("q"), 27):  # 27 = Esc
                break
    finally:
        camera.release()
        cv2.destroyAllWindows()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
