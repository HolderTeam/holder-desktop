namespace HolderLinux {

public class ToolboxPane : Object {
    private ConnectionsToolView connections_tool;
    private GitSyncToolView git_sync_tool;
    private RecoveryKeyToolView recovery_key_tool;
    private ResourcesToolView resources_tool;
    private SharingToolView sharing_tool;
    private DebugToolView debug_tool;
    private TerminalToolView terminal_tool;
    private FlowboardToolView flowboard_tool;
    private TrashToolView trash_tool;
    private Gtk.Stack? toolbox_stack;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    public Gtk.Revealer widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void flowboard_card_open_requested(string card_id);
    public signal void flowboard_card_move_to_trash_requested(string card_id);
    public signal void flowboard_move_intent_requested(string card_id,
                                                       string project_id,
                                                       string intent,
                                                       string? target_card_id,
                                                       string? parent_card_id);
    public signal void flowboard_new_card_requested(string? parent_card_id);
    public signal void send_card_as_email_requested();
    public signal void send_recovery_key_as_email_requested();
    public signal void save_recovery_key_to_usb_requested();
    public signal void import_recovery_key_requested();
    public signal void terminal_copy_to_card_requested(string text);
    public signal void connections_project_overview_requested(string project_id);
    public signal void connections_projects_root_requested();

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
        if (trash_tool != null) {
            trash_tool.set_api_client(api);
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
        if (trash_tool != null) {
            trash_tool.set_project_selection(project_selection);
        }
    }

    public void bind_flowboard_controller(FlowboardController controller) {
        if (flowboard_tool == null) {
            return;
        }
        flowboard_tool.bind_controller(controller);
    }

    public void set_reveal_child(bool reveal) {
        widget.set_reveal_child(reveal);
    }

    public void log_debug(string line) {
        if (debug_tool != null) {
            debug_tool.append_log_line(line);
        }
    }

    private void bind_flowboard_listener_signals() {
        flowboard_tool.card_open_requested.connect((card_id) => {
            flowboard_card_open_requested(card_id);
        });
        flowboard_tool.card_move_to_trash_requested.connect((card_id) => {
            flowboard_card_move_to_trash_requested(card_id);
        });
        flowboard_tool.move_intent_requested.connect((card_id, project_id, intent, target_card_id, parent_card_id) => {
            flowboard_move_intent_requested(card_id, project_id, intent, target_card_id, parent_card_id);
        });
        flowboard_tool.new_card_requested.connect((parent_card_id) => {
            flowboard_new_card_requested(parent_card_id);
        });
        flowboard_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
    }

    public void refresh_trash() {
        if (trash_tool != null) {
            trash_tool.refresh();
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
        toolbox_stack = stack;
        stack.set_vexpand(true);
        stack.set_hexpand(true);
        switcher.set_stack(stack);
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

        flowboard_tool = new FlowboardToolView();
        bind_flowboard_listener_signals();
        var flowboard_page = stack.add_titled(flowboard_tool.widget, "flowboard", "Flowboard");
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
        connections_tool.project_overview_requested.connect((project_id) => {
            connections_project_overview_requested(project_id);
        });
        connections_tool.projects_root_requested.connect(() => {
            connections_projects_root_requested();
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

        terminal_tool = new TerminalToolView();
        terminal_tool.debug_log_requested.connect((line) => {
            log_debug(line);
        });
        terminal_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        terminal_tool.copy_to_card_requested.connect((text) => {
            terminal_copy_to_card_requested(text);
        });
        var terminals_page = stack.add_titled(terminal_tool.widget, "terminals", "Terminals");
        terminals_page.set_icon_name("utilities-terminal-symbolic");

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

        recovery_key_tool = new RecoveryKeyToolView();
        recovery_key_tool.send_recovery_key_as_email_requested.connect(() => {
            send_recovery_key_as_email_requested();
        });
        recovery_key_tool.save_recovery_key_to_usb_requested.connect(() => {
            save_recovery_key_to_usb_requested();
        });
        recovery_key_tool.import_recovery_key_requested.connect(() => {
            import_recovery_key_requested();
        });
        var recovery_page = stack.add_titled(recovery_key_tool.widget, "recovery", "Recovery Key");
        recovery_page.set_icon_name("dialog-password-symbolic");

        trash_tool = new TrashToolView();
        trash_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        trash_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        trash_tool.breadcrumb_activated.connect((index) => {
            if (index == 0) {
                flowboard_tool.show_projects_root();
            }
            if (index < 2 && toolbox_stack != null) {
                toolbox_stack.set_visible_child_name("flowboard");
            }
        });
        trash_tool.set_api_client(api);
        trash_tool.set_project_selection(project_selection);
        var trash_page = stack.add_titled(trash_tool.widget, "trash", "Trash");
        trash_page.set_icon_name("user-trash-symbolic");

        debug_tool = new DebugToolView();
        var debug_page = stack.add_titled(debug_tool.widget, "debug", "Debug");
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
            if (page.title == "Trash") {
                refresh_trash();
            }
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

    private Gtk.Widget build_sharing_tab() {
        sharing_tool = new SharingToolView();
        sharing_tool.send_card_as_email_requested.connect(() => {
            send_card_as_email_requested();
        });
        refresh_sharing_action_state();
        return sharing_tool.widget;
    }

    private void refresh_sharing_action_state() {
        if (sharing_tool == null) {
            return;
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        sharing_tool.set_has_selected_card(selected_card != null);
    }

}

}
