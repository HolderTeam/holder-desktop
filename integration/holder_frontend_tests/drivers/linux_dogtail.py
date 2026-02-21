from __future__ import annotations

import os
import signal
import subprocess
import time
from typing import Callable, Optional

from .base import FrontendDriver


class LinuxDogtailDriver(FrontendDriver):
    """Dogtail adapter for the Linux GTK frontend."""

    def __init__(self, app_path: str) -> None:
        self.app_path = app_path
        self.proc: Optional[subprocess.Popen] = None

    def launch(self) -> None:
        if not os.path.exists(self.app_path):
            raise RuntimeError(f"App not found: {self.app_path}")

        env = os.environ.copy()
        env.setdefault("NO_AT_BRIDGE", "0")
        env.setdefault("GTK_A11Y", "atspi")
        env.setdefault("GSETTINGS_BACKEND", "memory")
        env.setdefault("GTK_USE_PORTAL", "0")

        self.proc = subprocess.Popen([self.app_path], env=env)

        # Lazy import so non-linux clients can still import package safely.
        from dogtail import tree  # pylint: disable=import-outside-toplevel

        app = self._wait_for(lambda: self._find_app(tree), timeout=40.0)
        self._wait_for(lambda: self._find_window(app), timeout=30.0)

    def shutdown(self) -> None:
        if self.proc is None:
            return
        if self.proc.poll() is None:
            self.proc.send_signal(signal.SIGTERM)
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)
        self.proc = None

    def create_card(self) -> None:
        from dogtail import tree  # pylint: disable=import-outside-toplevel

        app = self._wait_for(lambda: self._find_app(tree), timeout=20.0)
        window = self._wait_for(lambda: self._find_window(app), timeout=20.0)

        button = self._wait_for(
            lambda: self._find_named(window, "Create a new card"),
            timeout=20.0,
        )
        self._click_node(button)

    def has_card_titled_prefix(self, prefix: str) -> bool:
        from dogtail import tree  # pylint: disable=import-outside-toplevel

        app = self._wait_for(lambda: self._find_app(tree), timeout=20.0)
        window = self._wait_for(lambda: self._find_window(app), timeout=20.0)

        matches = window.findChildren(
            lambda node: (getattr(node, "name", "") or "").startswith(prefix)
        )
        return len(matches) > 0

    def _find_app(self, tree_module):
        for app_name in ("Holder", "holder-linux", "io.holder.linux"):
            try:
                app = tree_module.root.application(app_name)
                if app is not None:
                    return app
            except Exception:
                pass

        for child in getattr(tree_module.root, "children", []):
            try:
                if getattr(child, "roleName", "") == "application" and self._find_window(child) is not None:
                    return child
            except Exception:
                pass
        return None

    @staticmethod
    def _find_window(app):
        for child in app.children:
            if child.roleName in ("frame", "window"):
                return child
        return None

    @staticmethod
    def _find_named(scope, name: str):
        matches = scope.findChildren(lambda node: getattr(node, "name", "") == name)
        return matches[0] if matches else None

    @staticmethod
    def _click_node(node) -> None:
        for action_name in ("click", "press", "activate"):
            try:
                node.doActionNamed(action_name)
                return
            except Exception:
                pass
        raise RuntimeError(f"Cannot click node: {getattr(node, 'name', '<unnamed>')}")

    @staticmethod
    def _wait_for(fn: Callable[[], object], timeout: float = 20.0, interval: float = 0.2):
        deadline = time.time() + timeout
        last_error = None
        while time.time() < deadline:
            try:
                value = fn()
                if value is not None:
                    return value
            except Exception as exc:
                last_error = exc
            time.sleep(interval)
        if last_error:
            raise RuntimeError(f"Timed out waiting; last error: {last_error}")
        raise RuntimeError("Timed out waiting for condition")
