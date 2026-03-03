namespace HolderLinux {

public class ToolboxPane : Object {
    private Gtk.TextBuffer debug_buffer;
    private Gtk.TextView debug_view;
    private Gtk.Button sharing_email_btn;
    private Gtk.ListBox ai_catalog_list;
    private Gtk.ListBox git_catalog_list;
    private Gtk.Notebook terminal_notebook;
    private int next_terminal_index = 1;
    private ConnectionsToolView connections_tool;
    private GitSyncToolView git_sync_tool;
    private ResourcesToolView resources_tool;
    private FlowboardPane flowboard;
    private FlowboardController? flowboard_controller;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    public Gtk.Revealer widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void flowboard_card_open_requested(string card_id);
    public signal void flowboard_move_requested(string card_id, string? parent_card_id, double sort_key);
    public signal void flowboard_new_card_requested(string? parent_card_id);
    public signal void send_card_as_email_requested();
    public signal void send_recovery_key_as_email_requested();
    public signal void save_recovery_key_to_usb_requested();
    public signal void import_recovery_key_requested();
    public signal void terminal_copy_to_card_requested(string text);

    public ToolboxPane() {
        widget = new Gtk.Revealer();
        widget.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP);
        widget.set_reveal_child(false);
        widget.set_child(build_ui());
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        if (connections_tool != null) {
            connections_tool.set_api_client(api);
        }
        if (git_sync_tool != null) {
            git_sync_tool.set_api_client(api);
        }
        if (resources_tool != null) {
            resources_tool.set_api_client(api);
        }
    }

    public void set_settings(Settings? settings) {
        this.settings = settings;
        if (connections_tool != null) {
            connections_tool.set_settings(settings);
        }
        if (git_sync_tool != null) {
            git_sync_tool.set_settings(settings);
        }
    }

    public void bind_connections_context(Gtk.SingleSelection project_selection,
                                         GLib.ListStore card_store,
                                         Gtk.SingleSelection card_selection) {
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.card_selection = card_selection;

        if (connections_tool != null) {
            connections_tool.bind_context(project_selection, card_store, card_selection);
        }

        project_selection.notify["selected"].connect(() => {
            refresh_sharing_action_state();
        });
        card_selection.notify["selected"].connect(() => {
            refresh_sharing_action_state();
        });
        card_store.items_changed.connect((position, removed, added) => {
            refresh_sharing_action_state();
        });
        refresh_sharing_action_state();
        if (git_sync_tool != null) {
            git_sync_tool.set_project_selection(project_selection);
        }
        if (resources_tool != null) {
            resources_tool.set_project_selection(project_selection);
        }
    }

    public void bind_flowboard_controller(FlowboardController controller) {
        flowboard_controller = controller;
        flowboard.set_model(controller.get_visible_model());
        controller.breadcrumb_segments_changed.connect((segments) => {
            flowboard.set_breadcrumb_segments(segments);
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
        flowboard.breadcrumb_segment_activated.connect((index) => {
            controller.navigate_to_breadcrumb_index(index);
        });
        flowboard.card_drop_requested.connect((source_card_id, target_card_id, target_x_fraction) => {
            controller.on_card_drop(source_card_id, target_card_id, target_x_fraction);
        });
        flowboard.background_drop_requested.connect((source_card_id) => {
            controller.on_background_drop(source_card_id);
        });
        flowboard.background_new_card_requested.connect(() => {
            controller.request_create_card_here();
        });
        flowboard.card_open_requested.connect((card_id) => {
            controller.open_card_from_context_menu(card_id);
        });
        flowboard.card_move_up_level_requested.connect((card_id) => {
            controller.move_card_up_level_from_context_menu(card_id);
        });
        flowboard.card_move_left_requested.connect((card_id) => {
            controller.move_card_left_from_context_menu(card_id);
        });
        flowboard.card_move_right_requested.connect((card_id) => {
            controller.move_card_right_from_context_menu(card_id);
        });
        flowboard.card_move_to_start_requested.connect((card_id) => {
            controller.move_card_to_start_from_context_menu(card_id);
        });
        flowboard.card_move_to_end_requested.connect((card_id) => {
            controller.move_card_to_end_from_context_menu(card_id);
        });
        controller.move_requested.connect((card_id, parent_card_id, sort_key) => {
            flowboard_move_requested(card_id, parent_card_id, sort_key);
        });
        controller.create_card_requested.connect((parent_card_id) => {
            flowboard_new_card_requested(parent_card_id);
        });
        controller.toast_requested.connect((message) => {
            toast_requested(message);
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

    public async void refresh_git_provider_catalog() {
        if (api == null || git_catalog_list == null) {
            return;
        }
        clear_list_box(git_catalog_list);
        try {
            var providers = yield api.list_git_provider_catalog();
            if (providers.size == 0) {
                git_catalog_list.append(new Gtk.Label("No git providers in catalog.") { xalign = 0.0f });
                return;
            }
            foreach (var provider in providers) {
                var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
                var title = "%s (%s)".printf(provider.name, provider.id);
                var title_label = new Gtk.Label(title) { xalign = 0.0f };
                title_label.add_css_class("title-5");
                var detail = "kind=%s default=%s".printf(
                    provider.kind,
                    provider.preferred_transport.length > 0 ? provider.preferred_transport : "-"
                );
                var detail_label = new Gtk.Label(detail) { xalign = 0.0f };
                detail_label.add_css_class("dim-label");
                detail_label.set_wrap(true);
                row.append(title_label);
                row.append(detail_label);
                if (provider.transports_summary.length > 0) {
                    var transports = new Gtk.Label("transports: %s".printf(provider.transports_summary)) { xalign = 0.0f };
                    transports.add_css_class("caption");
                    transports.add_css_class("dim-label");
                    transports.set_wrap(true);
                    row.append(transports);
                }
                git_catalog_list.append(row);
            }
            log_debug("Git providers catalog refreshed: %d providers".printf(providers.size));
        } catch (Error e) {
            log_debug("Git providers catalog refresh failed: %s".printf(e.message));
            error_reported("Git providers catalog refresh failed", e.message);
        }
    }

    public void refresh_catalogs() {
        refresh_ai_catalog.begin();
        refresh_git_provider_catalog.begin();
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

        flowboard = new FlowboardPane();
        var flowboard_page = stack.add_titled(flowboard.widget, "flowboard", "Flowboard");
        flowboard_page.set_icon_name("view-grid-symbolic");

        connections_tool = new ConnectionsToolView();
        connections_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        connections_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        connections_tool.debug_log_requested.connect((line) => {
            log_debug(line);
        });
        connections_tool.set_api_client(api);
        connections_tool.set_settings(settings);
        if (project_selection != null && card_store != null && card_selection != null) {
            connections_tool.bind_context(project_selection, card_store, card_selection);
        }

        var connections_page = stack.add_titled(connections_tool.widget, "connections", "Connections");
        connections_page.set_icon_name("network-wired-symbolic");

        resources_tool = new ResourcesToolView();
        resources_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        resources_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        resources_tool.set_api_client(api);
        resources_tool.set_project_selection(project_selection);
        var resources_page = stack.add_titled(resources_tool.widget, "resources", "Resources");
        resources_page.set_icon_name("view-list-symbolic");

        var sharing_page = stack.add_titled(
            build_sharing_tab(),
            "sharing",
            "Sharing"
        );
        sharing_page.set_icon_name("emblem-shared-symbolic");

        var terminals_page = stack.add_titled(build_terminal_tab(), "terminals", "Terminals");
        terminals_page.set_icon_name("utilities-terminal-symbolic");

        var catalog_page = stack.add_titled(build_ai_catalog_tab(), "catalog", "AI Catalog");
        catalog_page.set_icon_name("x-office-address-book-symbolic");

        git_sync_tool = new GitSyncToolView();
        git_sync_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        git_sync_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        git_sync_tool.set_api_client(api);
        git_sync_tool.set_settings(settings);
        git_sync_tool.set_project_selection(project_selection);

        var git_page = stack.add_titled(git_sync_tool.widget, "git", "Git Sync");
        git_page.set_icon_name("folder-remote-symbolic");

        var recovery_page = stack.add_titled(build_recovery_key_tab(), "recovery", "Recovery Key");
        recovery_page.set_icon_name("dialog-password-symbolic");

        var trash_page = stack.add_titled(
            build_placeholder_tab("Trash tools are scaffolded and planned."),
            "trash",
            "Trash"
        );
        trash_page.set_icon_name("user-trash-symbolic");

        var debug_page = stack.add_titled(build_debug_tab(), "debug", "Debug");
        debug_page.set_icon_name("view-reveal-symbolic");

        stack.set_visible_child_name("flowboard");
        stack.notify["visible-child"].connect(() => {
            var visible = stack.get_visible_child();
            if (visible == null) {
                title.set_label("Toolbox");
                return;
            }
            var page = stack.get_page(visible);
            if (page == null || page.title == null || page.title.length == 0) {
                title.set_label("Toolbox");
                return;
            }
            title.set_label("Toolbox: %s".printf(page.title));
        });
        var initial_visible = stack.get_visible_child();
        if (initial_visible != null) {
            var initial_page = stack.get_page(initial_visible);
            if (initial_page != null && initial_page.title != null && initial_page.title.length > 0) {
                title.set_label("Toolbox: %s".printf(initial_page.title));
            }
        }

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_min_content_height(180);
        scroller.set_child(stack);
        frame.append(scroller);

        return frame;
    }

    public void set_connections_internal_links(Gee.ArrayList<string> link_targets) {
        if (connections_tool != null) {
            connections_tool.set_internal_links(link_targets);
        }
    }

    private Gtk.Widget build_placeholder_tab(string message) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var info = new Gtk.Label(message) { xalign = 0.0f };
        info.set_wrap(true);
        info.add_css_class("dim-label");
        box.append(info);
        return box;
    }

    private Gtk.Widget build_sharing_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        var info = new Gtk.Label(
            "Share the currently selected card using desktop integrations."
        ) { xalign = 0.0f };
        info.set_wrap(true);
        info.add_css_class("dim-label");
        root.append(info);

        sharing_email_btn = new Gtk.Button.with_label("Send card as email");
        sharing_email_btn.set_halign(Gtk.Align.START);
        sharing_email_btn.clicked.connect(() => {
            send_card_as_email_requested();
        });
        root.append(sharing_email_btn);

        refresh_sharing_action_state();
        return root;
    }

    private Gtk.Widget build_recovery_key_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var info = new Gtk.Label(
            "Keep a copy of your recovery key somewhere safe in case your computer is lost or damaged. " +
            "Email it to yourself, or store it on a USB stick."
        ) { xalign = 0.0f };
        info.set_wrap(true);
        info.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        info.add_css_class("dim-label");
        root.append(info);

        var email_btn = new Gtk.Button.with_label("Email Recovery Key");
        email_btn.set_halign(Gtk.Align.START);
        email_btn.clicked.connect(() => {
            send_recovery_key_as_email_requested();
        });
        root.append(email_btn);

        var usb_btn = new Gtk.Button.with_label("Save Recovery Key to USB Drive");
        usb_btn.set_halign(Gtk.Align.START);
        usb_btn.clicked.connect(() => {
            save_recovery_key_to_usb_requested();
        });
        root.append(usb_btn);

        var import_btn = new Gtk.Button.with_label("Import Recovery Key");
        import_btn.set_halign(Gtk.Align.START);
        import_btn.clicked.connect(() => {
            import_recovery_key_requested();
        });
        root.append(import_btn);

        return root;
    }

    private void refresh_sharing_action_state() {
        if (sharing_email_btn == null) {
            return;
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        sharing_email_btn.set_sensitive(selected_card != null);
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

        var copy_to_card_action = new SimpleAction("copy-to-card", null);
        copy_to_card_action.activate.connect(() => {
            var text = terminal.get_text_selected(Vte.Format.TEXT);
            if (text == null || text.strip().length == 0) {
                toast_requested("Select terminal text first.");
                return;
            }
            terminal_copy_to_card_requested(text);
        });
        actions.add_action(copy_to_card_action);

        var copy_all_to_card_action = new SimpleAction("copy-all-to-card", null);
        copy_all_to_card_action.activate.connect(() => {
            terminal.select_all();
            var text = terminal.get_text_selected(Vte.Format.TEXT);
            terminal.unselect_all();
            if (text == null || text.strip().length == 0) {
                toast_requested("Terminal has no text to copy.");
                return;
            }
            terminal_copy_to_card_requested(text);
        });
        actions.add_action(copy_all_to_card_action);

        terminal.insert_action_group("terminal", actions);

        var menu = new GLib.Menu();
        menu.append("Copy", "terminal.copy");
        menu.append("Paste", "terminal.paste");
        menu.append("Select All", "terminal.select-all");
        menu.append("Copy to Card", "terminal.copy-to-card");
        menu.append("Copy All to Card", "terminal.copy-all-to-card");
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
