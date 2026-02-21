#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import time

from dogtail import tree


def wait_for(fn, timeout=30.0, interval=0.2):
    deadline = time.time() + timeout
    last_error = None
    while time.time() < deadline:
        try:
            value = fn()
            if value is not None:
                return value
        except Exception as exc:  # noqa: BLE001
            last_error = exc
        time.sleep(interval)
    if last_error:
        raise RuntimeError(f"Timed out waiting; last error: {last_error}")
    raise RuntimeError("Timed out waiting for condition")


def find_app():
    apps = []
    try:
        for child in tree.root.children:
            if getattr(child, "roleName", "") == "application":
                apps.append(child)
    except Exception:  # noqa: BLE001
        apps = []

    for app_name in ("Holder", "holder-desktop", "holder-linux", "io.holder.linux"):
        try:
            app = tree.root.application(app_name)
            if app is not None:
                return app
        except Exception:  # noqa: BLE001
            pass

    for app in apps:
        try:
            if find_window(app) is not None:
                return app
        except Exception:  # noqa: BLE001
            pass
    return None


def find_window(app):
    for child in app.children:
        if child.roleName in ("frame", "window"):
            return child
    return None


def has_toolbox_label(window):
    expected_names = (
        "Toolbox",
        "Debug",
        "AI Catalog",
        "New Terminal",
        "Refresh Catalog",
    )
    for child in window.findChildren(
        lambda node: getattr(node, "name", "") in expected_names
    ):
        if child is not None:
            return True
    return False


def click_node(node):
    for action_name in ("click", "press", "activate"):
        try:
            node.doActionNamed(action_name)
            return
        except Exception:  # noqa: BLE001
            pass
    raise RuntimeError(f"Could not click node named {getattr(node, 'name', '<unnamed>')}")


def click_toolbox_toggle(window):
    buttons = window.findChildren(
        lambda node: "button" in getattr(node, "roleName", "").lower()
    )

    for button in buttons:
        name = (getattr(button, "name", "") or "").lower()
        if "toolbox" in name:
            click_node(button)
            return

    toggle_buttons = [
        button for button in buttons
        if getattr(button, "roleName", "").lower() == "toggle button"
    ]
    if len(toggle_buttons) >= 2:
        click_node(toggle_buttons[-1])
        return

    if toggle_buttons:
        click_node(toggle_buttons[0])
        return

    raise RuntimeError("Could not find toolbox toggle button in accessibility tree")


def main():
    if len(sys.argv) != 2:
        raise RuntimeError("usage: test_smoke.py /path/to/holder-desktop")

    app_path = sys.argv[1]
    env = os.environ.copy()
    env["NO_AT_BRIDGE"] = "0"
    env["GTK_A11Y"] = "atspi"
    env["GSETTINGS_BACKEND"] = "memory"
    env["GTK_USE_PORTAL"] = "0"

    proc = subprocess.Popen([app_path], env=env)
    try:
        app = wait_for(find_app, timeout=40.0)
        window = wait_for(lambda: find_window(app), timeout=30.0)

        click_toolbox_toggle(window)

        wait_for(lambda: window if has_toolbox_label(window) else None, timeout=10.0)

        click_toolbox_toggle(window)
        time.sleep(0.2)

        print("UI smoke test passed")
    finally:
        if proc.poll() is None:
            proc.send_signal(signal.SIGTERM)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)


if __name__ == "__main__":
    main()
