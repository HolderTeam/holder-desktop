namespace HolderLinux {

public class ToolboxPane : Object {
    private const int GRAPH_BLOCK_MARGIN_START = 0;
    private const int GRAPH_ACTION_COL_WIDTH = 24;
    private const int GRAPH_CONTENT_GAP = 14;
    private const int GRAPH_KIND_EXTRA_INDENT = 10;
    private const int GRAPH_TEXT_START = GRAPH_BLOCK_MARGIN_START + GRAPH_ACTION_COL_WIDTH + GRAPH_CONTENT_GAP;
    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    private Gtk.Label connections_card_title_label;
    private Gtk.Label connections_internal_links_label;
    private Gtk.ListBox connections_graph_outgoing_list;
    private Gtk.ListBox connections_graph_backlinks_list;
    private Gtk.Label connections_graph_outgoing_empty_label;
    private Gtk.Label connections_graph_backlinks_empty_label;
    private Gtk.Button connections_add_graph_link_btn;
    private Gtk.TextBuffer debug_buffer;
    private Gtk.TextView debug_view;
    private Gtk.Label connections_structure_label;
    private Gtk.Button sharing_email_btn;
    private GLib.ListStore resources_store;
    private Gtk.SingleSelection resources_selection;
    private Gtk.SearchEntry resources_search_entry;
    private Gtk.Label resources_empty_label;
    private Gtk.Button resources_open_btn;
    private Gtk.Button resources_edit_btn;
    private Gtk.Button resources_delete_btn;
    private Gee.ArrayList<ProjectResource> all_resources = new Gee.ArrayList<ProjectResource>();
    private uint resources_refresh_serial = 0;
    private Gtk.ListBox ai_catalog_list;
    private Gtk.ListBox git_catalog_list;
    private Gtk.Notebook terminal_notebook;
    private int next_terminal_index = 1;
    private Gtk.Entry git_remote_entry;
    private Gtk.Entry git_branch_entry;
    private Gtk.Button git_manual_save_btn;
    private Gtk.Label git_manual_status_label;
    private Gtk.DropDown git_provider_dropdown;
    private Gtk.StringList git_provider_name_model;
    private Gee.ArrayList<GitProviderCatalogEntry> git_provider_entries = new Gee.ArrayList<GitProviderCatalogEntry>();
    private Gtk.DropDown git_provider_transport_dropdown;
    private Gtk.Entry git_provider_namespace_entry;
    private Gtk.Entry git_provider_repo_entry;
    private Gtk.Box git_provider_host_row;
    private Gtk.Entry git_provider_host_entry;
    private Gtk.Entry git_provider_remote_entry;
    private Gtk.Entry git_provider_branch_entry;
    private Gtk.Label git_provider_status_label;
    private Gtk.Label git_provider_template_label;
    private Gtk.Button git_provider_apply_btn;
    private Gtk.Stack git_sync_stack;
    private Gtk.Label git_gh_cli_status_label;
    private Gtk.Button git_gh_cli_auto_btn;
    private Gtk.Button git_gh_cli_guided_btn;
    private Gtk.Entry git_guided_username_entry;
    private Gtk.Button git_guided_next_btn;
    private Gtk.Label git_guided_ssh_status_label;
    private Gtk.Entry git_guided_email_entry;
    private Gtk.Button git_guided_generate_key_btn;
    private Gtk.Button git_guided_copy_key_btn;
    private Gtk.TextView git_guided_pubkey_view;
    private Gtk.Entry git_guided_repo_name_entry;
    private Gtk.Label git_guided_repo_mode_label;
    private Gtk.Label git_guided_repo_manual_label;
    private Gtk.LinkButton git_guided_repo_create_link;
    private Gtk.Label git_guided_repo_manual_instructions_label;
    private Gtk.Label git_guided_repo_status_label;
    private Gtk.Button git_guided_repo_next_btn;
    private Gtk.Label git_guided_push_intro_label;
    private Gtk.Label git_guided_push_status_label;
    private Gtk.Button git_guided_push_btn;
    private string git_guided_part4_username = "";
    private string git_guided_part4_repo_name = "";
    private Gtk.Box git_guided_missing_key_box;
    private Gtk.Box git_guided_key_ready_box;
    private Gtk.Button git_guided_open_keys_btn;
    private string git_guided_public_key = "";
    private bool git_guided_check_running = false;
    private bool git_guided_github_authenticated = false;
    private Gtk.Button git_guided_create_repo_cli_btn;
    private bool git_gh_available = false;
    private bool git_gh_authenticated = false;
    private string git_gh_login = "";
    private FlowboardPane flowboard;
    private FlowboardController? flowboard_controller;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    private uint connections_graph_refresh_serial = 0;
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
        ensure_connections_css();
        widget.set_child(build_ui());
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_connections_graph_refresh();
        queue_resources_refresh();
    }

    public void set_settings(Settings? settings) {
        this.settings = settings;
        refresh_guided_github_username();
        check_github_cli_state.begin();
    }

    public void bind_connections_context(Gtk.SingleSelection project_selection,
                                         GLib.ListStore card_store,
                                         Gtk.SingleSelection card_selection) {
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.card_selection = card_selection;

        project_selection.notify["selected"].connect(() => {
            refresh_connections_structure();
            queue_connections_graph_refresh();
            queue_resources_refresh();
            refresh_sharing_action_state();
            refresh_guided_repo_name_default();
            refresh_provider_setup_defaults();
        });
        card_selection.notify["selected"].connect(() => {
            refresh_connections_structure();
            queue_connections_graph_refresh();
            refresh_sharing_action_state();
        });
        card_store.items_changed.connect((position, removed, added) => {
            refresh_connections_structure();
            queue_connections_graph_refresh();
            refresh_sharing_action_state();
        });
        refresh_connections_structure();
        queue_connections_graph_refresh();
        queue_resources_refresh();
        refresh_sharing_action_state();
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

        var connections_page = stack.add_titled(build_connections_tab(), "connections", "Connections");
        connections_page.set_icon_name("network-wired-symbolic");

        var resources_page = stack.add_titled(build_resources_tab(), "resources", "Resources");
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

        var git_page = stack.add_titled(build_git_sync_tab(), "git", "Git Sync");
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

    private Gtk.Widget build_connections_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        var columns = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        root.append(columns);

        var graph_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        graph_column.set_margin_top(6);
        graph_column.set_margin_bottom(6);
        graph_column.set_margin_start(6);
        graph_column.set_margin_end(6);

        var context_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        context_column.set_margin_top(6);
        context_column.set_margin_bottom(6);
        context_column.set_margin_start(6);
        context_column.set_margin_end(6);

        var graph_scroller = new Gtk.ScrolledWindow();
        graph_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        graph_scroller.set_hexpand(true);
        graph_scroller.set_vexpand(true);
        graph_scroller.set_child(graph_column);

        var context_scroller = new Gtk.ScrolledWindow();
        context_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        context_scroller.set_size_request(200, -1);
        context_scroller.set_hexpand(false);
        context_scroller.set_vexpand(true);
        context_scroller.set_child(context_column);
        columns.append(context_scroller);

        var divider = new Gtk.Separator(Gtk.Orientation.VERTICAL);
        columns.append(divider);

        columns.append(graph_scroller);
        columns.append(context_scroller);

        connections_card_title_label = new Gtk.Label("No card selected") { xalign = 0.0f };
        connections_card_title_label.add_css_class("title-5");
        connections_card_title_label.set_ellipsize(Pango.EllipsizeMode.END);
        connections_card_title_label.set_max_width_chars(30);
        connections_card_title_label.set_margin_top(10);
        connections_card_title_label.set_margin_start(0);
        connections_structure_label = new Gtk.Label("") { xalign = 0.0f };
        connections_structure_label.set_wrap(true);
        connections_structure_label.set_use_markup(true);
        connections_structure_label.set_lines(4);
        connections_structure_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_structure_label.set_yalign(0.0f);
        connections_structure_label.set_margin_top(4);
        connections_structure_label.set_margin_start(0);
        connections_structure_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_internal_links_label = new Gtk.Label("Internal Links:") { xalign = 0.0f };
        connections_internal_links_label.set_wrap(true);
        connections_internal_links_label.set_use_markup(true);
        connections_internal_links_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_internal_links_label.set_yalign(0.0f);
        connections_internal_links_label.set_margin_top(4);
        connections_internal_links_label.set_margin_start(0);
        connections_internal_links_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        context_column.append(connections_card_title_label);
        context_column.append(connections_structure_label);
        context_column.append(connections_internal_links_label);

        var graph_header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var graph_title = new Gtk.Label("Graph Connections") { xalign = 0.0f };
        graph_title.add_css_class("title-5");
        graph_title.set_margin_start(GRAPH_TEXT_START);
        graph_title.set_hexpand(true);
        connections_add_graph_link_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        connections_add_graph_link_btn.set_tooltip_text("Add graph link");
        connections_add_graph_link_btn.set_sensitive(false);
        connections_add_graph_link_btn.clicked.connect(() => {
            open_add_graph_link_dialog();
        });
        graph_header.append(graph_title);
        graph_header.append(connections_add_graph_link_btn);
        graph_column.append(graph_header);

        var outgoing_title = new Gtk.Label("Outgoing") { xalign = 0.0f };
        outgoing_title.add_css_class("heading");
        outgoing_title.set_margin_start(GRAPH_TEXT_START);
        graph_column.append(outgoing_title);
        connections_graph_outgoing_empty_label = new Gtk.Label("Select a card to view graph links.") { xalign = 0.0f };
        connections_graph_outgoing_empty_label.add_css_class("dim-label");
        connections_graph_outgoing_empty_label.set_wrap(true);
        connections_graph_outgoing_empty_label.set_margin_start(GRAPH_TEXT_START);
        graph_column.append(connections_graph_outgoing_empty_label);
        connections_graph_outgoing_list = new Gtk.ListBox();
        connections_graph_outgoing_list.set_selection_mode(Gtk.SelectionMode.NONE);
        connections_graph_outgoing_list.add_css_class("connections-graph-list");
        graph_column.append(connections_graph_outgoing_list);

        var backlinks_title = new Gtk.Label("Incoming") { xalign = 0.0f };
        backlinks_title.add_css_class("heading");
        backlinks_title.set_margin_start(GRAPH_TEXT_START);
        graph_column.append(backlinks_title);
        connections_graph_backlinks_empty_label = new Gtk.Label("Select a card to view graph links.") { xalign = 0.0f };
        connections_graph_backlinks_empty_label.add_css_class("dim-label");
        connections_graph_backlinks_empty_label.set_wrap(true);
        connections_graph_backlinks_empty_label.set_margin_start(GRAPH_TEXT_START);
        graph_column.append(connections_graph_backlinks_empty_label);
        connections_graph_backlinks_list = new Gtk.ListBox();
        connections_graph_backlinks_list.set_selection_mode(Gtk.SelectionMode.NONE);
        connections_graph_backlinks_list.add_css_class("connections-graph-list");
        graph_column.append(connections_graph_backlinks_list);

        refresh_connections_structure();
        set_graph_empty_state(
            "Select a card to view graph links.",
            "Select a card to view graph links."
        );
        return root;
    }

    public void set_connections_internal_links(Gee.ArrayList<string> link_targets) {
        if (connections_internal_links_label == null) {
            return;
        }
        if (link_targets == null || link_targets.size == 0) {
            connections_internal_links_label.set_visible(false);
            return;
        }
        connections_internal_links_label.set_visible(true);
        var builder = new StringBuilder("Internal Links:");
        foreach (var target in link_targets) {
            builder.append(" ");
            builder.append(link_markup("ilink", target, target));
        }
        connections_internal_links_label.set_markup(builder.str);
    }

    private Gtk.Widget build_resources_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        resources_search_entry = new Gtk.SearchEntry();
        resources_search_entry.set_placeholder_text("Filter resources...");
        resources_search_entry.set_hexpand(true);
        resources_search_entry.search_changed.connect(() => {
            apply_resources_filter();
        });
        header.append(resources_search_entry);

        var add_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        add_btn.set_tooltip_text("Add resource");
        add_btn.clicked.connect(() => {
            open_resource_dialog(null);
        });
        header.append(add_btn);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh resources");
        refresh_btn.clicked.connect(() => {
            queue_resources_refresh();
        });
        header.append(refresh_btn);
        root.append(header);

        resources_store = new GLib.ListStore(typeof(ProjectResource));
        resources_selection = new Gtk.SingleSelection(resources_store);
        resources_selection.set_autoselect(false);
        resources_selection.notify["selected-item"].connect(() => {
            refresh_resource_action_state();
        });

        var view = new Gtk.ColumnView(resources_selection);
        view.set_vexpand(true);
        view.append_column(build_resource_text_column("Label", "label"));
        view.append_column(build_resource_text_column("Kind", "kind"));
        view.append_column(build_resource_text_column("URI", "uri"));
        view.append_column(build_resource_text_column("Desc", "desc"));
        view.append_column(build_resource_text_column("Updated", "updated"));

        var scroller = new Gtk.ScrolledWindow();
        scroller.set_vexpand(true);
        scroller.set_child(view);
        root.append(scroller);

        resources_empty_label = new Gtk.Label("No resources in this project.") { xalign = 0.0f };
        resources_empty_label.add_css_class("dim-label");
        resources_empty_label.set_visible(false);
        root.append(resources_empty_label);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        resources_open_btn = new Gtk.Button.with_label("Open");
        resources_open_btn.clicked.connect(() => {
            open_selected_resource();
        });
        actions.append(resources_open_btn);

        resources_edit_btn = new Gtk.Button.with_label("Edit");
        resources_edit_btn.clicked.connect(() => {
            var selected = selected_resource();
            if (selected != null) {
                open_resource_dialog(selected);
            }
        });
        actions.append(resources_edit_btn);

        resources_delete_btn = new Gtk.Button.with_label("Delete");
        resources_delete_btn.add_css_class("destructive-action");
        resources_delete_btn.clicked.connect(() => {
            confirm_delete_selected_resource();
        });
        actions.append(resources_delete_btn);
        root.append(actions);

        refresh_resource_action_state();
        return root;
    }

    private Gtk.ColumnViewColumn build_resource_text_column(string title, string field) {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }
            var label = new Gtk.Label("") { xalign = 0.0f };
            label.set_wrap(false);
            label.set_ellipsize(Pango.EllipsizeMode.END);
            item.set_child(label);
        });
        factory.bind.connect((item_obj) => {
            var item = item_obj as Gtk.ListItem;
            if (item == null) {
                return;
            }
            var resource = item.get_item() as ProjectResource;
            var label = item.get_child() as Gtk.Label;
            if (resource == null || label == null) {
                return;
            }
            switch (field) {
                case "label":
                    label.set_text(ellipsize_connections_title(resource.label));
                    label.set_tooltip_text(resource.label);
                    break;
                case "kind":
                    label.set_text(resource.kind);
                    label.set_tooltip_text(resource.kind);
                    break;
                case "uri":
                    label.set_text(ellipsize_connections_title(resource.uri));
                    label.set_tooltip_text(resource.uri);
                    break;
                case "desc":
                    var desc = resource.desc ?? "";
                    label.set_text(ellipsize_connections_title(desc));
                    label.set_tooltip_text(desc);
                    break;
                case "updated":
                    label.set_text(format_epoch(resource.updated_at));
                    label.set_tooltip_text(resource.updated_at.to_string());
                    break;
                default:
                    label.set_text("");
                    break;
            }
        });

        return new Gtk.ColumnViewColumn(title, factory);
    }

    private string format_epoch(int64 epoch) {
        if (epoch <= 0) {
            return "";
        }
        var dt = new DateTime.from_unix_local(epoch);
        return dt.format("%Y-%m-%d %H:%M");
    }

    private void queue_resources_refresh() {
        resources_refresh_serial++;
        refresh_resources.begin(resources_refresh_serial);
    }

    private async void refresh_resources(uint request_serial) {
        if (resources_store == null) {
            return;
        }
        while (resources_store.get_n_items() > 0) {
            resources_store.remove(resources_store.get_n_items() - 1);
        }
        all_resources.clear();

        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (project == null) {
            resources_empty_label.set_text("Select a project to view resources.");
            resources_empty_label.set_visible(true);
            refresh_resource_action_state();
            return;
        }
        if (api == null) {
            resources_empty_label.set_text("API unavailable.");
            resources_empty_label.set_visible(true);
            refresh_resource_action_state();
            return;
        }

        try {
            var resources = yield api.list_resources(project.project_id);
            if (request_serial != resources_refresh_serial) {
                return;
            }
            all_resources = resources;
            apply_resources_filter();
        } catch (Error e) {
            if (request_serial != resources_refresh_serial) {
                return;
            }
            resources_empty_label.set_text("Failed to load resources.");
            resources_empty_label.set_visible(true);
            error_reported("Resources refresh failed", e.message);
            refresh_resource_action_state();
        }
    }

    private void apply_resources_filter() {
        if (resources_store == null) {
            return;
        }
        while (resources_store.get_n_items() > 0) {
            resources_store.remove(resources_store.get_n_items() - 1);
        }

        var query = resources_search_entry != null ? resources_search_entry.get_text().strip().down() : "";
        foreach (var resource in all_resources) {
            if (query.length > 0) {
                var haystack = "%s %s %s %s".printf(
                    resource.label,
                    resource.kind,
                    resource.uri,
                    resource.desc ?? ""
                ).down();
                if (!haystack.contains(query)) {
                    continue;
                }
            }
            resources_store.append(resource);
        }

        resources_empty_label.set_visible(resources_store.get_n_items() == 0);
        if (resources_store.get_n_items() == 0) {
            resources_empty_label.set_text(
                query.length > 0 ? "No resources match this filter." : "No resources in this project."
            );
        }
        refresh_resource_action_state();
    }

    private ProjectResource? selected_resource() {
        return resources_selection != null
            ? resources_selection.get_selected_item() as ProjectResource
            : null;
    }

    private void refresh_resource_action_state() {
        var selected = selected_resource();
        if (resources_open_btn != null) {
            resources_open_btn.set_sensitive(selected != null);
        }
        if (resources_edit_btn != null) {
            resources_edit_btn.set_sensitive(selected != null);
        }
        if (resources_delete_btn != null) {
            resources_delete_btn.set_sensitive(selected != null);
        }
    }

    private string[] default_resource_kinds() {
        return {"url", "file", "dir", "repo", "image"};
    }

    private void open_resource_dialog(ProjectResource? existing) {
        var project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (project == null) {
            toast_requested("Select a project first.");
            return;
        }

        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }

        var is_edit = existing != null;
        var dialog = new Adw.MessageDialog(
            root_window,
            is_edit ? "Edit Resource" : "Add Resource",
            is_edit ? "Update resource pointer fields." : "Create a project resource pointer."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("save", "Save");
        dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("save");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var kind_label = new Gtk.Label("Kind") { xalign = 0.0f };
        var kind_options = new Gtk.StringList(null);
        foreach (var kind in default_resource_kinds()) {
            kind_options.append(kind);
        }
        kind_options.append("custom");
        var kind_dropdown = new Gtk.DropDown(kind_options, null);
        var custom_kind_entry = new Gtk.Entry();
        custom_kind_entry.set_placeholder_text("custom kind");
        custom_kind_entry.set_visible(false);
        kind_dropdown.notify["selected"].connect(() => {
            var idx = kind_dropdown.get_selected();
            custom_kind_entry.set_visible(idx == kind_options.get_n_items() - 1);
            if (!custom_kind_entry.get_visible()) {
                custom_kind_entry.set_text("");
            }
        });
        content.append(kind_label);
        content.append(kind_dropdown);
        content.append(custom_kind_entry);

        var uri_label = new Gtk.Label("URI") { xalign = 0.0f };
        var uri_entry = new Gtk.Entry();
        uri_entry.set_placeholder_text("https://..., file:///..., /path/to/file");
        content.append(uri_label);
        content.append(uri_entry);

        var label_label = new Gtk.Label("Label") { xalign = 0.0f };
        var label_entry = new Gtk.Entry();
        content.append(label_label);
        content.append(label_entry);

        var local_picker_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var pick_file_btn = new Gtk.Button.with_label("Pick File...");
        pick_file_btn.clicked.connect(() => {
            open_local_resource_picker(root_window, uri_entry, label_entry, false);
        });
        local_picker_row.append(pick_file_btn);
        var pick_image_btn = new Gtk.Button.with_label("Pick Image...");
        pick_image_btn.clicked.connect(() => {
            open_local_resource_picker(root_window, uri_entry, label_entry, true);
        });
        local_picker_row.append(pick_image_btn);
        content.append(local_picker_row);

        var desc_label = new Gtk.Label("Description (optional)") { xalign = 0.0f };
        var desc_entry = new Gtk.Entry();
        content.append(desc_label);
        content.append(desc_entry);

        if (existing != null) {
            uri_entry.set_text(existing.uri);
            label_entry.set_text(existing.label);
            desc_entry.set_text(existing.desc ?? "");
            int match = -1;
            for (uint i = 0; i < kind_options.get_n_items(); i++) {
                var option = kind_options.get_string(i);
                if (option == existing.kind) {
                    match = (int) i;
                    break;
                }
            }
            if (match >= 0) {
                kind_dropdown.set_selected((uint) match);
            } else {
                kind_dropdown.set_selected(kind_options.get_n_items() - 1);
                custom_kind_entry.set_visible(true);
                custom_kind_entry.set_text(existing.kind);
            }
        } else {
            kind_dropdown.set_selected(0);
        }

        dialog.set_extra_child(content);
        dialog.response.connect((response) => {
            if (response != "save") {
                dialog.close();
                return;
            }

            var uri = uri_entry.get_text().strip();
            var label = label_entry.get_text().strip();
            var desc_raw = desc_entry.get_text().strip();
            if (uri.length == 0 || label.length == 0) {
                toast_requested("URI and label are required.");
                return;
            }

            string kind = "url";
            var selected = kind_dropdown.get_selected();
            if (selected < kind_options.get_n_items() - 1) {
                kind = kind_options.get_string(selected);
            } else {
                var custom = custom_kind_entry.get_text().strip();
                kind = custom.length > 0 ? custom : "url";
            }

            var desc = desc_raw.length > 0 ? desc_raw : null;
            if (existing != null) {
                update_resource.begin(existing.resource_id, kind, uri, label, desc);
            } else {
                create_resource.begin(project.project_id, kind, uri, label, desc);
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void create_resource(string project_id,
                                       string kind,
                                       string uri,
                                       string label,
                                       string? desc) {
        if (api == null) {
            return;
        }
        try {
            yield api.create_resource(project_id, kind, uri, label, desc);
            toast_requested("Resource added.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to create resource", e.message);
        }
    }

    private async void update_resource(string resource_id,
                                       string kind,
                                       string uri,
                                       string label,
                                       string? desc) {
        if (api == null) {
            return;
        }
        try {
            var now = new DateTime.now_utc().to_unix();
            yield api.update_resource(resource_id, kind, uri, label, desc, now);
            toast_requested("Resource updated.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to update resource", e.message);
        }
    }

    private void open_selected_resource() {
        var selected = selected_resource();
        if (selected == null) {
            return;
        }
        try {
            AppInfo.launch_default_for_uri(selected.uri, null);
        } catch (Error e) {
            error_reported("Failed to open resource", e.message);
        }
    }

    private void confirm_delete_selected_resource() {
        var selected = selected_resource();
        if (selected == null) {
            return;
        }
        var root_window = widget.get_root() as Gtk.Window;
        if (root_window == null) {
            return;
        }

        var dialog = new Adw.MessageDialog(
            root_window,
            "Delete Resource",
            "Delete \"%s\"?".printf(selected.label)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("delete", "Delete");
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response.connect((response) => {
            if (response == "delete") {
                delete_resource.begin(selected.resource_id);
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void delete_resource(string resource_id) {
        if (api == null) {
            return;
        }
        try {
            yield api.delete_resource(resource_id);
            toast_requested("Resource deleted.");
            queue_resources_refresh();
        } catch (Error e) {
            error_reported("Failed to delete resource", e.message);
        }
    }

    private void open_local_resource_picker(Gtk.Window root_window,
                                            Gtk.Entry uri_entry,
                                            Gtk.Entry? label_entry,
                                            bool images_only) {
        var dialog = new Gtk.FileDialog();
        dialog.set_title(images_only ? "Choose Image" : "Choose File");

        if (images_only) {
            var image_filter = new Gtk.FileFilter();
            image_filter.add_mime_type("image/*");
            var filters = new GLib.ListStore(typeof(Gtk.FileFilter));
            filters.append(image_filter);
            dialog.set_filters(filters);
            dialog.set_default_filter(image_filter);
        }

        dialog.open.begin(root_window, null, (obj, res) => {
            try {
                var file = dialog.open.end(res);
                if (file == null) {
                    return;
                }
                var uri = file.get_uri();
                if (uri != null && uri.length > 0) {
                    uri_entry.set_text(uri);
                }
                if (label_entry != null && label_entry.get_text().strip().length == 0) {
                    var basename = file.get_basename();
                    if (basename != null && basename.length > 0) {
                        label_entry.set_text(basename);
                    }
                }
            } catch (Error e) {
                // User cancellation is expected; only surface unexpected errors.
                if (!(e is IOError.CANCELLED)) {
                    error_reported("Failed to choose file", e.message);
                }
            }
        });
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

    private string? normalize_parent(string? parent_card_id) {
        if (parent_card_id == null) {
            return null;
        }
        var trimmed = parent_card_id.strip();
        return trimmed.length == 0 ? null : trimmed;
    }

    private int compare_sibling_order(CardSummary a, CardSummary b) {
        if (a.sort_key < b.sort_key) {
            return -1;
        }
        if (a.sort_key > b.sort_key) {
            return 1;
        }
        if (a.updated_at > b.updated_at) {
            return -1;
        }
        if (a.updated_at < b.updated_at) {
            return 1;
        }
        return strcmp(a.title.down(), b.title.down());
    }

    private string compact_structure_markup(Project? project, CardSummary? selected_card) {
        var lines = new Gee.ArrayList<string>();
        if (project != null) {
            lines.add("Project: %s".printf(link_markup("project", project.project_id, project.name)));
        } else {
            lines.add("Project: None");
        }

        if (selected_card != null && card_store != null) {
            var parent_id = normalize_parent(selected_card.parent_card_id);
            if (parent_id != null) {
                for (uint i = 0; i < card_store.get_n_items(); i++) {
                    var maybe_parent = card_store.get_item(i) as CardSummary;
                    if (maybe_parent != null && maybe_parent.card_id == parent_id) {
                        lines.add(
                            "Parent: %s".printf(
                                link_markup("card", maybe_parent.card_id, maybe_parent.title)
                            )
                        );
                        break;
                    }
                }
            }
        }

        if (selected_card != null && card_store != null) {
            var siblings = new Gee.ArrayList<CardSummary>();
            var parent_id = normalize_parent(selected_card.parent_card_id);
            for (uint i = 0; i < card_store.get_n_items(); i++) {
                var card = card_store.get_item(i) as CardSummary;
                if (card == null) {
                    continue;
                }
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (normalize_parent(card.parent_card_id) == parent_id) {
                    siblings.add(card);
                }
            }
            siblings.sort((a, b) => compare_sibling_order(a, b));

            int selected_index = -1;
            for (int i = 0; i < siblings.size; i++) {
                if (siblings[i].card_id == selected_card.card_id) {
                    selected_index = i;
                    break;
                }
            }

            var sibling_parts = new Gee.ArrayList<string>();
            if (selected_index > 0) {
                sibling_parts.add("Previous: %s".printf(
                    link_markup("card", siblings[selected_index - 1].card_id, siblings[selected_index - 1].title)
                ));
            }
            if (selected_index >= 0 && selected_index < siblings.size - 1) {
                sibling_parts.add("Next: %s".printf(
                    link_markup("card", siblings[selected_index + 1].card_id, siblings[selected_index + 1].title)
                ));
            }
            if (sibling_parts.size > 0) {
                lines.add(string.joinv("   ", sibling_parts.to_array()));
            }

            var children = new Gee.ArrayList<CardSummary>();
            for (uint i = 0; i < card_store.get_n_items(); i++) {
                var card = card_store.get_item(i) as CardSummary;
                if (card == null) {
                    continue;
                }
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (normalize_parent(card.parent_card_id) == selected_card.card_id) {
                    children.add(card);
                }
            }
            if (children.size > 0) {
                children.sort((a, b) => compare_sibling_order(a, b));
                var child_links = new StringBuilder();
                for (int i = 0; i < children.size; i++) {
                    if (i > 0) {
                        child_links.append(" ");
                    }
                    child_links.append(link_markup("card", children[i].card_id, children[i].title));
                }
                lines.add("Children: %s".printf(child_links.str));
            }
        }

        return string.joinv("\n", lines.to_array());
    }

    private string link_markup(string kind, string id, string title) {
        var href = "%s:%s".printf(kind, Uri.escape_string(id, null, false));
        return "<a href=\"%s\">%s</a>".printf(
            Markup.escape_text(href),
            Markup.escape_text(ellipsize_connections_title(title))
        );
    }

    private string ellipsize_connections_title(string title) {
        if (title == null) {
            return "";
        }
        if (title.char_count() < 47) {
            return title;
        }
        int cutoff = title.index_of_nth_char(44);
        if (cutoff < 0) {
            return title;
        }
        return title.substring(0, cutoff) + "...";
    }

    private void set_graph_empty_state(string outgoing_text, string backlinks_text) {
        clear_list_box(connections_graph_outgoing_list);
        clear_list_box(connections_graph_backlinks_list);
        if (connections_graph_outgoing_empty_label != null) {
            connections_graph_outgoing_empty_label.set_text(outgoing_text);
            connections_graph_outgoing_empty_label.set_visible(true);
        }
        if (connections_graph_backlinks_empty_label != null) {
            connections_graph_backlinks_empty_label.set_text(backlinks_text);
            connections_graph_backlinks_empty_label.set_visible(true);
        }
        update_add_graph_link_button_state();
    }

    private void update_add_graph_link_button_state() {
        if (connections_add_graph_link_btn == null) {
            return;
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        var has_target = false;
        if (selected_card != null && card_store != null) {
            for (uint i = 0; i < card_store.get_n_items(); i++) {
                var card = card_store.get_item(i) as CardSummary;
                if (card == null) {
                    continue;
                }
                if (card.project_id != selected_card.project_id) {
                    continue;
                }
                if (card.card_id != selected_card.card_id) {
                    has_target = true;
                    break;
                }
            }
        }
        connections_add_graph_link_btn.set_sensitive(api != null && selected_card != null && has_target);
    }

    private void open_add_graph_link_dialog() {
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (selected_card == null || card_store == null || api == null) {
            return;
        }

        var target_ids = new Gee.ArrayList<string>();
        var target_titles = new Gtk.StringList(null);
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != selected_card.project_id || card.card_id == selected_card.card_id) {
                continue;
            }
            target_ids.add(card.card_id);
            target_titles.append("%s (%s)".printf(card.title, card.card_id));
        }
        if (target_ids.size == 0) {
            toast_requested("No other cards in this project to link.");
            return;
        }

        var root = widget.get_root() as Gtk.Window;
        if (root == null) {
            return;
        }

        var dialog = new Adw.MessageDialog(root, "Add Graph Link", "Create an explicit card-to-card link.");
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("add", "Add");
        dialog.set_response_appearance("add", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("add");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        var target_label = new Gtk.Label("Target card") { xalign = 0.0f };
        var target_dropdown = new Gtk.DropDown(target_titles, null);
        target_dropdown.set_selected(0);
        content.append(target_label);
        content.append(target_dropdown);

        var kind_label = new Gtk.Label("Kind") { xalign = 0.0f };
        var kind_options = new Gtk.StringList(null);
        var available_kinds = list_available_link_kinds();
        foreach (var kind_option in available_kinds) {
            kind_options.append(kind_option);
        }
        kind_options.append("custom");
        var kind_dropdown = new Gtk.DropDown(kind_options, null);
        kind_dropdown.set_selected(0);
        var custom_kind_entry = new Gtk.Entry();
        custom_kind_entry.set_placeholder_text("custom kind");
        custom_kind_entry.set_visible(false);
        kind_dropdown.notify["selected"].connect(() => {
            var selected = kind_dropdown.get_selected();
            var is_custom = (selected == kind_options.get_n_items() - 1);
            custom_kind_entry.set_visible(is_custom);
            if (!is_custom) {
                custom_kind_entry.set_text("");
            }
        });
        var kind_row = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        kind_row.append(kind_dropdown);
        kind_row.append(custom_kind_entry);
        content.append(kind_label);
        content.append(kind_row);

        var label_label = new Gtk.Label("Label (optional)") { xalign = 0.0f };
        var label_entry = new Gtk.Entry();
        label_entry.set_placeholder_text("optional note");
        content.append(label_label);
        content.append(label_entry);

        dialog.set_extra_child(content);
        dialog.response.connect((response) => {
            if (response == "add") {
                var selected_index = target_dropdown.get_selected();
                if (selected_index >= target_ids.size) {
                    dialog.close();
                    return;
                }
                var target_id = target_ids[(int) selected_index];
                var selected_kind_index = (int) kind_dropdown.get_selected();
                var custom_index = (int) kind_options.get_n_items() - 1;
                string kind = "ref";
                bool remember_kind = false;
                if (selected_kind_index >= 0 && selected_kind_index < custom_index) {
                    var chosen = kind_options.get_string((uint) selected_kind_index);
                    if (chosen != null && chosen.length > 0) {
                        kind = chosen;
                    }
                } else {
                    var custom_kind = custom_kind_entry.get_text().strip();
                    kind = custom_kind.length > 0 ? custom_kind : "ref";
                    remember_kind = custom_kind.length > 0;
                }
                var link_label = label_entry.get_text().strip();
                create_graph_link.begin(
                    selected_card.card_id,
                    target_id,
                    kind.length > 0 ? kind : "ref",
                    link_label.length > 0 ? link_label : null,
                    remember_kind
                );
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void create_graph_link(string from_card_id,
                                         string to_card_id,
                                         string kind,
                                         string? label,
                                         bool remember_kind) {
        if (api == null) {
            return;
        }
        try {
            yield api.create_card_link(from_card_id, to_card_id, kind, label, "card");
            if (remember_kind) {
                remember_custom_link_kind(kind);
            }
            toast_requested("Graph link added.");
            queue_connections_graph_refresh();
        } catch (Error e) {
            error_reported("Failed to add graph link", e.message);
        }
    }

    private Gee.ArrayList<string> list_available_link_kinds() {
        var values = new Gee.ArrayList<string>();
        values.add("ref");
        values.add("depends_on");
        values.add("example_of");
        values.add("blocks");
        values.add("related_to");

        if (settings == null) {
            return values;
        }

        foreach (var kind in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            var cleaned = kind.strip();
            if (cleaned.length == 0 || cleaned == "custom" || values.contains(cleaned)) {
                continue;
            }
            values.add(cleaned);
        }
        return values;
    }

    private void remember_custom_link_kind(string kind) {
        if (settings == null) {
            return;
        }
        var cleaned = kind.strip();
        if (cleaned.length == 0 || cleaned == "custom") {
            return;
        }

        var defaults = new Gee.HashSet<string>();
        defaults.add("ref");
        defaults.add("depends_on");
        defaults.add("example_of");
        defaults.add("blocks");
        defaults.add("related_to");
        if (defaults.contains(cleaned)) {
            return;
        }

        var custom = new Gee.ArrayList<string>();
        foreach (var existing in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            var item = existing.strip();
            if (item.length == 0 || item == "custom" || defaults.contains(item) || custom.contains(item)) {
                continue;
            }
            custom.add(item);
        }
        if (custom.contains(cleaned)) {
            return;
        }

        custom.add(cleaned);
        while (custom.size > 20) {
            custom.remove_at(0);
        }

        string[] stored = new string[custom.size];
        for (int i = 0; i < custom.size; i++) {
            stored[i] = custom[i];
        }
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, stored);
    }

    private void queue_connections_graph_refresh() {
        connections_graph_refresh_serial++;
        refresh_connections_graph.begin(connections_graph_refresh_serial);
    }

    private async void refresh_connections_graph(uint request_serial) {
        if (connections_graph_outgoing_list == null || connections_graph_backlinks_list == null) {
            return;
        }
        if (api == null) {
            set_graph_empty_state(
                "API unavailable.",
                "API unavailable."
            );
            return;
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (selected_card == null) {
            set_graph_empty_state(
                "Select a card to view graph links.",
                "Select a card to view graph links."
            );
            return;
        }

        var expected_card_id = selected_card.card_id;
        try {
            var outgoing = yield api.list_card_links(expected_card_id);
            var backlinks = yield api.list_card_backlinks(expected_card_id);

            if (request_serial != connections_graph_refresh_serial) {
                return;
            }
            var still_selected = card_selection != null
                ? card_selection.get_selected_item() as CardSummary
                : null;
            if (still_selected == null || still_selected.card_id != expected_card_id) {
                return;
            }

            populate_graph_rows(outgoing, true);
            populate_graph_rows(backlinks, false);
            update_add_graph_link_button_state();
        } catch (Error e) {
            if (request_serial != connections_graph_refresh_serial) {
                return;
            }
            set_graph_empty_state(
                "Failed to load outgoing links.",
                "Failed to load backlinks."
            );
            log_debug("Graph links refresh failed: %s".printf(e.message));
        }
    }

    private string title_for_card_id(string card_id) {
        if (card_store == null) {
            return card_id;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                return card.title;
            }
        }
        return card_id;
    }

    private void populate_graph_rows(Gee.ArrayList<CardLink> links, bool outgoing) {
        var list = outgoing ? connections_graph_outgoing_list : connections_graph_backlinks_list;
        var empty = outgoing ? connections_graph_outgoing_empty_label : connections_graph_backlinks_empty_label;
        clear_list_box(list);

        if (links.size == 0) {
            if (empty != null) {
                empty.set_text("None yet.");
                empty.set_visible(true);
            }
            return;
        }
        if (empty != null) {
            empty.set_visible(false);
        }

        var grouped = new Gee.HashMap<string, Gee.ArrayList<CardLink>>();
        var kind_order = new Gee.ArrayList<string>();
        foreach (var link in links) {
            var kind = (link.kind != null && link.kind.strip().length > 0) ? link.kind.strip() : "ref";
            var bucket = grouped.get(kind);
            if (bucket == null) {
                bucket = new Gee.ArrayList<CardLink>();
                grouped.set(kind, bucket);
                kind_order.add(kind);
            }
            bucket.add(link);
        }

        foreach (var kind in kind_order) {
            var bucket = grouped.get(kind);
            if (bucket == null) {
                continue;
            }

            var header_row = new Gtk.ListBoxRow();
            header_row.set_activatable(false);
            header_row.set_selectable(false);
            header_row.add_css_class("connections-kind-row");
            header_row.set_child(build_graph_kind_header_row(kind));
            list.append(header_row);

            for (int i = 0; i < bucket.size; i++) {
                var row = new Gtk.ListBoxRow();
                row.set_activatable(false);
                row.set_selectable(false);
                row.add_css_class("connections-link-row");
                row.set_child(build_graph_link_row(bucket[i], outgoing));
                list.append(row);
            }
        }
    }

    private Gtk.Widget build_graph_kind_header_row(string kind) {
        var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        row.set_margin_start(GRAPH_BLOCK_MARGIN_START);

        var gutter = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        gutter.set_size_request(GRAPH_ACTION_COL_WIDTH, -1);
        row.append(gutter);

        var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        content.set_margin_start(GRAPH_CONTENT_GAP);
        content.set_hexpand(true);
        var kind_label = new Gtk.Label(kind) { xalign = 0.0f };
        kind_label.add_css_class("dim-label");
        kind_label.set_margin_start(GRAPH_KIND_EXTRA_INDENT);
        content.append(kind_label);
        row.append(content);
        return row;
    }

    private Gtk.Widget build_graph_link_row(CardLink link, bool outgoing) {
        var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        row.set_margin_start(GRAPH_BLOCK_MARGIN_START);
        var target_id = outgoing ? link.to_card_id : link.from_card_id;
        var target_type = outgoing ? link.to_type : "card";
        var direction = outgoing ? "→" : "←";

        var action_gutter = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        action_gutter.set_size_request(GRAPH_ACTION_COL_WIDTH, -1);
        row.append(action_gutter);

        var actions_btn = new Gtk.MenuButton();
        actions_btn.set_icon_name("open-menu-symbolic");
        actions_btn.add_css_class("flat");
        actions_btn.set_valign(Gtk.Align.START);
        actions_btn.set_halign(Gtk.Align.CENTER);
        var popover = new Gtk.Popover();
        var actions_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        actions_box.set_margin_top(6);
        actions_box.set_margin_bottom(6);
        actions_box.set_margin_start(6);
        actions_box.set_margin_end(6);
        var edit_btn = new Gtk.Button.with_label("Edit");
        edit_btn.add_css_class("flat");
        edit_btn.clicked.connect(() => {
            popover.popdown();
            open_edit_graph_link_dialog(link, outgoing);
        });
        var delete_btn = new Gtk.Button.with_label("Delete");
        delete_btn.add_css_class("flat");
        delete_btn.clicked.connect(() => {
            popover.popdown();
            delete_graph_link.begin(link);
        });
        actions_box.append(edit_btn);
        actions_box.append(delete_btn);
        popover.set_child(actions_box);
        actions_btn.set_popover(popover);
        action_gutter.append(actions_btn);

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        content.set_margin_start(GRAPH_CONTENT_GAP);
        content.set_hexpand(true);
        row.append(content);

        var detail = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        detail.set_margin_start(0);
        detail.set_hexpand(true);
        content.append(detail);

        var arrow_label = new Gtk.Label(direction) { xalign = 0.0f };
        arrow_label.add_css_class("dim-label");
        detail.append(arrow_label);

        Gtk.Widget target_widget;
        if (target_type == "card") {
            var target_btn = new Gtk.Button.with_label(
                ellipsize_connections_title(title_for_card_id(target_id))
            );
            target_btn.add_css_class("flat");
            target_btn.add_css_class("link");
            target_btn.clicked.connect(() => {
                select_card_by_id(target_id);
            });
            target_widget = target_btn;
        } else {
            target_widget = new Gtk.Label("%s:%s".printf(target_type, target_id)) { xalign = 0.0f };
        }
        target_widget.set_hexpand(false);
        target_widget.set_halign(Gtk.Align.START);
        detail.append(target_widget);

        if (link.label != null && link.label.strip().length > 0) {
            var label = new Gtk.Label(link.label.strip()) { xalign = 0.0f };
            label.add_css_class("caption");
            label.add_css_class("dim-label");
            detail.append(label);
        }

        var trailing_spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        trailing_spacer.set_hexpand(true);
        detail.append(trailing_spacer);

        return row;
    }

    private static void ensure_connections_css() {
        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
.connections-kind-row {
  background: transparent;
  background-color: transparent;
  box-shadow: none;
}

.connections-kind-row:hover,
.connections-kind-row:focus,
.connections-kind-row:focus-within,
.connections-kind-row:selected {
  background: transparent;
  background-color: transparent;
  box-shadow: none;
}

.connections-graph-list,
.connections-graph-list row,
.connections-graph-list row:hover,
.connections-graph-list row:selected,
.connections-graph-list row:focus,
.connections-graph-list row:focus-within {
  background: transparent;
  background-color: transparent;
  box-shadow: none;
}
""");
        gtk_style_context_add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void open_edit_graph_link_dialog(CardLink link, bool outgoing) {
        var root = widget.get_root() as Gtk.Window;
        if (root == null) {
            return;
        }
        var target_id = outgoing ? link.to_card_id : link.from_card_id;
        var target_title = title_for_card_id(target_id);

        var dialog = new Adw.MessageDialog(root, "Edit Graph Link", "Update kind or label.");
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("save", "Save");
        dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("save");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        content.append(new Gtk.Label("Target") { xalign = 0.0f });
        content.append(new Gtk.Label(target_title) { xalign = 0.0f });

        content.append(new Gtk.Label("Kind") { xalign = 0.0f });
        var kind_options = new Gtk.StringList(null);
        var available_kinds = list_available_link_kinds();
        foreach (var kind_option in available_kinds) {
            kind_options.append(kind_option);
        }
        kind_options.append("custom");
        var kind_dropdown = new Gtk.DropDown(kind_options, null);
        var custom_kind_entry = new Gtk.Entry();
        custom_kind_entry.set_placeholder_text("custom kind");
        custom_kind_entry.set_visible(false);

        int selected_index = -1;
        for (uint i = 0; i < kind_options.get_n_items(); i++) {
            if (kind_options.get_string(i) == link.kind) {
                selected_index = (int) i;
                break;
            }
        }
        if (selected_index >= 0) {
            kind_dropdown.set_selected((uint) selected_index);
        } else {
            kind_dropdown.set_selected(kind_options.get_n_items() - 1);
            custom_kind_entry.set_text(link.kind);
            custom_kind_entry.set_visible(true);
        }

        kind_dropdown.notify["selected"].connect(() => {
            var selected = kind_dropdown.get_selected();
            var is_custom = (selected == kind_options.get_n_items() - 1);
            custom_kind_entry.set_visible(is_custom);
            if (!is_custom) {
                custom_kind_entry.set_text("");
            }
        });
        var kind_row = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        kind_row.append(kind_dropdown);
        kind_row.append(custom_kind_entry);
        content.append(kind_row);

        content.append(new Gtk.Label("Label (optional)") { xalign = 0.0f });
        var label_entry = new Gtk.Entry();
        if (link.label != null) {
            label_entry.set_text(link.label);
        }
        content.append(label_entry);

        dialog.set_extra_child(content);
        dialog.response.connect((response) => {
            if (response == "save") {
                var custom_index = (int) kind_options.get_n_items() - 1;
                var picked_index = (int) kind_dropdown.get_selected();
                string new_kind = "ref";
                bool remember_kind = false;
                if (picked_index >= 0 && picked_index < custom_index) {
                    var chosen = kind_options.get_string((uint) picked_index);
                    if (chosen != null && chosen.length > 0) {
                        new_kind = chosen;
                    }
                } else {
                    var custom_kind = custom_kind_entry.get_text().strip();
                    new_kind = custom_kind.length > 0 ? custom_kind : "ref";
                    remember_kind = custom_kind.length > 0;
                }
                var new_label = label_entry.get_text().strip();
                update_graph_link.begin(
                    link,
                    new_kind,
                    new_label.length > 0 ? new_label : null,
                    remember_kind
                );
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void update_graph_link(CardLink old_link,
                                         string new_kind,
                                         string? new_label,
                                         bool remember_kind) {
        if (api == null) {
            return;
        }
        try {
            var kind_changed = old_link.kind != new_kind;
            if (kind_changed) {
                yield api.create_card_link(old_link.from_card_id, old_link.to_card_id, new_kind, new_label, old_link.to_type);
                yield api.delete_card_link(old_link.from_card_id, old_link.to_card_id, old_link.kind, old_link.to_type);
            } else {
                yield api.create_card_link(old_link.from_card_id, old_link.to_card_id, new_kind, new_label, old_link.to_type);
            }
            if (remember_kind) {
                remember_custom_link_kind(new_kind);
            }
            toast_requested("Graph link updated.");
            queue_connections_graph_refresh();
        } catch (Error e) {
            error_reported("Failed to edit graph link", e.message);
        }
    }

    private async void delete_graph_link(CardLink link) {
        if (api == null) {
            return;
        }
        try {
            yield api.delete_card_link(link.from_card_id, link.to_card_id, link.kind, link.to_type);
            toast_requested("Graph link deleted.");
            queue_connections_graph_refresh();
        } catch (Error e) {
            error_reported("Failed to delete graph link", e.message);
        }
    }

    private bool on_connections_link_activated(string uri) {
        if (uri == null || uri.length == 0) {
            return false;
        }

        if (uri.has_prefix("card:")) {
            var encoded = uri.substring("card:".length);
            var card_id = Uri.unescape_string(encoded, null);
            if (card_id != null) {
                Idle.add(() => {
                    select_card_by_id(card_id);
                    return Source.REMOVE;
                });
                return true;
            }
            return false;
        }

        if (uri.has_prefix("project:")) {
            var encoded = uri.substring("project:".length);
            var project_id = Uri.unescape_string(encoded, null);
            if (project_id != null) {
                Idle.add(() => {
                    select_project_by_id(project_id);
                    return Source.REMOVE;
                });
                return true;
            }
            return false;
        }

        if (uri.has_prefix("ilink:")) {
            var encoded = uri.substring("ilink:".length);
            var target = Uri.unescape_string(encoded, null);
            if (target != null) {
                var card_id = resolve_internal_link_target_card_id(target);
                if (card_id != null) {
                    Idle.add(() => {
                        select_card_by_id(card_id);
                        return Source.REMOVE;
                    });
                }
                return true;
            }
            return false;
        }

        return false;
    }

    private string? selected_project_id() {
        if (project_selection == null) {
            return null;
        }
        var selected_project = project_selection.get_selected_item() as Project;
        return selected_project != null ? selected_project.project_id : null;
    }

    private string? resolve_internal_link_target_card_id(string target) {
        if (card_store == null || target.length == 0) {
            return null;
        }
        var project_id = selected_project_id();
        if (project_id == null) {
            return null;
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != project_id) {
                continue;
            }
            if (card.card_id == target) {
                return card.card_id;
            }
        }

        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != project_id) {
                continue;
            }
            if (card.title == target) {
                return card.card_id;
            }
        }

        var lowered_target = target.down();
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card == null || card.project_id != project_id) {
                continue;
            }
            if (card.title.down() == lowered_target) {
                return card.card_id;
            }
        }

        return null;
    }

    private bool select_project_by_id(string project_id) {
        if (project_selection == null) {
            return false;
        }
        var model = project_selection.get_model();
        if (model == null) {
            return false;
        }
        for (uint i = 0; i < model.get_n_items(); i++) {
            var project = model.get_item(i) as Project;
            if (project != null && project.project_id == project_id) {
                project_selection.set_selected(i);
                return true;
            }
        }
        return false;
    }

    private bool select_card_by_id(string card_id) {
        if (card_selection == null) {
            return false;
        }
        var model = card_selection.get_model();
        if (model == null) {
            return false;
        }
        for (uint i = 0; i < model.get_n_items(); i++) {
            var card = model.get_item(i) as CardSummary;
            if (card != null && card.card_id == card_id) {
                card_selection.set_selected(i);
                return true;
            }
        }
        return false;
    }

    private void refresh_connections_structure() {
        if (connections_structure_label == null) {
            return;
        }
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (connections_card_title_label != null) {
            connections_card_title_label.set_text(
                selected_card != null
                    ? ellipsize_connections_title(selected_card.title)
                    : "No card selected"
            );
        }
        connections_structure_label.set_markup(compact_structure_markup(selected_project, selected_card));
        update_add_graph_link_button_state();
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
        git_sync_stack = new Gtk.Stack();
        git_sync_stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        git_sync_stack.set_vexpand(true);
        git_sync_stack.set_hexpand(true);

        var start_page = build_git_sync_start_page();
        git_sync_stack.add_named(start_page, "start");

        var guided_page = build_git_sync_guided_part1_page();
        git_sync_stack.add_named(guided_page, "guided-part1");
        var guided_ssh_page = build_git_sync_guided_part2_page();
        git_sync_stack.add_named(guided_ssh_page, "guided-part2");
        var guided_repo_page = build_git_sync_guided_part3_page();
        git_sync_stack.add_named(guided_repo_page, "guided-part3");
        var guided_push_page = build_git_sync_guided_part4_page();
        git_sync_stack.add_named(guided_push_page, "guided-part4");
        var provider_page = build_git_sync_provider_page();
        git_sync_stack.add_named(provider_page, "provider");
        git_sync_stack.set_visible_child_name("start");

        return git_sync_stack;
    }

    private Gtk.Widget build_git_sync_start_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var intro = new Gtk.Label(
            "Syncing your project to a Git provider keeps your cards in sync across devices,\n" +
            "provides an additional copy in case of computer loss or failure,\n" +
            "and optionally enables collaboration with others."
        ) { xalign = 0.0f };
        intro.set_wrap(true);
        intro.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        intro.add_css_class("dim-label");
        box.append(intro);

        git_gh_cli_auto_btn = new Gtk.Button.with_label("Use GitHub CLI (Automatic)");
        git_gh_cli_auto_btn.set_halign(Gtk.Align.START);
        git_gh_cli_auto_btn.set_sensitive(false);
        git_gh_cli_auto_btn.clicked.connect(() => {
            run_github_cli_auto_sync.begin();
        });
        box.append(git_gh_cli_auto_btn);

        git_gh_cli_status_label = new Gtk.Label("Checking GitHub CLI...") { xalign = 0.0f };
        git_gh_cli_status_label.set_wrap(true);
        git_gh_cli_status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_gh_cli_status_label.add_css_class("dim-label");
        box.append(git_gh_cli_status_label);

        var guided_btn = new Gtk.Button.with_label("Guided (I'm new to this)");
        guided_btn.set_halign(Gtk.Align.START);
        guided_btn.clicked.connect(() => {
            refresh_guided_github_username();
            git_sync_stack.set_visible_child_name("guided-part1");
        });
        box.append(guided_btn);

        git_gh_cli_guided_btn = new Gtk.Button.with_label("Use GitHub CLI (auto-fill username)");
        git_gh_cli_guided_btn.set_halign(Gtk.Align.START);
        git_gh_cli_guided_btn.set_sensitive(false);
        git_gh_cli_guided_btn.clicked.connect(() => {
            if (git_gh_login.strip().length > 0 && git_guided_username_entry != null) {
                git_guided_username_entry.set_text(git_gh_login);
                persist_guided_github_username();
            }
            refresh_guided_github_username();
            git_sync_stack.set_visible_child_name("guided-part2");
            refresh_guided_ssh_email_default();
            check_guided_ssh_state.begin();
        });
        box.append(git_gh_cli_guided_btn);

        var provider_btn = new Gtk.Button.with_label("Provider setup (I know git)");
        provider_btn.set_halign(Gtk.Align.START);
        provider_btn.clicked.connect(() => {
            refresh_provider_setup_defaults();
            refresh_provider_setup_catalog.begin();
            git_sync_stack.set_visible_child_name("provider");
        });
        box.append(provider_btn);

        var section = new Gtk.Label("I already have a remote URL:") { xalign = 0.0f };
        section.add_css_class("heading");
        section.set_margin_top(6);
        box.append(section);

        var remote_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var remote_label = new Gtk.Label("Remote URL:") { xalign = 0.0f };
        remote_label.set_size_request(110, -1);
        git_remote_entry = new Gtk.Entry();
        git_remote_entry.set_hexpand(true);
        git_remote_entry.set_placeholder_text("https://example.com/repo.git");
        var branch_label = new Gtk.Label("Branch:") { xalign = 0.0f };
        branch_label.set_size_request(70, -1);
        git_branch_entry = new Gtk.Entry();
        git_branch_entry.set_width_chars(10);
        git_branch_entry.set_placeholder_text("local default");
        var save_btn = new Gtk.Button.with_label("Save");
        git_manual_save_btn = save_btn;
        save_btn.clicked.connect(() => {
            run_manual_remote_setup.begin();
        });
        remote_row.append(remote_label);
        remote_row.append(git_remote_entry);
        remote_row.append(branch_label);
        remote_row.append(git_branch_entry);
        remote_row.append(save_btn);
        box.append(remote_row);

        git_manual_status_label = new Gtk.Label("") { xalign = 0.0f };
        git_manual_status_label.set_wrap(true);
        git_manual_status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_manual_status_label.add_css_class("dim-label");
        box.append(git_manual_status_label);

        check_github_cli_state.begin();

        return box;
    }

    private async void run_manual_remote_setup() {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (selected_project == null) {
            toast_requested("Select a project first.");
            return;
        }
        if (api == null) {
            error_reported("Git sync failed", "Backend API client is not ready.");
            return;
        }
        var remote_url = git_remote_entry != null ? git_remote_entry.get_text().strip() : "";
        var branch = git_branch_entry != null ? git_branch_entry.get_text().strip() : "";
        if (remote_url.length == 0) {
            toast_requested("Remote URL is required.");
            return;
        }
        yield apply_project_git_remote_and_sync(
            selected_project,
            remote_url,
            branch,
            git_manual_status_label,
            git_manual_save_btn
        );
    }

    private async void apply_project_git_remote_and_sync(Project selected_project,
                                                         string remote_url,
                                                         string branch,
                                                         Gtk.Label? status_label,
                                                         Gtk.Button? action_button) {
        if (api == null) {
            error_reported("Git sync failed", "Backend API client is not ready.");
            return;
        }
        if (action_button != null) {
            action_button.set_sensitive(false);
        }
        if (status_label != null) {
            status_label.set_text("Saving remote and testing connectivity...");
        }

        var updated_at = new DateTime.now_utc().to_unix();
        GitTestRemoteResult? test_result = null;
        GitPushResult? push_result = null;
        try {
            yield api.set_project_git_remote(selected_project.project_id, remote_url, updated_at);
            test_result = yield api.test_project_git_remote(selected_project.project_id, remote_url, branch);
            if (test_result.status == "reachable") {
                if (status_label != null) {
                    status_label.set_text("Remote reachable. Pushing project data...");
                }
                push_result = yield api.push_project_git(selected_project.project_id, branch, true);
            }
        } catch (Error e) {
            if (action_button != null) {
                action_button.set_sensitive(true);
            }
            if (status_label != null) {
                status_label.set_text("Git sync failed: %s".printf(e.message));
            }
            error_reported("Git sync failed", e.message);
            return;
        }
        if (action_button != null) {
            action_button.set_sensitive(true);
        }
        var lines = new StringBuilder();
        lines.append("Project: %s\n".printf(selected_project.name));
        lines.append("Remote: %s\n".printf(remote_url));
        if (branch.length > 0) {
            lines.append("Branch: %s\n".printf(branch));
        }
        if (test_result != null) {
            lines.append("\nRemote test: %s".printf(test_result.status));
            if (test_result.error_message.strip().length > 0) {
                lines.append(" (%s)".printf(test_result.error_message.strip()));
            }
            lines.append("\n");
        } else {
            lines.append("\nRemote test: not run\n");
        }
        if (push_result != null) {
            lines.append("Push: %s".printf(push_result.status));
            if (push_result.error_message.strip().length > 0) {
                lines.append(" (%s)".printf(push_result.error_message.strip()));
            }
            if (push_result.next_action.strip().length > 0) {
                lines.append("\nNext action: %s".printf(push_result.next_action));
            }
            if (push_result.status == "pushed" || push_result.status == "up_to_date") {
                toast_requested("Git remote configured and synced.");
            }
        } else {
            lines.append("Push: not run");
        }
        if (status_label != null) {
            status_label.set_text(lines.str.strip());
        }
    }

    private Gtk.Widget build_git_sync_guided_part1_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var part_title = new Gtk.Label("Part 1/4: Username") { xalign = 0.0f };
        part_title.add_css_class("title-5");
        box.append(part_title);

        var body = new Gtk.Label(
            "There are many remote Git providers. In this guided setup, we'll use GitHub, the most widely used Git hosting platform.\n" +
            "If you prefer another provider, you can use the provider setup instead.\n\n" +
            "First thing you need is a GitHub username."
        ) { xalign = 0.0f };
        body.set_wrap(true);
        body.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        body.add_css_class("dim-label");
        box.append(body);

        var signup = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var signup_prefix = new Gtk.Label("If you don't have one:") { xalign = 0.0f };
        signup_prefix.add_css_class("dim-label");
        var signup_link = new Gtk.LinkButton.with_label("https://github.com/signup",
                                                         "click here to go to your browser to make one");
        signup_link.set_halign(Gtk.Align.START);
        signup.append(signup_prefix);
        signup.append(signup_link);
        box.append(signup);

        var username_label = new Gtk.Label("GitHub username") { xalign = 0.0f };
        box.append(username_label);
        git_guided_username_entry = new Gtk.Entry();
        git_guided_username_entry.set_placeholder_text("your-github-username");
        git_guided_username_entry.changed.connect(() => {
            refresh_guided_next_button_state();
        });
        box.append(git_guided_username_entry);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var back_btn = new Gtk.Button.with_label("Back");
        back_btn.clicked.connect(() => {
            git_sync_stack.set_visible_child_name("start");
        });
        git_guided_next_btn = new Gtk.Button.with_label("Next");
        git_guided_next_btn.set_sensitive(false);
        git_guided_next_btn.clicked.connect(() => {
            persist_guided_github_username();
            git_sync_stack.set_visible_child_name("guided-part2");
            refresh_guided_ssh_email_default();
            check_guided_ssh_state.begin();
        });
        actions.append(back_btn);
        actions.append(git_guided_next_btn);
        box.append(actions);

        refresh_guided_github_username();
        refresh_guided_next_button_state();
        return box;
    }

    private void refresh_guided_github_username() {
        if (git_guided_username_entry == null) {
            return;
        }
        if (git_gh_login.strip().length > 0) {
            git_guided_username_entry.set_text(git_gh_login);
            refresh_guided_next_button_state();
            return;
        }
        if (settings == null) {
            git_guided_username_entry.set_text("");
            refresh_guided_next_button_state();
            return;
        }
        var stored = settings.get_string(AppSettings.KEY_GIT_GITHUB_USERNAME);
        git_guided_username_entry.set_text(stored ?? "");
        refresh_guided_next_button_state();
    }

    private void refresh_git_cli_controls() {
        if (git_guided_repo_mode_label != null) {
            if (git_gh_authenticated && git_gh_login.strip().length > 0) {
                git_guided_repo_mode_label.set_text(
                    "Recommended on this device: create the private repository with GitHub CLI."
                );
            } else {
                git_guided_repo_mode_label.set_text(
                    "Create a private repository for this project."
                );
            }
        }
        if (git_guided_repo_manual_label != null) {
            git_guided_repo_manual_label.set_text(
                (git_gh_authenticated && git_gh_login.strip().length > 0)
                    ? "Browser fallback:"
                    : "Create a new repository:"
            );
        }
        if (git_guided_repo_manual_instructions_label != null) {
            if (git_gh_authenticated && git_gh_login.strip().length > 0) {
                git_guided_repo_manual_instructions_label.set_markup(
                    "If you prefer the browser route, create it manually at GitHub:\n\n" +
                    "<b>Under 2. Configuration\n" +
                    "there is \"Choose visibility *\"\n" +
                    "Change the drop down to 🔒Private</b>\n\n" +
                    "Leave README/.gitignore/license unset so the remote starts empty."
                );
            } else {
                git_guided_repo_manual_instructions_label.set_markup(
                    "Fill in the repository name, and you need to tell us the same name below.\n\n" +
                    "You can leave the description blank.\n\n" +
                    "<b>Under 2. Configuration\n" +
                    "there is \"Choose visibility *\"\n" +
                    "Change the drop down to 🔒Private</b>\n\n" +
                    "We want the external repository to be empty, so leave the next three options alone.\n\n" +
                    "So under \"Add README\", leave it \"Off\"\n" +
                    "Under \"Add .gitignore\", leave it at \"No .gitignore\"\n" +
                    "Under \"Add license\", leave it at \"No licence\"\n\n" +
                    "Click the green button called \"Create repository\""
                );
            }
        }

        if (git_gh_cli_status_label != null) {
            if (!git_gh_available) {
                git_gh_cli_status_label.set_text(
                    "GitHub CLI not detected. Install `gh` to enable automatic username and repo creation."
                );
            } else if (!git_gh_authenticated) {
                git_gh_cli_status_label.set_text(
                    "GitHub CLI detected, but not authenticated. Run `gh auth login` in a terminal to enable automation."
                );
            } else {
                git_gh_cli_status_label.set_text(
                    "GitHub CLI authenticated as `%s`. Use the automatic button above to create repo, set remote, and push."
                        .printf(git_gh_login)
                );
            }
        }
        if (git_gh_cli_auto_btn != null) {
            git_gh_cli_auto_btn.set_visible(git_gh_available);
            git_gh_cli_auto_btn.set_sensitive(git_gh_authenticated && git_gh_login.strip().length > 0);
        }
        if (git_gh_cli_guided_btn != null) {
            git_gh_cli_guided_btn.set_visible(git_gh_available);
            git_gh_cli_guided_btn.set_sensitive(git_gh_authenticated && git_gh_login.strip().length > 0);
        }
        if (git_guided_create_repo_cli_btn != null) {
            git_guided_create_repo_cli_btn.set_visible(git_gh_authenticated && git_gh_login.strip().length > 0);
            git_guided_create_repo_cli_btn.set_sensitive(git_gh_authenticated && git_gh_login.strip().length > 0);
        }
    }

    private async void check_github_cli_state() {
        git_gh_available = false;
        git_gh_authenticated = false;
        git_gh_login = "";

        var auth_output = yield run_capture_command_async({
            "gh",
            "auth",
            "status",
            "-h",
            "github.com"
        });
        var auth_exit = command_exit_code(auth_output);
        if (auth_exit < 0) {
            refresh_git_cli_controls();
            return;
        }

        git_gh_available = true;
        if (auth_exit != 0) {
            refresh_git_cli_controls();
            return;
        }

        var login_output = yield run_capture_command_async({
            "gh",
            "api",
            "user",
            "-q",
            ".login"
        });
        var login_exit = command_exit_code(login_output);
        if (login_exit != 0) {
            refresh_git_cli_controls();
            return;
        }

        git_gh_authenticated = true;
        git_gh_login = strip_exit_code_prefix(login_output).strip();
        if (git_gh_login.length > 0) {
            if (settings != null) {
                settings.set_string(AppSettings.KEY_GIT_GITHUB_USERNAME, git_gh_login);
            }
            if (git_guided_username_entry != null) {
                git_guided_username_entry.set_text(git_gh_login);
                refresh_guided_next_button_state();
            }
        }
        refresh_git_cli_controls();
    }

    private async void create_guided_repository_with_cli() {
        var username = guided_github_username();
        var repo_name = git_guided_repo_name_entry != null ? git_guided_repo_name_entry.get_text().strip() : "";
        if (username.length == 0 || repo_name.length == 0) {
            toast_requested("GitHub username and repository name are required.");
            return;
        }
        if (git_guided_create_repo_cli_btn != null) {
            git_guided_create_repo_cli_btn.set_sensitive(false);
        }
        if (git_guided_repo_next_btn != null) {
            git_guided_repo_next_btn.set_sensitive(false);
        }
        if (git_guided_repo_status_label != null) {
            git_guided_repo_status_label.set_text("Creating private repository via GitHub CLI...");
        }

        var command_output = yield run_capture_command_async({
            "gh",
            "repo",
            "create",
            "%s/%s".printf(username, repo_name),
            "--private",
            "--disable-issues",
            "--disable-wiki",
            "--confirm"
        });
        var created_ok = command_exit_code(command_output) == 0;
        string check_error = "";
        var exists = yield guided_repository_exists_on_github(username, repo_name, out check_error);

        if (git_guided_create_repo_cli_btn != null) {
            git_guided_create_repo_cli_btn.set_sensitive(true);
        }
        if (git_guided_repo_next_btn != null) {
            git_guided_repo_next_btn.set_sensitive(true);
        }

        if (exists) {
            if (git_guided_repo_status_label != null) {
                git_guided_repo_status_label.set_text(
                    created_ok
                        ? "Repository created with GitHub CLI and verified."
                        : "Repository available and verified."
                );
            }
            git_guided_part4_username = username;
            git_guided_part4_repo_name = repo_name;
            if (git_guided_push_intro_label != null) {
                var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
                git_guided_push_intro_label.set_text(
                    "We'll now save this remote and push your cards.\nRemote: %s".printf(remote_url)
                );
            }
            if (git_guided_push_status_label != null) {
                git_guided_push_status_label.set_text("");
            }
            git_sync_stack.set_visible_child_name("guided-part4");
            return;
        }

        var details = strip_exit_code_prefix(command_output).strip();
        if (details.length == 0) {
            details = check_error.length > 0 ? check_error : "Repository could not be created.";
        }
        if (git_guided_repo_status_label != null) {
            git_guided_repo_status_label.set_text(details);
        }
        error_reported("GitHub CLI repository creation failed", details);
    }

    private string normalize_repository_name(string project_name) {
        var name = project_name.strip();
        if (name.length == 0) {
            return "";
        }

        var out_name = new StringBuilder();
        for (int i = 0; i < name.length; i++) {
            var c = name.get_char(i);
            if ((c >= 'a' && c <= 'z') ||
                (c >= 'A' && c <= 'Z') ||
                (c >= '0' && c <= '9') ||
                c == '-' || c == '_' || c == '.') {
                out_name.append_unichar(c);
                continue;
            }
            if (c == ' ' || c == '/' || c == '\\') {
                out_name.append_c('-');
            }
        }

        return out_name.str.strip();
    }

    private async void run_github_cli_auto_sync() {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (selected_project == null) {
            toast_requested("Select a project first.");
            return;
        }
        if (api == null) {
            error_reported("Git sync failed", "Backend API client is not ready.");
            return;
        }
        if (!git_gh_authenticated || git_gh_login.strip().length == 0) {
            toast_requested("GitHub CLI is not authenticated. Run `gh auth login` first.");
            return;
        }

        var username = git_gh_login.strip();
        var repo_name = normalize_repository_name(selected_project.name ?? "");
        if (repo_name.length == 0) {
            error_reported("Git sync failed",
                           "Project name does not produce a valid repository name. Rename project or use manual setup.");
            return;
        }

        if (git_gh_cli_auto_btn != null) {
            git_gh_cli_auto_btn.set_sensitive(false);
        }
        if (git_gh_cli_guided_btn != null) {
            git_gh_cli_guided_btn.set_sensitive(false);
        }
        if (git_gh_cli_status_label != null) {
            git_gh_cli_status_label.set_text(
                "GitHub CLI: creating private repo `%s/%s`...".printf(username, repo_name)
            );
        }

        var create_output = yield run_capture_command_async({
            "gh",
            "repo",
            "create",
            "%s/%s".printf(username, repo_name),
            "--private",
            "--disable-issues",
            "--disable-wiki",
            "--confirm"
        });
        var create_ok = command_exit_code(create_output) == 0;
        string check_error = "";
        var exists = yield guided_repository_exists_on_github(username, repo_name, out check_error);
        if (!exists) {
            var details = strip_exit_code_prefix(create_output).strip();
            if (details.length == 0) {
                details = check_error.length > 0 ? check_error : "Repository could not be created.";
            }
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text("GitHub CLI setup failed: %s".printf(details));
            }
            error_reported("GitHub CLI setup failed", details);
            refresh_git_cli_controls();
            return;
        }

        var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
        var updated_at = new DateTime.now_utc().to_unix();
        GitTestRemoteResult? test_result = null;
        GitPushResult? push_result = null;

        try {
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text("Saving remote and testing connectivity...");
            }
            yield api.set_project_git_remote(selected_project.project_id, remote_url, updated_at);
            test_result = yield api.test_project_git_remote(selected_project.project_id, remote_url, "");
            if (test_result.status == "reachable") {
                if (git_gh_cli_status_label != null) {
                    git_gh_cli_status_label.set_text("Remote reachable. Pushing cards...");
                }
                push_result = yield api.push_project_git(selected_project.project_id, "", true);
            }
        } catch (Error e) {
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text("GitHub CLI setup failed: %s".printf(e.message));
            }
            error_reported("Git sync failed", e.message);
            refresh_git_cli_controls();
            return;
        }

        var status = new StringBuilder();
        status.append("GitHub CLI: %s repo `%s/%s`. ".printf(
            create_ok ? "created" : "using existing",
            username,
            repo_name
        ));
        if (test_result != null) {
            status.append("Remote test: %s".printf(test_result.status));
            if (test_result.error_message.strip().length > 0) {
                status.append(" (%s)".printf(test_result.error_message.strip()));
            }
            status.append(". ");
        }
        if (push_result != null) {
            status.append("Push: %s".printf(push_result.status));
            if (push_result.error_message.strip().length > 0) {
                status.append(" (%s)".printf(push_result.error_message.strip()));
            }
            status.append(".");
            if (push_result.status == "pushed" || push_result.status == "up_to_date") {
                toast_requested("GitHub CLI sync setup completed.");
            }
        } else {
            status.append("Push not run.");
        }
        if (git_gh_cli_status_label != null) {
            git_gh_cli_status_label.set_text(status.str);
        }

        refresh_git_cli_controls();
    }

    private Gtk.Widget build_git_sync_guided_part2_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var part_title = new Gtk.Label("Part 2/4: SSH Key") { xalign = 0.0f };
        part_title.add_css_class("title-5");
        box.append(part_title);

        var body = new Gtk.Label(
            "We'll set up SSH so Holder can sync your project with GitHub."
        ) { xalign = 0.0f };
        body.set_wrap(true);
        body.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        body.add_css_class("dim-label");
        box.append(body);

        git_guided_ssh_status_label = new Gtk.Label("Checking SSH setup...") { xalign = 0.0f };
        git_guided_ssh_status_label.set_wrap(true);
        git_guided_ssh_status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        box.append(git_guided_ssh_status_label);

        git_guided_missing_key_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        var email_label = new Gtk.Label("Email address for your SSH key") { xalign = 0.0f };
        git_guided_email_entry = new Gtk.Entry();
        git_guided_email_entry.set_placeholder_text("you@example.com");
        git_guided_generate_key_btn = new Gtk.Button.with_label("Generate SSH Key");
        git_guided_generate_key_btn.set_halign(Gtk.Align.START);
        git_guided_generate_key_btn.clicked.connect(() => {
            generate_guided_ssh_key.begin();
        });
        git_guided_missing_key_box.append(email_label);
        git_guided_missing_key_box.append(git_guided_email_entry);
        git_guided_missing_key_box.append(git_guided_generate_key_btn);
        box.append(git_guided_missing_key_box);

        git_guided_key_ready_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        var key_label = new Gtk.Label("Public key (copy and paste into GitHub)") { xalign = 0.0f };
        git_guided_pubkey_view = new Gtk.TextView();
        git_guided_pubkey_view.set_editable(false);
        git_guided_pubkey_view.set_cursor_visible(false);
        git_guided_pubkey_view.set_wrap_mode(Gtk.WrapMode.CHAR);
        git_guided_pubkey_view.set_monospace(true);
        var key_scroll = new Gtk.ScrolledWindow();
        key_scroll.set_min_content_height(80);
        key_scroll.set_child(git_guided_pubkey_view);
        git_guided_copy_key_btn = new Gtk.Button.with_label("Copy Public Key");
        git_guided_copy_key_btn.set_halign(Gtk.Align.START);
        git_guided_copy_key_btn.clicked.connect(() => {
            copy_guided_public_key();
        });
        git_guided_key_ready_box.append(key_label);
        git_guided_key_ready_box.append(key_scroll);
        git_guided_key_ready_box.append(git_guided_copy_key_btn);
        box.append(git_guided_key_ready_box);

        git_guided_open_keys_btn = new Gtk.Button.with_label("Open GitHub SSH Keys Page");
        git_guided_open_keys_btn.set_halign(Gtk.Align.START);
        git_guided_open_keys_btn.clicked.connect(() => {
            open_guided_github_ssh_keys_page();
        });
        box.append(git_guided_open_keys_btn);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var back_btn = new Gtk.Button.with_label("Back");
        back_btn.clicked.connect(() => {
            git_sync_stack.set_visible_child_name("guided-part1");
        });
        var recheck_btn = new Gtk.Button.with_label("Re-check");
        recheck_btn.clicked.connect(() => {
            check_guided_ssh_state.begin();
        });
        var next_btn = new Gtk.Button.with_label("Next");
        next_btn.clicked.connect(() => {
            git_sync_stack.set_visible_child_name("guided-part3");
            refresh_guided_repo_name_default();
        });
        actions.append(back_btn);
        actions.append(recheck_btn);
        actions.append(next_btn);
        box.append(actions);

        set_guided_key_ui_visibility(false);
        return box;
    }

    private Gtk.Widget build_git_sync_guided_part3_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var part_title = new Gtk.Label("Part 3/4: Repository") { xalign = 0.0f };
        part_title.add_css_class("title-5");
        box.append(part_title);

        git_guided_repo_mode_label = new Gtk.Label("") { xalign = 0.0f };
        git_guided_repo_mode_label.set_wrap(true);
        git_guided_repo_mode_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_guided_repo_mode_label.add_css_class("dim-label");
        box.append(git_guided_repo_mode_label);

        var create_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        git_guided_repo_manual_label = new Gtk.Label("Create a new repository:") { xalign = 0.0f };
        git_guided_repo_manual_label.add_css_class("dim-label");
        git_guided_repo_create_link = new Gtk.LinkButton.with_label("https://github.com/new", "https://github.com/new");
        git_guided_repo_create_link.set_halign(Gtk.Align.START);
        create_row.append(git_guided_repo_manual_label);
        create_row.append(git_guided_repo_create_link);
        box.append(create_row);

        git_guided_repo_manual_instructions_label = new Gtk.Label(
            "Fill in the repository name, and you need to tell us the same name below.\n\n" +
            "You can leave the description blank.\n\n" +
            "<b>Under 2. Configuration\n" +
            "there is \"Choose visibility *\"\n" +
            "Change the drop down to 🔒Private</b>\n\n" +
            "We want the external repository to be empty, so leave the next three options alone.\n\n" +
            "So under \"Add README\", leave it \"Off\"\n" +
            "Under \"Add .gitignore\", leave it at \"No .gitignore\"\n" +
            "Under \"Add license\", leave it at \"No licence\"\n\n" +
            "Click the green button called \"Create repository\""
        ) { xalign = 0.0f };
        git_guided_repo_manual_instructions_label.set_use_markup(true);
        git_guided_repo_manual_instructions_label.set_wrap(true);
        git_guided_repo_manual_instructions_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_guided_repo_manual_instructions_label.add_css_class("dim-label");
        box.append(git_guided_repo_manual_instructions_label);

        var repo_label = new Gtk.Label("The repository name:") { xalign = 0.0f };
        box.append(repo_label);
        git_guided_repo_name_entry = new Gtk.Entry();
        git_guided_repo_name_entry.set_hexpand(true);
        git_guided_repo_name_entry.changed.connect(() => {
            if (git_guided_repo_status_label != null) {
                git_guided_repo_status_label.set_text("");
            }
        });
        box.append(git_guided_repo_name_entry);

        git_guided_repo_status_label = new Gtk.Label("") { xalign = 0.0f };
        git_guided_repo_status_label.set_wrap(true);
        git_guided_repo_status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_guided_repo_status_label.add_css_class("dim-label");
        box.append(git_guided_repo_status_label);

        git_guided_create_repo_cli_btn = new Gtk.Button.with_label("Create Private Repo with GitHub CLI");
        git_guided_create_repo_cli_btn.set_halign(Gtk.Align.START);
        git_guided_create_repo_cli_btn.set_visible(false);
        git_guided_create_repo_cli_btn.clicked.connect(() => {
            create_guided_repository_with_cli.begin();
        });
        box.append(git_guided_create_repo_cli_btn);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var back_btn = new Gtk.Button.with_label("Back");
        back_btn.clicked.connect(() => {
            git_sync_stack.set_visible_child_name("guided-part2");
        });
        git_guided_repo_next_btn = new Gtk.Button.with_label("Next");
        git_guided_repo_next_btn.clicked.connect(() => {
            verify_guided_repository_exists.begin();
        });
        actions.append(back_btn);
        actions.append(git_guided_repo_next_btn);
        box.append(actions);

        refresh_guided_repo_name_default();
        refresh_git_cli_controls();
        return box;
    }

    private Gtk.Widget build_git_sync_guided_part4_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var part_title = new Gtk.Label("Part 4/4: Push Cards") { xalign = 0.0f };
        part_title.add_css_class("title-5");
        box.append(part_title);

        git_guided_push_intro_label = new Gtk.Label("") { xalign = 0.0f };
        git_guided_push_intro_label.set_wrap(true);
        git_guided_push_intro_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_guided_push_intro_label.add_css_class("dim-label");
        box.append(git_guided_push_intro_label);

        git_guided_push_status_label = new Gtk.Label("") { xalign = 0.0f };
        git_guided_push_status_label.set_wrap(true);
        git_guided_push_status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_guided_push_status_label.add_css_class("dim-label");
        box.append(git_guided_push_status_label);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var back_btn = new Gtk.Button.with_label("Back");
        back_btn.clicked.connect(() => {
            git_sync_stack.set_visible_child_name("guided-part3");
        });
        git_guided_push_btn = new Gtk.Button.with_label("Push Cards");
        git_guided_push_btn.clicked.connect(() => {
            if (git_guided_part4_username.length == 0 || git_guided_part4_repo_name.length == 0) {
                toast_requested("GitHub username and repository name are required.");
                git_sync_stack.set_visible_child_name("guided-part3");
                return;
            }
            run_guided_part4_setup.begin(git_guided_part4_username, git_guided_part4_repo_name);
        });
        actions.append(back_btn);
        actions.append(git_guided_push_btn);
        box.append(actions);
        return box;
    }

    private Gtk.Widget build_git_sync_provider_page() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

        var part_title = new Gtk.Label("Provider setup") { xalign = 0.0f };
        part_title.add_css_class("title-5");
        box.append(part_title);

        var intro = new Gtk.Label(
            "Choose a provider and transport, then set namespace and repository. " +
            "Holder will generate a remote URL that you can edit before saving."
        ) { xalign = 0.0f };
        intro.set_wrap(true);
        intro.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        intro.add_css_class("dim-label");
        box.append(intro);

        var provider_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var provider_label = new Gtk.Label("Provider:") { xalign = 0.0f };
        provider_label.set_size_request(130, -1);
        git_provider_name_model = new Gtk.StringList(null);
        git_provider_dropdown = new Gtk.DropDown(git_provider_name_model, null);
        git_provider_dropdown.set_hexpand(true);
        git_provider_dropdown.notify["selected"].connect(() => {
            refresh_provider_transport_options();
            update_provider_remote_preview();
        });
        provider_row.append(provider_label);
        provider_row.append(git_provider_dropdown);
        box.append(provider_row);

        var transport_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var transport_label = new Gtk.Label("Transport:") { xalign = 0.0f };
        transport_label.set_size_request(130, -1);
        git_provider_transport_dropdown = new Gtk.DropDown(new Gtk.StringList(null), null);
        git_provider_transport_dropdown.notify["selected"].connect(() => {
            update_provider_remote_preview();
        });
        transport_row.append(transport_label);
        transport_row.append(git_provider_transport_dropdown);
        box.append(transport_row);

        var namespace_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var namespace_label = new Gtk.Label("Account/Namespace:") { xalign = 0.0f };
        namespace_label.set_size_request(130, -1);
        git_provider_namespace_entry = new Gtk.Entry();
        git_provider_namespace_entry.set_hexpand(true);
        git_provider_namespace_entry.changed.connect(() => {
            update_provider_remote_preview();
        });
        namespace_row.append(namespace_label);
        namespace_row.append(git_provider_namespace_entry);
        box.append(namespace_row);

        var repo_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var repo_label = new Gtk.Label("Repository:") { xalign = 0.0f };
        repo_label.set_size_request(130, -1);
        git_provider_repo_entry = new Gtk.Entry();
        git_provider_repo_entry.set_hexpand(true);
        git_provider_repo_entry.changed.connect(() => {
            update_provider_remote_preview();
        });
        repo_row.append(repo_label);
        repo_row.append(git_provider_repo_entry);
        box.append(repo_row);

        var host_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        git_provider_host_row = host_row;
        var host_label = new Gtk.Label("Host (if needed):") { xalign = 0.0f };
        host_label.set_size_request(130, -1);
        git_provider_host_entry = new Gtk.Entry();
        git_provider_host_entry.set_placeholder_text("git.example.com");
        git_provider_host_entry.set_hexpand(true);
        git_provider_host_entry.changed.connect(() => {
            update_provider_remote_preview();
        });
        host_row.append(host_label);
        host_row.append(git_provider_host_entry);
        box.append(host_row);

        var preview_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var preview_label = new Gtk.Label("Remote URL:") { xalign = 0.0f };
        preview_label.set_size_request(130, -1);
        git_provider_remote_entry = new Gtk.Entry();
        git_provider_remote_entry.set_hexpand(true);
        preview_row.append(preview_label);
        preview_row.append(git_provider_remote_entry);
        box.append(preview_row);

        git_provider_template_label = new Gtk.Label("") { xalign = 0.0f };
        git_provider_template_label.set_wrap(true);
        git_provider_template_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_provider_template_label.add_css_class("dim-label");
        box.append(git_provider_template_label);

        var branch_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var branch_label = new Gtk.Label("Branch:") { xalign = 0.0f };
        branch_label.set_size_request(130, -1);
        git_provider_branch_entry = new Gtk.Entry();
        git_provider_branch_entry.set_placeholder_text("local default");
        branch_row.append(branch_label);
        branch_row.append(git_provider_branch_entry);
        box.append(branch_row);

        git_provider_status_label = new Gtk.Label("") { xalign = 0.0f };
        git_provider_status_label.set_wrap(true);
        git_provider_status_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_provider_status_label.add_css_class("dim-label");
        box.append(git_provider_status_label);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var back_btn = new Gtk.Button.with_label("Back");
        back_btn.clicked.connect(() => {
            git_sync_stack.set_visible_child_name("start");
        });
        git_provider_apply_btn = new Gtk.Button.with_label("Save + Test + Push");
        git_provider_apply_btn.clicked.connect(() => {
            run_provider_remote_setup.begin();
        });
        actions.append(back_btn);
        actions.append(git_provider_apply_btn);
        box.append(actions);

        refresh_provider_setup_defaults();
        return box;
    }

    private void refresh_guided_ssh_email_default() {
        if (git_guided_email_entry == null) {
            return;
        }
        if (git_guided_email_entry.get_text().strip().length > 0) {
            return;
        }
        var stored_username = git_guided_username_entry != null
            ? git_guided_username_entry.get_text().strip()
            : "";
        if (stored_username.length > 0) {
            git_guided_email_entry.set_text("%s@users.noreply.github.com".printf(stored_username));
        }
    }

    private void refresh_provider_setup_defaults() {
        if (git_provider_repo_entry != null) {
            var selected_project = project_selection != null
                ? project_selection.get_selected_item() as Project
                : null;
            var name = selected_project != null ? selected_project.name : "";
            git_provider_repo_entry.set_text(normalize_repository_name(name));
        }
        if (git_provider_namespace_entry != null &&
            git_provider_namespace_entry.get_text().strip().length == 0) {
            var username = guided_github_username();
            if (username.length > 0) {
                git_provider_namespace_entry.set_text(username);
            }
        }
        update_provider_remote_preview();
    }

    private async void refresh_provider_setup_catalog() {
        if (api == null) {
            return;
        }
        try {
            var providers = yield api.list_git_provider_catalog();
            git_provider_entries.clear();
            if (git_provider_name_model != null) {
                git_provider_name_model.splice(0, git_provider_name_model.get_n_items(), null);
            }
            foreach (var provider in providers) {
                git_provider_entries.add(provider);
                if (git_provider_name_model != null) {
                    git_provider_name_model.append("%s (%s)".printf(provider.name, provider.id));
                }
            }
            if (git_provider_dropdown != null && providers.size > 0) {
                git_provider_dropdown.set_selected(0);
            }
            refresh_provider_transport_options();
            update_provider_remote_preview();
        } catch (Error e) {
            if (git_provider_status_label != null) {
                git_provider_status_label.set_text("Provider catalog load failed: %s".printf(e.message));
            }
            error_reported("Git provider catalog refresh failed", e.message);
        }
    }

    private GitProviderCatalogEntry? selected_git_provider_entry() {
        if (git_provider_dropdown == null) {
            return null;
        }
        var selected = git_provider_dropdown.get_selected();
        if (selected == Gtk.INVALID_LIST_POSITION || selected >= git_provider_entries.size) {
            return null;
        }
        return git_provider_entries[(int) selected];
    }

    private void refresh_provider_transport_options() {
        if (git_provider_transport_dropdown == null) {
            return;
        }
        var provider = selected_git_provider_entry();
        string[] options = {};
        if (provider != null && provider.transports_summary.strip().length > 0) {
            options = provider.transports_summary.split(",");
        }
        var normalized = new Gee.ArrayList<string>();
        foreach (var raw in options) {
            var item = raw.strip();
            if (item.length > 0) {
                normalized.add(item);
            }
        }
        if (normalized.size == 0) {
            normalized.add("ssh");
            normalized.add("https");
        }

        var model = new Gtk.StringList(null);
        foreach (var item in normalized) {
            model.append(item);
        }
        git_provider_transport_dropdown.set_model(model);

        uint selected_idx = 0;
        if (provider != null && provider.preferred_transport.strip().length > 0) {
            for (int i = 0; i < normalized.size; i++) {
                if (normalized[i] == provider.preferred_transport) {
                    selected_idx = (uint) i;
                    break;
                }
            }
        }
        git_provider_transport_dropdown.set_selected(selected_idx);
    }

    private string selected_provider_transport() {
        if (git_provider_transport_dropdown == null) {
            return "ssh";
        }
        var model = git_provider_transport_dropdown.get_model() as Gtk.StringList;
        if (model == null || model.get_n_items() == 0) {
            return "ssh";
        }
        var idx = git_provider_transport_dropdown.get_selected();
        if (idx == Gtk.INVALID_LIST_POSITION || idx >= model.get_n_items()) {
            idx = 0;
        }
        var value = model.get_string(idx);
        return value != null ? value : "ssh";
    }

    private string fill_remote_template(string template_text,
                                        string namespace_value,
                                        string repo_value,
                                        string host_value) {
        var output = template_text;
        output = output.replace("{owner}", namespace_value);
        output = output.replace("{workspace}", namespace_value);
        output = output.replace("{user}", namespace_value);
        output = output.replace("{org}", namespace_value);
        output = output.replace("{project}", namespace_value);
        output = output.replace("{repo}", repo_value);
        output = output.replace("{host}", host_value);
        output = output.replace("{region}", host_value);
        return output;
    }

    private void update_provider_remote_preview() {
        if (git_provider_remote_entry == null) {
            return;
        }
        var provider = selected_git_provider_entry();
        if (provider == null) {
            git_provider_remote_entry.set_text("");
            if (git_provider_template_label != null) {
                git_provider_template_label.set_text("No provider selected.");
            }
            return;
        }

        var namespace_value = git_provider_namespace_entry != null
            ? git_provider_namespace_entry.get_text().strip()
            : "";
        var repo_value = git_provider_repo_entry != null
            ? git_provider_repo_entry.get_text().strip()
            : "";
        var host_value = git_provider_host_entry != null
            ? git_provider_host_entry.get_text().strip()
            : "";
        var transport = selected_provider_transport();
        var template_text = transport == "https" ? provider.https_example : provider.ssh_example;
        if (template_text.strip().length == 0) {
            template_text = transport == "https"
                ? "https://{host}/{owner}/{repo}.git"
                : "git@{host}:{owner}/{repo}.git";
        }
        if (host_value.length == 0) {
            if (provider.id == "github") host_value = "github.com";
            else if (provider.id == "gitlab") host_value = "gitlab.com";
            else if (provider.id == "bitbucket") host_value = "bitbucket.org";
            else if (provider.id == "codeberg") host_value = "codeberg.org";
            else if (provider.id == "sourcehut") host_value = "git.sr.ht";
        }

        var remote_url = fill_remote_template(template_text, namespace_value, repo_value, host_value);
        if (git_provider_host_row != null) {
            var needs_host = template_text.contains("{host}") || template_text.contains("{region}");
            git_provider_host_row.set_visible(needs_host);
            if (!needs_host) {
                git_provider_host_entry.set_text("");
            }
        }
        git_provider_remote_entry.set_text(remote_url);
        if (git_provider_template_label != null) {
            git_provider_template_label.set_text(
                "Template: %s\nYou can edit Remote URL directly before saving.".printf(template_text)
            );
        }
    }

    private async void run_provider_remote_setup() {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (selected_project == null) {
            toast_requested("Select a project first.");
            return;
        }
        var remote_url = git_provider_remote_entry != null ? git_provider_remote_entry.get_text().strip() : "";
        var branch = git_provider_branch_entry != null ? git_provider_branch_entry.get_text().strip() : "";
        if (remote_url.length == 0) {
            toast_requested("Remote URL is required.");
            return;
        }
        yield apply_project_git_remote_and_sync(
            selected_project,
            remote_url,
            branch,
            git_provider_status_label,
            git_provider_apply_btn
        );
    }

    private void refresh_guided_repo_name_default() {
        if (git_guided_repo_name_entry == null) {
            return;
        }
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (selected_project != null && selected_project.name != null) {
            git_guided_repo_name_entry.set_text(selected_project.name);
        } else {
            git_guided_repo_name_entry.set_text("");
        }
    }

    private string guided_github_username() {
        if (git_guided_username_entry != null) {
            var from_entry = git_guided_username_entry.get_text().strip();
            if (from_entry.length > 0) {
                return from_entry;
            }
        }
        if (settings != null) {
            return settings.get_string(AppSettings.KEY_GIT_GITHUB_USERNAME).strip();
        }
        return "";
    }

    private async void verify_guided_repository_exists() {
        var username = guided_github_username();
        var repo_name = git_guided_repo_name_entry != null ? git_guided_repo_name_entry.get_text().strip() : "";
        if (username.length == 0) {
            toast_requested("GitHub username is required.");
            git_sync_stack.set_visible_child_name("guided-part1");
            return;
        }
        if (repo_name.length == 0) {
            toast_requested("Repository name is required.");
            return;
        }

        if (git_guided_repo_next_btn != null) {
            git_guided_repo_next_btn.set_sensitive(false);
        }
        git_guided_repo_status_label.set_text("Checking whether repository exists on GitHub...");

        string check_error = "";
        var exists = yield guided_repository_exists_on_github(username, repo_name, out check_error);

        if (git_guided_repo_next_btn != null) {
            git_guided_repo_next_btn.set_sensitive(true);
        }

        if (exists) {
            git_guided_repo_status_label.set_text("Repository found on GitHub.");
            git_guided_part4_username = username;
            git_guided_part4_repo_name = repo_name;
            if (git_guided_push_intro_label != null) {
                var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
                git_guided_push_intro_label.set_text(
                    "We'll now save this remote and push your cards.\nRemote: %s".printf(remote_url)
                );
            }
            if (git_guided_push_status_label != null) {
                git_guided_push_status_label.set_text("");
            }
            git_sync_stack.set_visible_child_name("guided-part4");
            return;
        }

        var details = check_error.length > 0 ? check_error : "Repository not found.";
        git_guided_repo_status_label.set_text(details);
        error_reported("Repository check failed",
                       "Could not find https://github.com/%s/%s . Create it first, then click Next again."
                           .printf(username, repo_name));
    }

    private async void run_guided_part4_setup(string username, string repo_name) {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        if (selected_project == null) {
            toast_requested("Select a project first.");
            return;
        }
        if (api == null) {
            error_reported("Git sync failed", "Backend API client is not ready.");
            return;
        }

        var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
        var updated_at = new DateTime.now_utc().to_unix();
        GitTestRemoteResult? test_result = null;
        GitPushResult? push_result = null;
        Project? refreshed_project = null;

        if (git_guided_push_btn != null) {
            git_guided_push_btn.set_sensitive(false);
        }
        if (git_guided_push_status_label != null) {
            git_guided_push_status_label.set_text("Saving remote and testing connectivity...");
        }

        try {
            yield api.set_project_git_remote(selected_project.project_id, remote_url, updated_at);
            test_result = yield api.test_project_git_remote(selected_project.project_id, remote_url, "");

            if (test_result.status == "reachable") {
                if (git_guided_push_status_label != null) {
                    git_guided_push_status_label.set_text("Remote reachable. Pushing project data...");
                }
                push_result = yield api.push_project_git(selected_project.project_id, "", true);
            } else {
                if (git_guided_push_status_label != null) {
                    git_guided_push_status_label.set_text("Remote test result: %s".printf(test_result.status));
                }
            }
            var projects = yield api.list_projects();
            foreach (var project in projects) {
                if (project.project_id == selected_project.project_id) {
                    refreshed_project = project;
                    break;
                }
            }
        } catch (Error e) {
            if (git_guided_push_btn != null) {
                git_guided_push_btn.set_sensitive(true);
            }
            error_reported("Git sync failed", e.message);
            return;
        }

        if (git_guided_push_btn != null) {
            git_guided_push_btn.set_sensitive(true);
        }
        if (git_guided_push_status_label != null) {
            var lines = new StringBuilder();
            if (test_result != null) {
                lines.append("Remote test: %s".printf(test_result.status));
                if (test_result.error_message.strip().length > 0) {
                    lines.append(" (%s)".printf(test_result.error_message.strip()));
                }
                lines.append("\n");
            } else {
                lines.append("Remote test: not run\n");
            }

            if (push_result != null) {
                lines.append("Push: %s".printf(push_result.status));
                if (push_result.error_message.strip().length > 0) {
                    lines.append(" (%s)".printf(push_result.error_message.strip()));
                }
                lines.append("\n");
                if (push_result.next_action.strip().length > 0) {
                    lines.append("Next action: %s\n".printf(push_result.next_action));
                }
                if (push_result.status == "pushed" || push_result.status == "up_to_date") {
                    toast_requested("Git sync setup completed.");
                }
            } else {
                lines.append("Push: not run\n");
            }
            if (refreshed_project != null) {
                lines.append("\n");
                lines.append("Sync state: ");
                var status = refreshed_project.sync.last_push_status.strip();
                lines.append(status.length > 0 ? status : "unknown");
                lines.append("\n");
                lines.append("Last push: ");
                lines.append(format_sync_time(
                    refreshed_project.sync.has_last_push_at,
                    refreshed_project.sync.last_push_at
                ));
                lines.append("\n");
                lines.append("Retry count: %d".printf(refreshed_project.sync.retry_count));
                if (refreshed_project.sync.last_sync_error.strip().length > 0) {
                    lines.append("\n");
                    lines.append("Error: %s".printf(refreshed_project.sync.last_sync_error));
                }
            }
            git_guided_push_status_label.set_text(lines.str.strip());
        }
    }

    private string format_sync_time(bool has_timestamp, int64 timestamp) {
        if (!has_timestamp || timestamp <= 0) {
            return "never";
        }
        var now = new DateTime.now_utc().to_unix();
        return TextUtils.format_relative_time(now, timestamp);
    }

    private async bool guided_repository_exists_on_github(string username,
                                                          string repo_name,
                                                          out string error_text) {
        error_text = "";
        var remote = "git@github.com:%s/%s.git".printf(username, repo_name);
        var output = yield run_capture_command_async({
            "git",
            "ls-remote",
            remote
        });
        if (output.has_prefix("__EXIT_CODE__:0")) {
            return true;
        }
        var details = output.replace("__EXIT_CODE__:", "").strip();
        if (details.length == 0) {
            details = "Repository not reachable over SSH.";
        }
        error_text = "Could not verify %s via SSH. %s".printf(remote, details);
        return false;
    }

    private void set_guided_key_ui_visibility(bool has_key) {
        if (git_guided_missing_key_box != null) {
            git_guided_missing_key_box.set_visible(!has_key);
        }
        if (git_guided_key_ready_box != null) {
            git_guided_key_ready_box.set_visible(has_key && !git_guided_github_authenticated);
        }
        if (git_guided_copy_key_btn != null) {
            git_guided_copy_key_btn.set_sensitive(has_key &&
                                                  !git_guided_github_authenticated &&
                                                  git_guided_public_key.strip().length > 0);
        }
        if (git_guided_open_keys_btn != null) {
            git_guided_open_keys_btn.set_visible(!git_guided_github_authenticated);
        }
    }

    private string read_text_file_or_empty(string path) {
        try {
            string content;
            FileUtils.get_contents(path, out content);
            return content ?? "";
        } catch (Error e) {
            return "";
        }
    }

    private string? guided_public_key_path_or_null() {
        var home = Environment.get_home_dir();
        if (home == null || home.strip().length == 0) {
            return null;
        }
        var ed = Path.build_filename(home, ".ssh", "id_ed25519.pub");
        if (FileUtils.test(ed, FileTest.EXISTS)) {
            return ed;
        }
        var rsa = Path.build_filename(home, ".ssh", "id_rsa.pub");
        if (FileUtils.test(rsa, FileTest.EXISTS)) {
            return rsa;
        }
        return null;
    }

    private async void check_guided_ssh_state() {
        if (git_guided_check_running) {
            return;
        }
        git_guided_check_running = true;
        git_guided_ssh_status_label.set_text("Checking SSH setup...");

        var pub_path = guided_public_key_path_or_null();
        if (pub_path == null) {
            git_guided_github_authenticated = false;
            git_guided_public_key = "";
            git_guided_pubkey_view.buffer.set_text("", -1);
            set_guided_key_ui_visibility(false);
            git_guided_ssh_status_label.set_text("No SSH key found. Enter your email address and generate one.");
            git_guided_check_running = false;
            return;
        }

        git_guided_public_key = read_text_file_or_empty(pub_path).strip();
        git_guided_pubkey_view.buffer.set_text(git_guided_public_key, -1);
        set_guided_key_ui_visibility(git_guided_public_key.length > 0);

        var probe_output = yield run_capture_command_async({
            "ssh",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=5",
            "-T",
            "git@github.com"
        });
        var probe_plain = strip_exit_code_prefix(probe_output);
        var probe = probe_plain.down();
        if (probe.contains("successfully authenticated")) {
            git_guided_github_authenticated = true;
            set_guided_key_ui_visibility(true);
            git_guided_ssh_status_label.set_text("SSH key found and authenticated with GitHub. You're all set.");
        } else if (probe.contains("permission denied")) {
            git_guided_github_authenticated = false;
            set_guided_key_ui_visibility(true);
            git_guided_ssh_status_label.set_text(
                "SSH key found locally, but GitHub rejected authentication. Copy this key and add it at GitHub SSH settings."
            );
        } else if (probe_plain.strip().length > 0) {
            git_guided_github_authenticated = false;
            set_guided_key_ui_visibility(true);
            git_guided_ssh_status_label.set_text(
                "SSH key found locally. GitHub verification result: %s".printf(probe_plain.strip())
            );
        } else {
            git_guided_github_authenticated = false;
            set_guided_key_ui_visibility(true);
            git_guided_ssh_status_label.set_text("SSH key found locally. Could not verify with GitHub.");
        }
        git_guided_check_running = false;
    }

    private async void generate_guided_ssh_key() {
        var email = git_guided_email_entry != null ? git_guided_email_entry.get_text().strip() : "";
        if (email.length == 0) {
            toast_requested("Email address is required.");
            return;
        }

        var home = Environment.get_home_dir();
        if (home == null || home.strip().length == 0) {
            error_reported("SSH key generation failed", "Home directory not available.");
            return;
        }
        var ssh_dir = Path.build_filename(home, ".ssh");
        var mkdir_result = DirUtils.create_with_parents(ssh_dir, 0700);
        if (mkdir_result != 0) {
            error_reported("SSH key generation failed",
                           "Could not create %s (errno=%d).".printf(ssh_dir, mkdir_result));
            return;
        }

        var key_path = Path.build_filename(ssh_dir, "id_ed25519");
        if (FileUtils.test(key_path, FileTest.EXISTS)) {
            toast_requested("Using existing id_ed25519 key.");
            check_guided_ssh_state.begin();
            return;
        }

        git_guided_generate_key_btn.set_sensitive(false);
        var output = yield run_capture_command_async({
            "ssh-keygen",
            "-t", "ed25519",
            "-C", email,
            "-f", key_path,
            "-N", ""
        });
        git_guided_generate_key_btn.set_sensitive(true);

        if (!FileUtils.test("%s.pub".printf(key_path), FileTest.EXISTS)) {
            error_reported("SSH key generation failed",
                           output.strip().length > 0 ? output.strip() : "ssh-keygen did not create a public key.");
            return;
        }

        toast_requested("SSH key generated.");
        check_guided_ssh_state.begin();
    }

    private async string run_capture_command_async(string[] argv) {
        try {
            var proc = new Subprocess.newv(argv,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string? stdout_buf = null;
            string? stderr_buf = null;
            yield proc.communicate_utf8_async(null, null, out stdout_buf, out stderr_buf);
            var code = proc.get_exit_status();
            var out_text = (stdout_buf ?? "").strip();
            var err_text = (stderr_buf ?? "").strip();
            var combined = "";
            if (out_text.length > 0 && err_text.length > 0) {
                combined = "%s\n%s".printf(out_text, err_text);
            } else {
                combined = out_text.length > 0 ? out_text : err_text;
            }
            return "__EXIT_CODE__:%d\n%s".printf(code, combined);
        } catch (Error e) {
            return e.message;
        }
    }

    private string strip_exit_code_prefix(string output) {
        if (output.has_prefix("__EXIT_CODE__:")) {
            var newline = output.index_of_char('\n');
            if (newline >= 0 && newline + 1 < output.length) {
                return output.substring(newline + 1);
            }
            return "";
        }
        return output;
    }

    private int command_exit_code(string output) {
        if (!output.has_prefix("__EXIT_CODE__:")) {
            return -1;
        }
        var newline = output.index_of_char('\n');
        var code_text = newline >= 0
            ? output.substring("__EXIT_CODE__:".length, newline - "__EXIT_CODE__:".length)
            : output.substring("__EXIT_CODE__:".length);
        return int.parse(code_text.strip());
    }

    private void copy_guided_public_key() {
        if (git_guided_public_key.strip().length == 0) {
            toast_requested("No public key to copy.");
            return;
        }
        var display = Gdk.Display.get_default();
        if (display == null) {
            error_reported("Clipboard unavailable", "No display available.");
            return;
        }
        display.get_clipboard().set_text(git_guided_public_key);
        toast_requested("Public key copied.");
    }

    private void open_guided_github_ssh_keys_page() {
        try {
            AppInfo.launch_default_for_uri("https://github.com/settings/ssh/new", null);
        } catch (Error e) {
            error_reported("Failed to open browser", e.message);
        }
    }

    private void persist_guided_github_username() {
        if (settings == null || git_guided_username_entry == null) {
            return;
        }
        var username = git_guided_username_entry.get_text().strip();
        settings.set_string(AppSettings.KEY_GIT_GITHUB_USERNAME, username);
    }

    private void refresh_guided_next_button_state() {
        if (git_guided_next_btn == null || git_guided_username_entry == null) {
            return;
        }
        git_guided_next_btn.set_sensitive(git_guided_username_entry.get_text().strip().length > 0);
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
