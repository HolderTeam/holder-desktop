from __future__ import annotations

import os
import signal
import subprocess
import time
from typing import Callable, Optional

from dogtail import rawinput

from .base import FrontendDriver


class LinuxDogtailDriver(FrontendDriver):
    """Dogtail adapter for the Linux GTK frontend."""

    def __init__(self, app_path: str) -> None:
        self.app_path = app_path
        self.proc: Optional[subprocess.Popen] = None
        self._app = None
        self._window = None

    def launch(self) -> None:
        if self.proc is not None and self.proc.poll() is None:
            self._current_window()
            return

        if not os.path.exists(self.app_path):
            raise RuntimeError(f"App not found: {self.app_path}")

        env = os.environ.copy()
        env.setdefault("NO_AT_BRIDGE", "0")
        env.setdefault("GTK_A11Y", "atspi")
        env.setdefault("GSETTINGS_BACKEND", "memory")
        env.setdefault("GTK_USE_PORTAL", "0")
        schema_dir = os.path.join(os.path.dirname(self.app_path), "data")
        if os.path.exists(os.path.join(schema_dir, "gschemas.compiled")):
            env.setdefault("GSETTINGS_SCHEMA_DIR", schema_dir)

        self.proc = subprocess.Popen(
            [self.app_path],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # Lazy import so non-linux clients can still import package safely.
        from dogtail import tree  # pylint: disable=import-outside-toplevel

        app = self._wait_for(lambda: self._find_launched_app(tree), timeout=40.0)
        window = self._wait_for(lambda: self._find_window(app), timeout=30.0)
        self._app = app
        self._window = window

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
        self._app = None
        self._window = None

    def create_card(self) -> None:
        window = self._current_window()
        button = self._wait_for(
            lambda: self._find_named(window, "Create a new card"),
            timeout=20.0,
        )
        self._click_node(button)

    def create_project(self, name: str) -> None:
        self._click_named_control("Create a new project")
        dialog = self._wait_for(lambda: self._find_dialog("New Project"), timeout=10.0)
        entries = self._text_entries(dialog)
        if not entries:
            raise RuntimeError("New Project dialog did not expose a project name entry")
        self._set_text(entries[0], name)
        create = self._wait_for(lambda: self._find_named(dialog, "Create"), timeout=10.0)
        self._click_node(create)
        self._wait_for(
            lambda: True if self._find_named(self._current_window(), name) is not None else None,
            timeout=20.0,
            interval=0.2,
        )

    def has_project_named(self, name: str) -> bool:
        return self._has_visible_named(name, timeout=10.0)

    def has_card_titled_prefix(self, prefix: str) -> bool:
        window = self._current_window()
        try:
            found = self._wait_for(
                lambda: True if window.findChildren(
                    lambda node: (getattr(node, "name", "") or "").startswith(prefix)
                ) else None,
                timeout=10.0,
                interval=0.2,
            )
            return found is True
        except RuntimeError:
            return False

    def replace_editor_text(self, text: str) -> None:
        editor = self._wait_for(lambda: self._find_editor_text_node(), timeout=20.0)
        self._set_text(editor, text)

    def save_state_is_visible(self, text: str) -> bool:
        return self._has_visible_named(text, timeout=20.0)

    def search_cards(self, query: str) -> None:
        search_entry = self._wait_for(lambda: self._find_search_entry(), timeout=20.0)
        self._set_text(search_entry, query)
        rawinput.pressKey("Enter")

    def has_search_result(self, text: str) -> bool:
        return self._has_visible_named(text, timeout=20.0)

    def open_search_result(self, text: str) -> None:
        result = self._wait_for(lambda: self._find_named(self._current_window(), text), timeout=20.0)
        self._click_node(result)
        self._wait_for(lambda: self._find_editor_text_node(), timeout=20.0)

    def replace_all_in_editor(self, find_text: str, replace_text: str) -> None:
        search_entry = self._wait_for(lambda: self._find_search_entry(), timeout=20.0)
        self._set_text(search_entry, "")
        rawinput.pressKey("Enter")
        self._wait_for(lambda: self._find_editor_text_node(), timeout=20.0)
        self.open_find_replace_panel()
        find_entry, replace_entry = self._find_replace_entries()
        self._set_text(find_entry, find_text)
        self._set_text(replace_entry, replace_text)
        self._click_named_control("Replace All")
        self._wait_for(
            lambda: True if self._find_named(self._current_window(), "Replaced 1 matches.") is not None else None,
            timeout=10.0,
            interval=0.2,
        )

    def editor_text_contains(self, text: str) -> bool:
        try:
            return self._wait_for(
                lambda: True if text in self._editor_text() else None,
                timeout=10.0,
                interval=0.2,
            ) is True
        except RuntimeError:
            return False

    def editor_text_excludes(self, text: str) -> bool:
        try:
            return self._wait_for(
                lambda: True if text not in self._editor_text() else None,
                timeout=10.0,
                interval=0.2,
            ) is True
        except RuntimeError:
            return False

    def open_find_replace_panel(self) -> None:
        if not self.find_replace_panel_is_visible():
            self.toggle_find_replace_panel()
        self._wait_for(
            lambda: True if self._find_visible_named(self._current_window(), "Replace All") is not None else None,
            timeout=10.0,
            interval=0.2,
        )

    def toggle_find_replace_panel(self) -> None:
        self._click_named_control("Find and replace")

    def find_replace_panel_is_visible(self) -> bool:
        try:
            return self._wait_for(
                lambda: True if self._find_visible_named(self._current_window(), "Replace All") is not None else None,
                timeout=5.0,
                interval=0.2,
            ) is True
        except RuntimeError:
            return False

    def find_replace_panel_is_hidden(self) -> bool:
        try:
            return self._wait_for(
                lambda: True if self._find_visible_named(self._current_window(), "Replace All") is None else None,
                timeout=5.0,
                interval=0.2,
            ) is True
        except RuntimeError:
            return False

    def open_preferences(self) -> None:
        try:
            self._click_named_control("Open app menu")
            self._click_app_named_control("Preferences", timeout=3.0)
        except RuntimeError:
            self._activate_window_action("show-preferences")
        self._wait_for(lambda: self._find_dialog("Preferences"), timeout=10.0)

    def preferences_options_are_visible(self) -> bool:
        dialog = self._find_dialog("Preferences")
        if dialog is None:
            return False
        expected = (
            "Appearance",
            "Style Variant",
            "Editor Theme",
            "Editor",
            "Show line numbers",
            "Show spell checking",
        )
        return all(self._find_named(dialog, name) is not None for name in expected)

    def close_preferences(self) -> None:
        dialog = self._wait_for(lambda: self._find_dialog("Preferences"), timeout=10.0)
        close = self._find_sensitive_named(dialog, "Close")
        if close is None:
            close = self._find_named(dialog, "Close")
        if close is None:
            raise RuntimeError("Preferences dialog did not expose a Close control")
        self._click_node(close)
        self._wait_for(
            lambda: True if self._find_dialog("Preferences") is None else None,
            timeout=10.0,
            interval=0.2,
        )

    def preferences_are_closed(self) -> bool:
        try:
            return self._wait_for(
                lambda: True if self._find_dialog("Preferences") is None else None,
                timeout=5.0,
                interval=0.2,
            ) is True
        except RuntimeError:
            return False

    def can_see_text(self, text: str) -> bool:
        return self._has_visible_named(text, timeout=10.0)

    def has_app_shell(self) -> bool:
        expected = (
            "Holder",
            "Projects",
            "Cards",
            "Create a new card",
            "Clear search",
        )
        return all(self._has_visible_named(name, timeout=10.0) for name in expected)

    def toggle_toolbox_panel(self) -> None:
        self._click_toolbox_toggle(self._current_window())

    def open_toolbox_panel(self) -> None:
        if not self._has_toolbox_label(self._current_window()):
            self.toggle_toolbox_panel()
        self._wait_for(
            lambda: self._current_window() if self._has_toolbox_label(self._current_window()) else None,
            timeout=10.0,
            interval=0.2,
        )

    def toolbox_shell_is_visible(self) -> bool:
        self.open_toolbox_panel()
        window = self._current_window()
        expected_tabs = ("Flowboard", "Connections", "Resources", "Debug")
        tabs_visible = all(
            self._find_named_with_role(window, tab, "page tab") is not None
            for tab in expected_tabs
        )
        flowboard_occurrences = window.findChildren(
            lambda node: (
                getattr(node, "name", "") == "Flowboard"
                and getattr(node, "showing", True)
                and getattr(node, "visible", True)
            )
        )
        return tabs_visible and len(flowboard_occurrences) >= 2

    def switch_toolbox_tool(self, tool_name: str) -> None:
        self.open_toolbox_panel()
        window = self._current_window()
        tab = self._wait_for(
            lambda: self._find_named_with_role(window, tool_name, "page tab"),
            timeout=20.0,
            interval=0.2,
        )
        self._click_node(tab)

    def add_url_resource(self, label: str, uri: str) -> None:
        self.switch_toolbox_tool("Resources")
        self._click_named_control("Add resource")
        dialog = self._wait_for(lambda: self._find_dialog("Add Resource"), timeout=10.0)
        entries = self._text_entries(dialog)
        if len(entries) < 2:
            raise RuntimeError("Add Resource dialog did not expose URI and Label entries")
        self._set_text(entries[0], uri)
        self._set_text(entries[1], label)
        save = self._wait_for(lambda: self._find_named(dialog, "Save"), timeout=10.0)
        self._click_node(save)
        self._wait_for(
            lambda: True if self._find_named(self._current_window(), label) is not None else None,
            timeout=10.0,
            interval=0.2,
        )

    def filter_resources(self, query: str) -> None:
        self.switch_toolbox_tool("Resources")
        entries = self._text_entries(self._current_window())
        if not entries:
            raise RuntimeError("Resources view did not expose a filter entry")
        self._set_text(entries[0], query)

    def delete_resource(self, label: str) -> None:
        self.switch_toolbox_tool("Resources")
        resource = self._wait_for(lambda: self._find_named(self._current_window(), label), timeout=10.0)
        self._click_resource_row(resource)
        self._click_named_control("Delete")
        dialog = self._wait_for(lambda: self._find_dialog("Delete Resource"), timeout=10.0)
        delete = self._wait_for(lambda: self._find_named(dialog, "Delete"), timeout=10.0)
        self._click_node(delete)
        self._wait_for(
            lambda: True if self._find_named(self._current_window(), "No resources in this project.") is not None else None,
            timeout=10.0,
            interval=0.2,
        )

    def toggle_ai_panel(self) -> None:
        self._click_named_control("Toggle AI panel")

    def search_panel_is_visible(self) -> bool:
        return self._has_visible_named("Clear search", timeout=10.0)

    def ai_panel_is_visible(self) -> bool:
        expected = ("AI", "Assistant", "Config", "Send", "New Thread")
        return all(self._has_visible_named(name, timeout=10.0) for name in expected)

    def toolbox_panel_is_visible(self) -> bool:
        window = self._current_window()
        visible = self._wait_for(
            lambda: window if self._has_toolbox_label(window) else None,
            timeout=10.0,
            interval=0.2,
        )
        return visible is not None

    def toolbox_panel_is_hidden(self) -> bool:
        window = self._current_window()
        hidden = self._wait_for(
            lambda: window if not self._has_toolbox_label(window) else None,
            timeout=10.0,
            interval=0.2,
        )
        return hidden is not None

    def _current_app(self):
        if self._app is not None:
            return self._app

        from dogtail import tree  # pylint: disable=import-outside-toplevel

        self._app = self._wait_for(lambda: self._find_launched_app(tree), timeout=20.0)
        return self._app

    def _current_window(self):
        if self._window is not None:
            return self._window

        app = self._current_app()
        self._window = self._wait_for(lambda: self._find_window(app), timeout=20.0)
        return self._window

    def _find_dialog(self, title: str):
        app = self._current_app()
        for child in app.children:
            try:
                name = getattr(child, "name", "") or ""
                role = getattr(child, "roleName", "") or ""
                if title in name and role in ("dialog", "frame", "window", "alert"):
                    return child
            except Exception:
                pass
        matches = app.findChildren(lambda node: title in (getattr(node, "name", "") or ""))
        return matches[0] if matches else None

    def _find_app(self, tree_module):
        for app_name in ("team.holder.Holder", "Holder", "holder-desktop", "holder-linux"):
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

    def _find_launched_app(self, tree_module):
        if self.proc is not None:
            exit_code = self.proc.poll()
            if exit_code is not None:
                raise RuntimeError(
                    f"App exited before appearing in accessibility tree: "
                    f"{self.app_path} exited with code {exit_code}"
                )
        return self._find_app(tree_module)

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
    def _find_visible_named(scope, name: str):
        matches = scope.findChildren(lambda node: getattr(node, "name", "") == name)
        for node in matches:
            if getattr(node, "showing", True) and getattr(node, "visible", True):
                return node
        return None

    @staticmethod
    def _find_named_with_role(scope, name: str, role_name: str):
        matches = scope.findChildren(
            lambda node: (
                getattr(node, "name", "") == name
                and getattr(node, "roleName", "") == role_name
            )
        )
        return matches[0] if matches else None

    @staticmethod
    def _find_sensitive_named(scope, name: str):
        matches = scope.findChildren(lambda node: getattr(node, "name", "") == name)
        if not matches:
            return None
        action_roles = ("push button", "button", "toggle button", "page tab", "menu item")
        actionable = [
            node for node in matches
            if (getattr(node, "roleName", "") or "") in action_roles
        ]
        candidates = actionable if actionable else matches
        visible_candidates = [
            node for node in candidates
            if (
                getattr(node, "sensitive", True)
                and getattr(node, "showing", True)
                and getattr(node, "visible", True)
                and LinuxDogtailDriver._node_area(node) > 0
            )
        ]
        if visible_candidates:
            candidates = visible_candidates
        for node in candidates:
            if getattr(node, "sensitive", True):
                return node
        return candidates[0]

    @staticmethod
    def _text_entries(scope):
        return scope.findChildren(
            lambda node: (
                (
                    "text" in (getattr(node, "roleName", "") or "").lower()
                    or (getattr(node, "roleName", "") or "").lower() == "entry"
                )
                and "label" not in (getattr(node, "roleName", "") or "").lower()
            )
        )

    def _find_search_entry(self):
        clear_button = self._find_named(self._current_window(), "Clear search")
        if clear_button is not None:
            parent = getattr(clear_button, "parent", None)
            if parent is not None:
                entries = self._text_entries(parent)
                if entries:
                    return entries[0]

        entries = self._text_entries(self._current_window())
        if not entries:
            return None
        return min(entries, key=self._node_area)

    def _find_editor_text_node(self):
        window = self._current_window()
        search_entry = self._find_search_entry()
        entries = [
            node for node in self._text_entries(window)
            if node is not search_entry
        ]
        if not entries:
            return None
        return max(entries, key=self._node_area)

    def _editor_text(self) -> str:
        editor = self._find_editor_text_node()
        if editor is None:
            return ""
        try:
            return editor.text
        except Exception:
            pass
        try:
            return editor.queryText().getText(0, -1)
        except Exception:
            return ""

    def _find_replace_entries(self):
        window = self._current_window()
        named_find = self._find_named(window, "Find text")
        named_replace = self._find_named(window, "Replacement text")
        if named_find is not None and named_replace is not None:
            return named_find, named_replace

        search_entry = self._find_search_entry()
        editor = self._find_editor_text_node()
        entries = [
            node for node in self._text_entries(window)
            if node is not search_entry and node is not editor
        ]
        entries.sort(key=lambda node: (self._node_y(node), self._node_x(node)))
        if len(entries) < 2:
            raise RuntimeError("Find/Replace bar did not expose find and replace entries")
        return entries[0], entries[1]

    @staticmethod
    def _node_x(node) -> int:
        try:
            x, _y = node.position
            return int(x)
        except Exception:
            return 0

    @staticmethod
    def _node_y(node) -> int:
        try:
            _x, y = node.position
            return int(y)
        except Exception:
            return 0

    @staticmethod
    def _node_area(node) -> int:
        try:
            width, height = node.size
            return int(width) * int(height)
        except Exception:
            return 0

    @staticmethod
    def _set_text(node, text: str) -> None:
        try:
            node.text = ""
            node.text = text
            return
        except Exception:
            pass
        node.grabFocus()
        rawinput.keyCombo("<Control>a")
        rawinput.pressKey("BackSpace")
        rawinput.typeText(text)

    def _click_resource_row(self, node) -> None:
        try:
            self._click_node(node)
            return
        except Exception:
            pass

        current = node
        for _ in range(6):
            role = (getattr(current, "roleName", "") or "").lower()
            if role in ("table row", "row", "list item"):
                for action_name in ("select", "click", "press", "activate"):
                    try:
                        current.doActionNamed(action_name)
                        return
                    except Exception:
                        pass
                self._click_node(current)
                return
            current = getattr(current, "parent", None)
            if current is None:
                break
        self._click_node(node)

    def _click_named_control(self, name: str) -> None:
        window = self._current_window()
        node = self._wait_for(
            lambda: self._find_sensitive_named(window, name),
            timeout=20.0,
            interval=0.2,
        )
        self._click_node(node)

    def _click_app_named_control(self, name: str, timeout: float = 20.0) -> None:
        node = self._wait_for(
            lambda: self._find_sensitive_named(self._current_app(), name),
            timeout=timeout,
            interval=0.2,
        )
        self._click_node(node)

    def _activate_window_action(self, action_name: str) -> None:
        candidates = (
            "/team/holder/Holder/window/1",
            "/team/holder/Holder/window/0",
            "/team/holder/Holder",
        )
        errors = []
        for object_path in candidates:
            proc = subprocess.run(
                [
                    "gdbus",
                    "call",
                    "--session",
                    "--dest",
                    "team.holder.Holder",
                    "--object-path",
                    object_path,
                    "--method",
                    "org.gtk.Actions.Activate",
                    action_name,
                    "[]",
                    "{}",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
                check=False,
            )
            if proc.returncode == 0:
                return
            errors.append(f"{object_path}: {proc.stderr.strip()}")
        raise RuntimeError(
            "Could not activate GTK action '%s': %s"
            % (action_name, "; ".join(errors))
        )

    @staticmethod
    def _click_center(node) -> None:
        x, y = node.position
        width, height = node.size
        rawinput.click(int(x + width / 2), int(y + height / 2))

    def _has_visible_named(self, name: str, timeout: float = 10.0) -> bool:
        window = self._current_window()
        try:
            found = self._wait_for(
                lambda: True if self._find_named(window, name) is not None else None,
                timeout=timeout,
                interval=0.2,
            )
            return found is True
        except RuntimeError:
            return False

    @staticmethod
    def _click_node(node) -> None:
        for action_name in ("click", "press", "activate"):
            try:
                node.doActionNamed(action_name)
                return
            except Exception:
                pass
        try:
            node.click()
            return
        except Exception:
            pass
        try:
            node.grabFocus()
            rawinput.pressKey("space")
            return
        except Exception:
            pass
        raise RuntimeError(f"Cannot click node: {getattr(node, 'name', '<unnamed>')}")

    def _click_toolbox_toggle(self, window) -> None:
        buttons = window.findChildren(
            lambda node: "button" in getattr(node, "roleName", "").lower()
        )

        for button in buttons:
            name = (getattr(button, "name", "") or "").lower()
            if "toolbox" in name:
                self._click_node(button)
                return

        toggle_buttons = [
            button for button in buttons
            if getattr(button, "roleName", "").lower() == "toggle button"
        ]
        if len(toggle_buttons) >= 2:
            self._click_node(toggle_buttons[-1])
            return
        if toggle_buttons:
            self._click_node(toggle_buttons[0])
            return
        raise RuntimeError("Could not find toolbox toggle button in accessibility tree")

    @staticmethod
    def _has_toolbox_label(window) -> bool:
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
