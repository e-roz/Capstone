"""Loads this camera's identity out of config.json — the git-ignored
counterpart to config.example.json. Same shape as the ESP32 reader's
secrets.h: the example file is committed, the real values aren't.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path

# Not next to the source/exe: once this ships as a packaged app copied
# between PCs, "next to the code" stops meaning anything stable, and a
# read-only or temp extraction folder couldn't be written to anyway. This is
# the same place Windows apps normally keep per-user settings.
_APP_DATA_DIR = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "AimParkAlpr"
CONFIG_PATH = _APP_DATA_DIR / "config.json"

# Every gate PC talks to the same server, so this is only something a guard
# would ever need to change if a technical person is troubleshooting — the
# setup dialog pre-fills it rather than asking a non-technical user to know it.
DEFAULT_API_BASE = "https://aimpark-api.onrender.com"


@dataclass
class Config:
    api_base: str
    api_key: str
    camera_index: int
    camera_mirrored: bool
    gate_label: str


def load_config() -> Config:
    data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))

    return Config(
        api_base=data["api_base"].rstrip("/"),
        api_key=data["api_key"],
        camera_index=data.get("camera_index", 0),
        camera_mirrored=data.get("camera_mirrored", False),
        gate_label=data.get("gate_label", "Unlabeled gate"),
    )


def load_config_or_none() -> Config | None:
    """Same as load_config, but for the app's startup path: a missing or
    incomplete config means "run the setup dialog," not a crash."""
    if not CONFIG_PATH.exists():
        return None
    try:
        config = load_config()
    except (KeyError, ValueError):
        return None
    return config if config.api_key and config.api_base else None


def save_config(config: Config) -> None:
    _APP_DATA_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(
        json.dumps(
            {
                "api_base": config.api_base,
                "api_key": config.api_key,
                "camera_index": config.camera_index,
                "camera_mirrored": config.camera_mirrored,
                "gate_label": config.gate_label,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
