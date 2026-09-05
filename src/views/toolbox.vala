namespace HolderLinux {

public class ToolboxPane : Object {
    private ConnectionsToolView connections_tool;
    private TagsToolView tags_tool;
    private GitSyncToolView git_sync_tool;
    private RecoveryKeyToolView recovery_key_tool;
    private ResourcesToolView resources_tool;
    private MilestonesToolView milestones_tool;
    private HistoryToolView history_tool;
    private SharingToolView sharing_tool;
    private DebugToolView debug_tool;
    private TerminalToolView terminal_tool;
    private FlowboardToolView flowboard_tool;
    private TrashToolView trash_tool;
    private Gee.HashMap<string, IToolShellAdapter> tool_adapters;
    private ToolShell? tool_shell;
    private Gtk.Stack? toolbox_stack;
    private NavigationBreadcrumbs? header_breadcrumbs;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    private ActivityLogStore? activity_log_store;
    private bool navigation_loading = false;
    public Gtk.Revealer widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void flowboard_card_open_requested(string card_id);
    public signal void connections_card_open_requested(string card_id);
    public signal void tags_card_open_requested(string card_id);
    public signal void resources_card_open_requested(string card_id);
    public signal void milestones_card_open_requested(string card_id);
    public signal void resource_references_requested(ProjectResource resource);
    public signal void asset_preview_requested(ProjectResource resource, ResourceAsset asset);
    public signal void project_resources_loaded(string project_id,
                                                Gee.ArrayList<ProjectResource> resources);
    public signal void connections_card_create_child_requested(string card_id);
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
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? card_id,
                                          ActivityDetails? details);
    public signal void breadcrumb_navigation_requested(string tool_id,
                                                       int segment_index,
                                                       string? project_id,
                                                       string? card_id);

    public ToolboxPane() {
        tool_adapters = new Gee.HashMap<string, IToolShellAdapter>();
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
        if (tags_tool != null) {
            tags_tool.set_api_client(api);
        }
        if (git_sync_tool != null) {
            git_sync_tool.set_api_client(api);
        }
        if (resources_tool != null) {
            resources_tool.set_api_client(api);
        }
        if (milestones_tool != null) {
            milestones_tool.set_api_client(api);
        }
        if (history_tool != null) {
            history_tool.set_api_client(api);
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

    public void set_activity_log_store(ActivityLogStore store) {
        activity_log_store = store;
        if (debug_tool != null) {
            debug_tool.bind_activity_log(store);
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
        if (tags_tool != null) {
            tags_tool.bind_context(project_selection, card_selection);
        }
        if (milestones_tool != null) {
            milestones_tool.bind_context(project_selection, card_store, card_selection);
        }
        if (history_tool != null) {
            history_tool.bind_context(project_selection, card_selection);
        }
        if (terminal_tool != null) {
            terminal_tool.bind_context(project_selection, card_selection);
        }

        project_selection.notify["selected"].connect(() => {
            refresh_sharing_action_state();
            apply_shell_state();
        });
        card_selection.notify["selected"].connect(() => {
            refresh_sharing_action_state();
            apply_shell_state();
        });
        card_store.items_changed.connect((position, removed, added) => {
            refresh_sharing_action_state();
            apply_shell_state();
        });
        refresh_sharing_action_state();
        apply_shell_state();
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

    public bool terminal_captures_application_shortcuts(Gtk.Widget? focus) {
        return terminal_tool != null &&
            terminal_tool.captures_application_shortcuts(focus);
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

    public void refresh_resources(string? select_resource_id = null) {
        if (resources_tool != null) {
            resources_tool.request_refresh(select_resource_id);
        }
    }

    public void refresh_milestones() {
        if (milestones_tool != null) {
            milestones_tool.refresh();
        }
    }

    public void refresh_history(string project_id, string card_id) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project : null;
        var card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary : null;
        if (history_tool != null && project != null && card != null &&
            project.project_id == project_id && card.card_id == card_id) {
            history_tool.refresh();
        }
    }

    public void show_flowboard_projects_root() {
        if (flowboard_tool == null) {
            return;
        }
        flowboard_tool.show_projects_root();
        apply_shell_state();
    }

    public void show_flowboard_project_root() {
        if (flowboard_tool == null) {
            return;
        }
        flowboard_tool.show_project_root();
        apply_shell_state();
    }

    public void show_connections_projects_root() {
        if (connections_tool == null) {
            return;
        }
        connections_tool.navigate_to_projects_root.begin(null);
        apply_shell_state();
    }

    public void set_navigation_loading(bool loading) {
        navigation_loading = loading;
        apply_shell_state();
    }

    private Gtk.Widget build_ui() {
        var frame = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        frame.update_property(Gtk.AccessibleProperty.LABEL, "Toolbox", -1);
        frame.set_margin_top(6);
        frame.set_margin_bottom(6);
        frame.set_margin_start(6);
        frame.set_margin_end(6);
        frame.add_css_class("toolbar");

        var switcher = new Gtk.StackSwitcher();
        switcher.update_property(Gtk.AccessibleProperty.LABEL, "Toolbox tool switcher", -1);
        header_breadcrumbs = new NavigationBreadcrumbs();
        header_breadcrumbs.segment_activated.connect((index) => {
            on_header_breadcrumb_clicked(index);
        });
        tool_shell = new ToolShell((!) header_breadcrumbs, switcher);
        frame.append((!) tool_shell.widget);

        var stack = new Gtk.Stack();
        toolbox_stack = stack;
        stack.set_vexpand(true);
        stack.set_hexpand(true);
        switcher.set_stack(stack);
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

        flowboard_tool = new FlowboardToolView();
        tool_adapters.set("flowboard", flowboard_tool);
        bind_flowboard_listener_signals();
        var flowboard_page = stack.add_titled(flowboard_tool.widget, "flowboard", "Flowboard");
        flowboard_page.set_icon_name("view-grid-symbolic");

        connections_tool = new ConnectionsToolView();
        tool_adapters.set("connections", connections_tool);
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
            breadcrumb_navigation_requested("connections", 1, project_id, null);
        });
        connections_tool.projects_root_requested.connect(() => {
            breadcrumb_navigation_requested("connections", 0, null, null);
        });
        connections_tool.card_open_requested.connect((card_id) => {
            connections_card_open_requested(card_id);
        });
        connections_tool.card_create_child_requested.connect((card_id) => {
            connections_card_create_child_requested(card_id);
        });
        connections_tool.set_api_client(api);
        connections_tool.set_settings(settings);
        if (project_selection != null && card_store != null && card_selection != null) {
            connections_tool.bind_context(project_selection, card_store, card_selection);
        }

        var connections_page = stack.add_titled(connections_tool.widget, "connections", "Connections");
        connections_page.set_icon_name("network-wired-symbolic");
        connections_tool.set_tool_visible(false);

        tags_tool = new TagsToolView();
        tool_adapters.set("tags", tags_tool);
        tags_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        tags_tool.card_open_requested.connect((card_id) => {
            tags_card_open_requested(card_id);
        });
        tags_tool.set_api_client(api);
        if (project_selection != null && card_selection != null) {
            tags_tool.bind_context(project_selection, card_selection);
        }
        var tags_page = stack.add_titled(tags_tool.widget, "tags", "Tags");
        tags_page.set_icon_name("tag-symbolic");
        tags_tool.set_tool_visible(false);

        resources_tool = new ResourcesToolView();
        tool_adapters.set("resources", resources_tool);
        resources_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        resources_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        resources_tool.asset_preview_requested.connect((resource, asset) => {
            asset_preview_requested(resource, asset);
        });
        resources_tool.card_open_requested.connect((card_id) => {
            resources_card_open_requested(card_id);
        });
        resources_tool.resource_references_requested.connect((resource) => {
            resource_references_requested(resource);
        });
        resources_tool.project_resources_loaded.connect((project_id, resources) => {
            project_resources_loaded(project_id, resources);
        });
        resources_tool.activity_requested.connect((kind, message, project_id, resource_id, details) => {
            activity_requested(kind, message, project_id, resource_id, details);
        });
        resources_tool.set_api_client(api);
        resources_tool.set_project_selection(project_selection);
        var resources_page = stack.add_titled(resources_tool.widget, "resources", "Resources");
        resources_page.set_icon_name("view-list-symbolic");

        milestones_tool = new MilestonesToolView();
        tool_adapters.set("milestones", milestones_tool);
        milestones_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        milestones_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        milestones_tool.card_open_requested.connect((card_id) => {
            milestones_card_open_requested(card_id);
        });
        milestones_tool.set_api_client(api);
        if (project_selection != null && card_store != null && card_selection != null) {
            milestones_tool.bind_context(project_selection, card_store, card_selection);
        }
        var milestones_page = stack.add_titled(
            milestones_tool.widget, "milestones", "Milestones"
        );
        milestones_page.set_icon_name("x-office-calendar-symbolic");
        milestones_tool.set_tool_visible(false);

        history_tool = new HistoryToolView();
        tool_adapters.set("history", history_tool);
        history_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        history_tool.set_api_client(api);
        if (project_selection != null && card_selection != null) {
            history_tool.bind_context(project_selection, card_selection);
        }
        var history_page = stack.add_titled(history_tool.widget, "history", "History");
        history_page.set_icon_name("document-open-recent-symbolic");
        history_tool.set_tool_visible(false);

        var sharing_page = stack.add_titled(
            build_sharing_tab(),
            "sharing",
            "Sharing"
        );
        sharing_page.set_icon_name("emblem-shared-symbolic");

        terminal_tool = new TerminalToolView();
        tool_adapters.set("terminals", terminal_tool);
        terminal_tool.debug_log_requested.connect((line) => {
            log_debug(line);
        });
        terminal_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        terminal_tool.copy_to_card_requested.connect((text) => {
            terminal_copy_to_card_requested(text);
        });
        if (project_selection != null && card_selection != null) {
            terminal_tool.bind_context(project_selection, card_selection);
        }
        var terminals_page = stack.add_titled(terminal_tool.widget, "terminals", "Terminals");
        terminals_page.set_icon_name("utilities-terminal-symbolic");

        git_sync_tool = new GitSyncToolView();
        tool_adapters.set("git", git_sync_tool);
        git_sync_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        git_sync_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        git_sync_tool.repository_history_changed.connect((project_id) => {
            var card = card_selection != null
                ? card_selection.get_selected_item() as CardSummary : null;
            if (card != null) refresh_history(project_id, card.card_id);
        });
        git_sync_tool.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activity_requested(kind, message, project_id, card_id, details);
        });
        git_sync_tool.set_api_client(api);
        git_sync_tool.set_settings(settings);
        git_sync_tool.set_project_selection(project_selection);

        var git_page = stack.add_titled(git_sync_tool.widget, "git", "Git Sync");
        git_page.set_icon_name("folder-remote-symbolic");

        recovery_key_tool = new RecoveryKeyToolView();
        tool_adapters.set("recovery", recovery_key_tool);
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
        tool_adapters.set("trash", trash_tool);
        trash_tool.error_reported.connect((title_text, details) => {
            error_reported(title_text, details);
        });
        trash_tool.toast_requested.connect((message) => {
            toast_requested(message);
        });
        trash_tool.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activity_requested(kind, message, project_id, card_id, details);
        });
        trash_tool.set_api_client(api);
        trash_tool.set_project_selection(project_selection);
        var trash_page = stack.add_titled(trash_tool.widget, "trash", "Trash");
        trash_page.set_icon_name("user-trash-symbolic");

        debug_tool = new DebugToolView();
        if (activity_log_store != null) {
            debug_tool.bind_activity_log((!) activity_log_store);
        }
        tool_adapters.set("debug", debug_tool);
        var debug_page = stack.add_titled(debug_tool.widget, "debug", "Debug");
        debug_page.set_icon_name("view-reveal-symbolic");

        stack.set_visible_child_name("flowboard");
        stack.notify["visible-child"].connect(() => {
            var visible = stack.get_visible_child();
            var page = visible != null ? stack.get_page(visible) : null;
            if (connections_tool != null) {
                connections_tool.set_tool_visible(page != null && page.name == "connections");
            }
            if (tags_tool != null) {
                tags_tool.set_tool_visible(page != null && page.name == "tags");
            }
            if (milestones_tool != null) {
                milestones_tool.set_tool_visible(page != null && page.name == "milestones");
            }
            if (history_tool != null) {
                history_tool.set_tool_visible(page != null && page.name == "history");
            }
            apply_shell_state();
            if (page.title == "Trash") {
                refresh_trash();
            }
        });
        if (connections_tool != null) {
            var visible = stack.get_visible_child();
            var page = visible != null ? stack.get_page(visible) : null;
            connections_tool.set_tool_visible(page != null && page.name == "connections");
        }
        if (tags_tool != null) {
            var visible = stack.get_visible_child();
            var page = visible != null ? stack.get_page(visible) : null;
            tags_tool.set_tool_visible(page != null && page.name == "tags");
        }
        if (milestones_tool != null) {
            var visible = stack.get_visible_child();
            var page = visible != null ? stack.get_page(visible) : null;
            milestones_tool.set_tool_visible(page != null && page.name == "milestones");
        }
        apply_shell_state();

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_min_content_height(180);
        scroller.set_child(stack);
        ((!) tool_shell).set_content_widget(scroller);
        ((!) tool_shell).set_actions_widget(null);
        ((!) tool_shell).set_loading(navigation_loading);

        return frame;
    }

    public void set_connections_internal_links(Gee.ArrayList<string> link_targets) {
        if (connections_tool != null) {
            connections_tool.set_internal_links(link_targets);
        }
    }

    public void show_tool(string tool_id) {
        if (toolbox_stack == null || tool_id.strip().length == 0) {
            return;
        }
        ((!) toolbox_stack).set_visible_child_name(tool_id);
        apply_shell_state();
    }

    public void show_tag(string tag) {
        show_tool("tags");
        if (tags_tool != null) {
            tags_tool.show_tag(tag);
        }
    }

    public bool is_showing_tool(string tool_id) {
        return current_tool_id() == tool_id;
    }

    public void request_flowboard_child_or_current_level_card() {
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (selected_card != null) {
            flowboard_new_card_requested(selected_card.card_id);
            return;
        }
        if (flowboard_tool != null) {
            flowboard_tool.request_create_card_here();
        }
    }

    private Gtk.Widget build_sharing_tab() {
        sharing_tool = new SharingToolView();
        tool_adapters.set("sharing", sharing_tool);
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

    private void refresh_tool_actions_row() {
        if (tool_shell == null || toolbox_stack == null) {
            return;
        }
        var child = toolbox_stack.get_visible_child();
        if (child == null) {
            ((!) tool_shell).set_actions_widget(null);
            return;
        }
        var page = toolbox_stack.get_page(child);
        if (page == null || page.name == null) {
            ((!) tool_shell).set_actions_widget(null);
            return;
        }
        var adapter = tool_adapters.get(page.name);
        if (adapter != null) {
            ((!) tool_shell).set_actions_widget(adapter.get_actions_widget());
            return;
        }
        ((!) tool_shell).set_actions_widget(null);
    }

    private void apply_shell_state() {
        refresh_tool_actions_row();
        refresh_header_breadcrumbs();
        if (tool_shell != null) {
            ((!) tool_shell).set_loading(navigation_loading);
        }
    }

    private void refresh_header_breadcrumbs() {
        if (header_breadcrumbs == null) {
            return;
        }

        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;

        var page_name = current_tool_id();
        var adapter = tool_adapters.get(page_name);
        if (adapter != null) {
            var snapshot = adapter.get_scope_snapshot(selected_project, selected_card);
            var segments_adapter = new Gee.ArrayList<NavigationBreadcrumbSegment>();
            segments_adapter.add(new NavigationBreadcrumbSegment(
                snapshot.tool_label,
                true,
                true,
                0
            ));
            segments_adapter.add(new NavigationBreadcrumbSegment(
                snapshot.project_label,
                false,
                snapshot.project_id != null,
                1
            ));
            segments_adapter.add(new NavigationBreadcrumbSegment(
                snapshot.card_label,
                false,
                snapshot.card_id != null,
                2
            ));
            ((!) header_breadcrumbs).set_segments(segments_adapter);
            return;
        }

        string tool_name = "Tool";
        if (toolbox_stack != null) {
            var visible = toolbox_stack.get_visible_child();
            if (visible != null) {
                var page = toolbox_stack.get_page(visible);
                if (page != null && page.title != null && page.title.strip().length > 0) {
                    tool_name = page.title;
                }
            }
        }
        string project_name = selected_project != null && selected_project.name.strip().length > 0
            ? selected_project.name
            : "(none)";
        string card_name = selected_card != null &&
            (selected_project == null || selected_card.project_id == selected_project.project_id) &&
            selected_card.title.strip().length > 0
            ? selected_card.title
            : "Overview";

        var segments = new Gee.ArrayList<NavigationBreadcrumbSegment>();
        segments.add(new NavigationBreadcrumbSegment(tool_name, true, true, 0));
        segments.add(new NavigationBreadcrumbSegment(project_name, false, selected_project != null, 1));
        segments.add(new NavigationBreadcrumbSegment(card_name, false, selected_card != null, 2));
        ((!) header_breadcrumbs).set_segments(segments);
    }

    private void on_header_breadcrumb_clicked(int segment_index) {
        var tool_id = current_tool_id();
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        var adapter = tool_adapters.get(tool_id);
        if (adapter != null) {
            var snapshot = adapter.get_scope_snapshot(selected_project, selected_card);
            breadcrumb_navigation_requested(
                tool_id,
                segment_index,
                snapshot.project_id,
                snapshot.card_id
            );
            return;
        }

        breadcrumb_navigation_requested(
            tool_id,
            segment_index,
            selected_project != null ? selected_project.project_id : null,
            selected_card != null ? selected_card.card_id : null
        );
    }

    private string current_tool_id() {
        if (toolbox_stack == null) {
            return "tool";
        }
        var child = toolbox_stack.get_visible_child();
        if (child == null) {
            return "tool";
        }
        var page = toolbox_stack.get_page(child);
        if (page == null || page.name == null || page.name.strip().length == 0) {
            return "tool";
        }
        return page.name;
    }

}

}
