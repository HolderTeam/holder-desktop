from __future__ import annotations

import os
from pathlib import Path

from holder_frontend_tests.drivers import LinuxDogtailDriver


def _default_linux_app_path() -> str:
    package_root = Path(__file__).resolve().parents[2]
    frontends_root = package_root.parent
    return str(frontends_root / "linux" / "build" / "holder-linux")


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


def after_scenario(context, scenario):
    if hasattr(context, "driver"):
        context.driver.shutdown()
