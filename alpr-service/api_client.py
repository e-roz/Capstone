"""Talks to POST /api/gate/alpr-readings — the one endpoint this app needs.
Auth and device identity work exactly like the ESP32 reader: a long-lived
device key sent as X-Api-Key, issued once via the admin API.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

import requests

# Kept short deliberately: a hung API call must not stall the capture loop
# it shares a worker thread with for more than a beat.
REQUEST_TIMEOUT_SECONDS = 5

# A login call runs once, blocking the sign-in dialog before anything else
# starts — no shared loop to protect, so it can afford to wait longer for a
# slow connection instead of failing one that would have gone through.
LOGIN_TIMEOUT_SECONDS = 10

# Accounts allowed to open this app at all — matches how the admin panel
# already treats these two roles as "staff," as opposed to a driver's own
# User account.
ALLOWED_STAFF_ROLES = {"Admin", "Security"}


@dataclass
class SendResult:
    ok: bool
    at: datetime
    error: str | None = None


@dataclass
class LoginResult:
    ok: bool
    full_name: str | None = None
    error: str | None = None


def login(api_base: str, email: str, password: str) -> LoginResult:
    """Same POST /api/auth/login the admin panel uses — this app doesn't
    keep the token afterward, it only exists to check who's signing in and
    that they're staff, not to authenticate any of this app's own API
    calls (the device key does that).
    """
    try:
        response = requests.post(
            f"{api_base}/api/auth/login",
            json={"email": email, "password": password},
            timeout=LOGIN_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        return LoginResult(ok=False, error=f"Could not reach the server: {exc}")

    data = response.json() if response.content else {}

    if response.status_code >= 400:
        return LoginResult(ok=False, error=data.get("message", "Invalid credentials."))

    if data.get("role") not in ALLOWED_STAFF_ROLES:
        return LoginResult(ok=False, error="This account isn't Security or Admin staff.")

    return LoginResult(ok=True, full_name=data.get("fullName"))


class ApiClient:
    def __init__(self, api_base: str, api_key: str) -> None:
        self._url = f"{api_base}/api/gate/alpr-readings"
        self._headers = {"X-Api-Key": api_key}

    def post_reading(self, plate: str | None, confidence: float | None) -> SendResult:
        now = datetime.now(timezone.utc)
        body = {"plateNumber": plate, "confidence": confidence}

        try:
            response = requests.post(
                self._url, json=body, headers=self._headers, timeout=REQUEST_TIMEOUT_SECONDS
            )
        except requests.RequestException as exc:
            return SendResult(ok=False, at=now, error=str(exc))

        if response.status_code >= 400:
            return SendResult(ok=False, at=now, error=f"HTTP {response.status_code}")

        return SendResult(ok=True, at=now)
