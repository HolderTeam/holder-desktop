namespace HolderLinux {

public class ToolboxPane : Object {
    private Gtk.TextBuffer debug_buffer;
    private Gtk.TextView debug_view;
    private Gtk.ListBox ai_catalog_list;
    private Gtk.Notebook terminal_notebook;
    private int next_terminal_index = 1;
    private Gtk.Entry git_remote_entry;
    private Gtk.Entry git_branch_entry;
    private FlowboardPane flowboard;
    private FlowboardController? flowboard_controller;
    private IHolderApi? api;
    public Gtk.Revealer widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void flowboard_card_open_requested(string card_id);

    public ToolboxPane() {
        widget = new Gtk.Revealer();
        widget.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP);
        widget.set_reveal_child(false);
        widget.set_child(build_ui());
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
    }

    public void bind_flowboard_controller(FlowboardController controller) {
        flowboard_controller = controller;
        flowboard.set_model(controller.get_visible_model());
        controller.breadcrumb_changed.connect((text) => {
            flowboard.set_breadcrumb(text);
        });
        controller.empty_message_changed.connect((text) => {
            flowboard.set_empty_message(text);
        });
        controller.card_open_requested.connect((card_id) => {
            flowboard_card_open_requested(card_id);
        });
        flowboard.tile_activated.connect((position) => {
            controller.activate_position(position);
        });
        flowboard.navigate_up_requested.connect(() => {
            controller.navigate_up();
        });
        controller.refresh();
    }

    public void set_reveal_child(bool reveal) {
        widget.set_reveal_child(reveal);
    }

    public void log_debug(string line) {
        Gtk.TextIter end;
        debug_buffer.get_end_iter(out end);
        var stamp = new DateTime.now_local().format("%H:%M:%S");
        debug_buffer.insert(ref end, "[%s] %s\n".printf(stamp, line), -1);
        if (debug_view != null) {
            Idle.add(() => {
                Gtk.TextIter latest_end;
                debug_buffer.get_end_iter(out latest_end);
                debug_buffer.place_cursor(latest_end);
                debug_view.scroll_to_iter(latest_end, 0.0, false, 0.0, 1.0);
                return Source.REMOVE;
            });
        }
    }

    public async void refresh_ai_catalog() {
        if (api == null) {
            return;
        }
        clear_list_box(ai_catalog_list);
        try {
            var providers = yield api.list_ai_provider_catalog();
            if (providers.size == 0) {
                ai_catalog_list.append(new Gtk.Label("No providers in catalog.") { xalign = 0.0f });
                return;
            }
            foreach (var provider in providers) {
                var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
                var title = "%s (%s)".printf(provider.display_name, provider.id);
                var title_label = new Gtk.Label(title) { xalign = 0.0f };
                title_label.add_css_class("title-5");
                var detail = "enabled=%s configured=%s".printf(
                    provider.enabled ? "yes" : "no",
                    provider.configured ? "yes" : "no"
                );
                var detail_label = new Gtk.Label(detail) { xalign = 0.0f };
                detail_label.add_css_class("dim-label");
                detail_label.set_wrap(true);
                row.append(title_label);
                row.append(detail_label);
                if (provider.setup_url.length > 0 || provider.docs_url.length > 0) {
                    var urls = new Gtk.Label(
                        "setup: %s\ndocs: %s".printf(provider.setup_url, provider.docs_url)
                    ) { xalign = 0.0f };
                    urls.add_css_class("caption");
                    urls.add_css_class("dim-label");
                    urls.set_wrap(true);
                    row.append(urls);
                }
                ai_catalog_list.append(row);
            }
            log_debug("AI catalog refreshed: %d providers".printf(providers.size));
        } catch (Error e) {
            log_debug("AI catalog refresh failed: %s".printf(e.message));
            error_reported("AI catalog refresh failed", e.message);
        }
    }

    private Gtk.Widget build_ui() {
        var frame = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        frame.set_margin_top(6);
        frame.set_margin_bottom(6);
        frame.set_margin_start(6);
        frame.set_margin_end(6);
        frame.add_css_class("toolbar");

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var title = new Gtk.Label("Toolbox");
        title.add_css_class("title-5");
        title.set_halign(Gtk.Align.START);
        title.set_hexpand(true);
        var switcher = new Gtk.StackSwitcher();
        header.append(title);
        header.append(switcher);
        frame.append(header);

        var stack = new Gtk.Stack();
        stack.set_vexpand(true);
        stack.set_hexpand(true);
        switcher.set_stack(stack);
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

        var connections_page = stack.add_titled(
            build_placeholder_tab("Connections tools are scaffolded and planned."),
            "connections",
            "Connections"
        );
        connections_page.set_icon_name("network-wired-symbolic");

        var resources_page = stack.add_titled(
            build_placeholder_tab("Resource tools are scaffolded and planned."),
            "resources",
            "Resources"
        );
        resources_page.set_icon_name("view-list-symbolic");

        flowboard = new FlowboardPane();
        var corkboard_page = stack.add_titled(flowboard.widget, "corkboard", "Corkboard");
        corkboard_page.set_icon_name("view-grid-symbolic");

        var sharing_page = stack.add_titled(
            build_placeholder_tab("Sharing tools are scaffolded and planned."),
            "sharing",
            "Sharing"
        );
        sharing_page.set_icon_name("emblem-shared-symbolic");

        var terminals_page = stack.add_titled(build_terminal_tab(), "terminals", "Terminals");
        terminals_page.set_icon_name("utilities-terminal-symbolic");

        var catalog_page = stack.add_titled(build_ai_catalog_tab(), "catalog", "AI Catalog");
        catalog_page.set_icon_name("x-office-address-book-symbolic");

        var git_page = stack.add_titled(build_git_sync_tab(), "git", "Git Sync");
        git_page.set_icon_name("folder-remote-symbolic");

        var debug_page = stack.add_titled(build_debug_tab(), "debug", "Debug");
        debug_page.set_icon_name("view-reveal-symbolic");

        stack.set_visible_child_name("terminals");

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_min_content_height(180);
        scroller.set_child(stack);
        frame.append(scroller);

        return frame;
    }

    private Gtk.Widget build_placeholder_tab(string message) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var info = new Gtk.Label(message) { xalign = 0.0f };
        info.set_wrap(true);
        info.add_css_class("dim-label");
        box.append(info);
        return box;
    }

    private Gtk.Widget build_debug_tab() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        debug_buffer = new Gtk.TextBuffer(null);
        debug_view = new Gtk.TextView.with_buffer(debug_buffer);
        debug_view.set_editable(false);
        debug_view.set_monospace(true);
        debug_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        debug_view.set_vexpand(true);

        var controls = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var clear = new Gtk.Button.with_label("Clear");
        clear.clicked.connect(() => {
            debug_buffer.set_text("", -1);
        });
        controls.append(clear);
        box.append(controls);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(debug_view);
        box.append(scroll);
        return box;
    }

    private Gtk.Widget build_ai_catalog_tab() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var refresh_btn = new Gtk.Button.with_label("Refresh Catalog");
        refresh_btn.clicked.connect(() => {
            refresh_ai_catalog.begin();
        });
        actions.append(refresh_btn);
        box.append(actions);

        ai_catalog_list = new Gtk.ListBox();
        ai_catalog_list.set_selection_mode(Gtk.SelectionMode.NONE);

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(ai_catalog_list);
        box.append(scroll);
        return box;
    }

    private Gtk.Widget build_terminal_tab() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        terminal_notebook = new Gtk.Notebook();
        terminal_notebook.set_vexpand(true);
        terminal_notebook.set_hexpand(true);

        var add_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        add_btn.set_tooltip_text("New Terminal");
        add_btn.add_css_class("flat");
        add_btn.clicked.connect(() => {
            add_terminal_tab();
        });
        terminal_notebook.set_action_widget(add_btn, Gtk.PackType.END);

        box.append(terminal_notebook);

        add_terminal_tab();
        return box;
    }

    private Gtk.Widget build_git_sync_tab() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        var remote_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var remote_label = new Gtk.Label("Remote URL") { xalign = 0.0f };
        remote_label.set_size_request(100, -1);
        git_remote_entry = new Gtk.Entry();
        git_remote_entry.set_hexpand(true);
        git_remote_entry.set_placeholder_text("https://example.com/repo.git");
        remote_row.append(remote_label);
        remote_row.append(git_remote_entry);
        box.append(remote_row);

        var branch_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var branch_label = new Gtk.Label("Branch") { xalign = 0.0f };
        branch_label.set_size_request(100, -1);
        git_branch_entry = new Gtk.Entry();
        git_branch_entry.set_placeholder_text("main");
        branch_row.append(branch_label);
        branch_row.append(git_branch_entry);
        box.append(branch_row);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var save_btn = new Gtk.Button.with_label("Save (Planned)");
        save_btn.clicked.connect(() => {
            log_debug("Git config save requested (not wired)");
            toast_requested("Git sync config wiring planned.");
        });
        actions.append(save_btn);
        box.append(actions);

        var help = new Gtk.Label(
            "This tab is scaffolded. It will map to project git configuration and sync actions."
        ) { xalign = 0.0f };
        help.add_css_class("dim-label");
        help.set_wrap(true);
        box.append(help);
        return box;
    }

    private void add_terminal_tab() {
        var terminal = new Vte.Terminal();
        terminal.set_vexpand(true);
        terminal.set_hexpand(true);
        terminal.set_scrollback_lines(10000);
        configure_terminal_interactions(terminal);
        var fallback_title = "Term %d".printf(next_terminal_index);

        var shell = Environment.get_variable("SHELL");
        if (shell == null || shell.strip().length == 0) {
            shell = "/bin/bash";
        }
        string[] argv = {shell, null};
        terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            null,
            argv,
            null,
            SpawnFlags.SEARCH_PATH,
            null,
            -1,
            null,
            (term, pid, error) => {
                if (error != null) {
                    log_debug("Terminal spawn failed: %s".printf(error.message));
                } else {
                    log_debug("Terminal spawned (pid=%d)".printf((int) pid));
                }
            }
        );

        Gtk.Label tab_title_label;
        var tab_label = build_terminal_tab_label(terminal, fallback_title, out tab_title_label);
        terminal.window_title_changed.connect(() => {
            sync_terminal_tab_title(terminal, tab_title_label, fallback_title);
        });
        sync_terminal_tab_title(terminal, tab_title_label, fallback_title);

        next_terminal_index++;
        terminal_notebook.append_page(terminal, tab_label);
        terminal_notebook.set_tab_reorderable(terminal, true);
        terminal_notebook.set_current_page(terminal_notebook.get_n_pages() - 1);
    }

    private void configure_terminal_interactions(Vte.Terminal terminal) {
        var actions = new SimpleActionGroup();

        var copy_action = new SimpleAction("copy", null);
        copy_action.activate.connect(() => {
            terminal.copy_clipboard_format(Vte.Format.TEXT);
        });
        actions.add_action(copy_action);

        var paste_action = new SimpleAction("paste", null);
        paste_action.activate.connect(() => {
            terminal.paste_clipboard();
        });
        actions.add_action(paste_action);

        var select_all_action = new SimpleAction("select-all", null);
        select_all_action.activate.connect(() => {
            terminal.select_all();
        });
        actions.add_action(select_all_action);

        terminal.insert_action_group("terminal", actions);

        var menu = new GLib.Menu();
        menu.append("Copy", "terminal.copy");
        menu.append("Paste", "terminal.paste");
        menu.append("Select All", "terminal.select-all");
        terminal.set_context_menu_model(menu);

        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            var ctrl_shift = (state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK))
                == (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK);
            if (!ctrl_shift) {
                return false;
            }

            if (keyval == Gdk.Key.C || keyval == Gdk.Key.c) {
                terminal.copy_clipboard_format(Vte.Format.TEXT);
                return true;
            }

            if (keyval == Gdk.Key.V || keyval == Gdk.Key.v) {
                terminal.paste_clipboard();
                return true;
            }

            if (keyval == Gdk.Key.A || keyval == Gdk.Key.a) {
                terminal.select_all();
                return true;
            }

            return false;
        });
        terminal.add_controller(key_controller);
    }

    private Gtk.Widget build_terminal_tab_label(Gtk.Widget terminal_page, string title, out Gtk.Label label) {
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        box.set_size_request(120, -1);
        label = new Gtk.Label(title);
        label.set_xalign(0.0f);
        label.set_hexpand(true);
        label.set_ellipsize(Pango.EllipsizeMode.END);

        var close_btn = new Gtk.Button.from_icon_name("window-close-symbolic");
        close_btn.add_css_class("flat");
        close_btn.set_tooltip_text("Close terminal");
        close_btn.clicked.connect(() => {
            close_terminal_page(terminal_page);
        });

        box.append(label);
        box.append(close_btn);
        return box;
    }

    private void sync_terminal_tab_title(Vte.Terminal terminal, Gtk.Label tab_title_label, string fallback_title) {
        var title = terminal.get_window_title();
        if (title == null || title.strip().length == 0) {
            title = fallback_title;
        }
        tab_title_label.set_text(title);
        tab_title_label.set_tooltip_text(title);
    }

    private void close_terminal_page(Gtk.Widget page) {
        var page_index = terminal_notebook.page_num(page);
        if (page_index < 0) {
            return;
        }

        terminal_notebook.remove_page(page_index);
        log_debug("Terminal tab closed");

        if (terminal_notebook.get_n_pages() == 0) {
            add_terminal_tab();
        } else {
            var next = page_index;
            var count = terminal_notebook.get_n_pages();
            if (next >= count) {
                next = count - 1;
            }
            terminal_notebook.set_current_page(next);
        }
    }

    private void clear_list_box(Gtk.ListBox list) {
        Gtk.Widget? child = list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            list.remove(child);
            child = next;
        }
    }
}

}
