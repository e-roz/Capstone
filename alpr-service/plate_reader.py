"""Shared plate-detection logic, used by both the console preview
(detect.py) and the desktop app (app.py) so the two can't drift apart.
"""

from __future__ import annotations

from dataclasses import dataclass

import cv2
from fast_alpr import ALPR

# Below this, a read is shown as a low-confidence (amber) result in the UI
# rather than a trusted (green) one. Purely a display cue — the API compares
# plate text, not confidence, so this has no effect on what gets sent.
CONFIDENCE_THRESHOLD = 0.85


def confidence_of(ocr) -> float:
    if ocr is None:
        return 0.0
    # Some OCR models return one confidence per character rather than one
    # overall value — the weakest character is what should decide whether to
    # trust the read, not the average across a mostly-clear plate.
    c = ocr.confidence
    return min(c) if isinstance(c, list) else c


@dataclass
class ReadResult:
    frame: cv2.typing.MatLike  # with detection boxes/text already drawn
    plate: str | None
    confidence: float


class PlateReader:
    def __init__(self) -> None:
        self._alpr = ALPR(
            detector_model="yolo-v9-t-384-license-plate-end2end",
            ocr_model="cct-xs-v2-global-model",
        )

    def read(self, frame: cv2.typing.MatLike) -> ReadResult:
        drawn = self._alpr.draw_predictions(frame)

        best_plate: str | None = None
        best_confidence = 0.0

        for result in drawn.results:
            if result.ocr is None or not result.ocr.text:
                continue
            confidence = confidence_of(result.ocr)
            # Keep the single most-confident plate in frame — this loop
            # is only ever asked "what's THE plate right now," not "list
            # everything visible."
            if best_plate is None or confidence > best_confidence:
                best_plate = result.ocr.text
                best_confidence = confidence

        return ReadResult(frame=drawn.image, plate=best_plate, confidence=best_confidence)
