from __future__ import annotations

import os
import json
from pathlib import Path
from time import time
from urllib.request import Request, urlopen

from holder_frontend_tests.drivers import LinuxDogtailDriver


def _default_linux_app_path() -> str:
    repo_root = Path(__file__).resolve().parents[3]
    return str(repo_root / "build" / "holder-desktop")


def before_all(context):
    target = os.environ.get("HOLDER_FRONTEND_TARGET", "linux").strip().lower()
    app_path = context.config.userdata.get("app_path") or os.environ.get(
        "HOLDER_FRONTEND_APP_PATH",
        _default_linux_app_path(),
    )

    if target == "linux":
        context.driver = LinuxDogtailDriver(app_path)
    else:
        raise RuntimeError(
            f"Unsupported HOLDER_FRONTEND_TARGET '{target}'. "
            "Expected one of: linux"
        )


def _has_tag(scenario, tag: str) -> bool:
    tags = getattr(scenario, "effective_tags", scenario.tags)
    return tag in tags


def _fixture_request(method: str, path: str, payload: dict | None = None) -> dict:
    base_url = os.environ.get("HOLDER_INTEGRATION_BASE_URL", "").rstrip("/")
    auth_token = os.environ.get("HOLDER_INTEGRATION_AUTH_TOKEN", "")
    if not base_url or not auth_token:
        raise RuntimeError("History fixture requires the isolated Holder daemon connection")
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        f"{base_url}{path}",
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {auth_token}",
            "Content-Type": "application/json",
        },
    )
    with urlopen(request, timeout=10) as response:  # nosec B310: isolated local daemon
        result = json.loads(response.read().decode("utf-8"))
    if not result.get("ok"):
        raise RuntimeError(f"History fixture request failed: {method} {path}")
    return result["data"]


def _seed_history_fixture(context) -> None:
    project = _fixture_request(
        "POST",
        "/projects",
        {"name": "History Fixture Project", "privacy_mode": "plain"},
    )
    card = _fixture_request(
        "POST",
        "/cards",
        {
            "project_id": project["project_id"],
            "title": "History Fixture Card",
            "content": "First fixture body\n",
        },
    )
    _fixture_request(
        "PATCH",
        f"/cards/{card['card_id']}",
        {
            "title": "History Fixture Card",
            "content": "Fixture revised history body\n",
            "updated_at": int(time()) + 1,
        },
    )
    context.history_fixture_project = project["name"]
    context.history_fixture_card = "History Fixture Card"


def before_scenario(context, scenario):
    if _has_tag(scenario, "isolated") and hasattr(context, "driver"):
        context.driver.shutdown()
    if _has_tag(scenario, "history_fixture"):
        _seed_history_fixture(context)


def after_scenario(context, scenario):
    if _has_tag(scenario, "isolated") and hasattr(context, "driver"):
        context.driver.shutdown()


def after_all(context):
    if hasattr(context, "driver"):
        context.driver.shutdown()
