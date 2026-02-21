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

    for app_name in ("Holder", "holder-linux", "io.holder.linux"):
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


def click_node(node):
    for action_name in ("click", "press", "activate"):
        try:
            node.doActionNamed(action_name)
            return
        except Exception:  # noqa: BLE001
            pass
    raise RuntimeError(f"Could not click node named {getattr(node, 'name', '<unnamed>')}")


def find_new_card_button(window):
    matches = window.findChildren(
        lambda node: getattr(node, "name", "") == "Create a new card"
    )
    if not matches:
        return None
    return matches[0]


def count_untitled_nodes(window):
    return len(window.findChildren(
        lambda node: (getattr(node, "name", "") or "").startswith("Untitled")
    ))


def has_created_status(window):
    matches = window.findChildren(
        lambda node: getattr(node, "name", "") == "Created new card"
    )
    return len(matches) > 0


def main():
    if len(sys.argv) != 2:
        raise RuntimeError("usage: test_create_card.py /path/to/holder-linux")

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

        button = wait_for(lambda: find_new_card_button(window), timeout=20.0)
        before_count = count_untitled_nodes(window)

        click_node(button)

        wait_for(
            lambda: window if count_untitled_nodes(window) > before_count or has_created_status(window) else None,
            timeout=20.0,
        )

        print("UI create-card test passed")
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
