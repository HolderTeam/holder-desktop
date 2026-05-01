from __future__ import annotations

import os
from pathlib import Path

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


def before_scenario(context, scenario):
    if _has_tag(scenario, "isolated") and hasattr(context, "driver"):
        context.driver.shutdown()


def after_scenario(context, scenario):
    if _has_tag(scenario, "isolated") and hasattr(context, "driver"):
        context.driver.shutdown()


def after_all(context):
    if hasattr(context, "driver"):
        context.driver.shutdown()
