namespace HolderLinux {

public class ConnectionsToolView : Object, IToolShellAdapter {
    private const int BOARD_NODE_WIDTH = 220;
    private const int BOARD_NODE_HEIGHT = 76;
    private const int BOARD_PADDING = 48;
    private const int BOARD_MIN_WIDTH = 900;
    private const int BOARD_MIN_HEIGHT = 240;
    private const int BOARD_BOTTOM_PADDING = 16;
    private const int PROJECT_MODE_MAX_NODES = 12;
    private const uint PROJECT_EMPTY_STATE_DELAY_MS = 250;
    private const uint GRAPH_REFRESH_DEBOUNCE_MS = 100;
    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    private Gtk.Box connections_actions_bar;
    private Gtk.Paned connections_main_pane;
    private Gtk.Overlay connections_board_overlay;
    private Gtk.DrawingArea connections_board_canvas;
    private Gtk.Fixed connections_board_nodes_layer;
    private Gtk.Label connections_board_empty_label;
    private Gtk.ToggleButton connections_relations_toggle_btn;
    private Gtk.ScrolledWindow connections_relations_scroller;
    private Gtk.Box connections_relations_column;
    private Gtk.Label connections_relations_title_label;
    private Gtk.Label connections_relations_structure_label;
    private Gtk.Box connections_relations_outgoing_section;
    private Gtk.Label connections_relations_outgoing_label;
    private Gtk.Box connections_relations_backlinks_section;
    private Gtk.Label connections_relations_backlinks_label;
    private Gtk.Box connections_relations_internal_section;
    private Gtk.Label connections_relations_internal_label;
    private Gtk.Button connections_add_graph_link_btn;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    private uint connections_graph_refresh_serial = 0;
    private uint connections_graph_generation = 0;
    private uint connections_graph_content_generation = 0;
    private ConnectionsController controller;
    private Gee.ArrayList<string> internal_links_cache = new Gee.ArrayList<string>();
    private Gee.ArrayList<ConnectionsBoardNode> board_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    private Gee.ArrayList<ConnectionsBoardEdge> board_edges = new Gee.ArrayList<ConnectionsBoardEdge>();
    private bool relations_default_split_applied = false;
    private uint relations_default_split_idle_id = 0;
    private bool show_projects_root = false;
    private bool has_committed_board = false;
    private uint pending_project_empty_state_id = 0;
    private bool is_tool_visible = false;
    private bool pending_refresh_when_visible = false;
    private uint pending_graph_refresh_id = 0;
    private bool graph_refresh_in_flight = false;
    private bool pending_graph_refresh_after_flight = false;
    private ConnectionsGraphRefreshTarget? pending_graph_refresh_target = null;
    private ConnectionsGraphRefreshTarget? in_flight_graph_refresh_target = null;
    private ConnectionsGraphRefreshTarget? committed_graph_refresh_target = null;
    private uint committed_graph_refresh_generation = 0;

    private bool project_has_known_cards(Project project) {
        return project.root_card_count > 0;
    }

    private void note_graph_refresh_content_changed() {
        connections_graph_content_generation++;
    }

    private void debug_graph_refresh(string event_name, ConnectionsGraphRefreshTarget target) {
        debug_log_requested(controller.format_graph_refresh_debug_event(event_name, target));
    }

    private ConnectionsGraphRefreshTarget current_graph_refresh_target() {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        return controller.build_graph_refresh_target(
            show_projects_root,
            selected_project,
            selected_card,
            connections_graph_content_generation
        );
    }

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "connections"; }
    }
    public string tool_label {
        owned get { return "Connections"; }
    }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void debug_log_requested(string line);
    public signal void project_overview_requested(string project_id);
    public signal void projects_root_requested();
    public signal void card_open_requested(string card_id);
    public signal void card_create_child_requested(string card_id);

    public ConnectionsToolView() {
        controller = new ConnectionsController();
        ensure_connections_css();
        widget = build_connections_tab();
    }

    public Gtk.Widget? get_actions_widget() {
        return connections_actions_bar;
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public void set_api_client(IHolderApi? api) {
        if (this.api != api) {
            note_graph_refresh_content_changed();
        }
        this.api = api;
        queue_connections_graph_refresh();
    }

    public void set_tool_visible(bool visible) {
        if (is_tool_visible == visible) {
            return;
        }
        is_tool_visible = visible;
        if (is_tool_visible && pending_refresh_when_visible) {
            pending_refresh_when_visible = false;
            queue_connections_graph_refresh();
        }
    }

    public void set_settings(Settings? settings) {
        this.settings = settings;
    }

    public void bind_context(Gtk.SingleSelection project_selection,
                             GLib.ListStore card_store,
                             Gtk.SingleSelection card_selection) {
        this.project_selection = project_selection;
        this.card_store = card_store;
        this.card_selection = card_selection;
        note_graph_refresh_content_changed();

        project_selection.notify["selected"].connect(() => {
            show_projects_root = false;
            refresh_connections_structure();
            queue_connections_graph_refresh();
        });
        card_selection.notify["selected"].connect(() => {
            show_projects_root = false;
            refresh_connections_structure();
            queue_connections_graph_refresh();
        });
        card_store.items_changed.connect((position, removed, added) => {
            refresh_connections_structure();
            note_graph_refresh_content_changed();
            queue_connections_graph_refresh();
        });

        refresh_connections_structure();
        queue_connections_graph_refresh();
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = ToolScopeMode.CARD_FOCUS;
        if (show_projects_root) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
            project_id = null;
            project_label = "Projects";
            card_id = null;
            card_label = "Overview";
        } else if (selected_card == null) {
            scope_mode = ToolScopeMode.PROJECT_ROOT;
            card_id = null;
            card_label = "Overview";
        }

        return new ToolScopeSnapshot(
            tool_id,
            tool_label,
            project_id,
            project_label,
            card_id,
            card_label,
            scope_mode,
            false
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        show_projects_root = true;
        refresh_connections_structure();
        queue_connections_graph_refresh();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        focus_project_overview(project_id);
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        card_open_requested(card_id);
        return true;
    }

    private Gtk.Widget build_connections_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        connections_actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        connections_actions_bar.set_hexpand(true);
        connections_actions_bar.set_halign(Gtk.Align.END);

        var content_shell = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        content_shell.add_css_class("flowboard-tile");
        content_shell.set_margin_top(2);
        content_shell.set_margin_bottom(6);
        content_shell.set_margin_start(6);
        content_shell.set_margin_end(6);
        content_shell.set_vexpand(true);
        content_shell.set_hexpand(true);
        root.append(content_shell);

        connections_main_pane = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        connections_main_pane.set_hexpand(true);
        connections_main_pane.set_vexpand(true);
        connections_main_pane.set_resize_start_child(true);
        connections_main_pane.set_shrink_start_child(true);
        connections_main_pane.set_resize_end_child(false);
        connections_main_pane.set_shrink_end_child(false);
        content_shell.append(connections_main_pane);

        var graph_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        graph_column.set_margin_top(6);
        graph_column.set_margin_bottom(6);
        graph_column.set_margin_start(6);
        graph_column.set_margin_end(6);

        var graph_scroller = new Gtk.ScrolledWindow();
        graph_scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        graph_scroller.set_hexpand(true);
        graph_scroller.set_vexpand(true);
        graph_scroller.set_child(graph_column);
        connections_main_pane.set_start_child(graph_scroller);

        connections_add_graph_link_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        connections_add_graph_link_btn.set_tooltip_text("Add graph connection");
        connections_add_graph_link_btn.update_property(Gtk.AccessibleProperty.LABEL, "Add graph connection", -1);
        connections_add_graph_link_btn.set_sensitive(false);
        connections_add_graph_link_btn.clicked.connect(() => {
            open_add_graph_link_dialog();
        });
        connections_relations_toggle_btn = new Gtk.ToggleButton();
        connections_relations_toggle_btn.add_css_class("flat");
        connections_relations_toggle_btn.set_icon_name("sidebar-show-right-symbolic");
        connections_relations_toggle_btn.set_tooltip_text("Toggle relations panel");
        connections_relations_toggle_btn.update_property(Gtk.AccessibleProperty.LABEL, "Toggle relations panel", -1);
        connections_relations_toggle_btn.set_active(true);
        connections_relations_toggle_btn.toggled.connect(() => {
            bool visible = connections_relations_toggle_btn.get_active();
            connections_relations_scroller.set_visible(visible);
        });
        connections_actions_bar.append(connections_add_graph_link_btn);
        connections_actions_bar.append(connections_relations_toggle_btn);
        connections_board_overlay = new Gtk.Overlay();
        connections_board_overlay.add_css_class("connections-board-surface");
        connections_board_overlay.set_hexpand(true);
        connections_board_overlay.set_vexpand(true);
        connections_board_overlay.set_size_request(BOARD_MIN_WIDTH, BOARD_MIN_HEIGHT);

        connections_board_canvas = new Gtk.DrawingArea();
        connections_board_canvas.set_hexpand(true);
        connections_board_canvas.set_vexpand(true);
        connections_board_canvas.set_content_width(BOARD_MIN_WIDTH);
        connections_board_canvas.set_content_height(BOARD_MIN_HEIGHT);
        connections_board_canvas.set_draw_func((area, cr, width, height) => {
            draw_connections_board(cr);
        });
        connections_board_overlay.set_child(connections_board_canvas);

        connections_board_nodes_layer = new Gtk.Fixed();
        connections_board_nodes_layer.set_size_request(BOARD_MIN_WIDTH, BOARD_MIN_HEIGHT);
        connections_board_nodes_layer.set_hexpand(true);
        connections_board_nodes_layer.set_vexpand(true);
        connections_board_overlay.add_overlay(connections_board_nodes_layer);

        connections_board_empty_label = new Gtk.Label("Select a card to view graph links.") { xalign = 0.0f };
        connections_board_empty_label.add_css_class("dim-label");
        connections_board_empty_label.set_wrap(true);
        connections_board_empty_label.set_halign(Gtk.Align.CENTER);
        connections_board_empty_label.set_valign(Gtk.Align.CENTER);
        connections_board_overlay.add_overlay(connections_board_empty_label);
        graph_column.append(connections_board_overlay);

        connections_relations_column = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        connections_relations_column.set_margin_top(8);
        connections_relations_column.set_margin_bottom(8);
        connections_relations_column.set_margin_start(8);
        connections_relations_column.set_margin_end(8);

        connections_relations_title_label = new Gtk.Label("Relations") { xalign = 0.0f };
        connections_relations_title_label.add_css_class("title-5");
        connections_relations_column.append(connections_relations_title_label);

        connections_relations_structure_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_structure_label.set_wrap(true);
        connections_relations_structure_label.set_use_markup(true);
        connections_relations_structure_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_structure_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_column.append(connections_relations_structure_label);

        connections_relations_outgoing_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        var outgoing_title = new Gtk.Label("Outgoing") { xalign = 0.0f };
        outgoing_title.add_css_class("heading");
        connections_relations_outgoing_section.append(outgoing_title);
        connections_relations_outgoing_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_outgoing_label.set_wrap(true);
        connections_relations_outgoing_label.set_use_markup(true);
        connections_relations_outgoing_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_outgoing_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_outgoing_section.append(connections_relations_outgoing_label);
        connections_relations_column.append(connections_relations_outgoing_section);

        connections_relations_backlinks_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        var incoming_title = new Gtk.Label("Incoming") { xalign = 0.0f };
        incoming_title.add_css_class("heading");
        connections_relations_backlinks_section.append(incoming_title);
        connections_relations_backlinks_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_backlinks_label.set_wrap(true);
        connections_relations_backlinks_label.set_use_markup(true);
        connections_relations_backlinks_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_backlinks_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_backlinks_section.append(connections_relations_backlinks_label);
        connections_relations_column.append(connections_relations_backlinks_section);

        connections_relations_internal_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        var internal_title = new Gtk.Label("Internal") { xalign = 0.0f };
        internal_title.add_css_class("heading");
        connections_relations_internal_section.append(internal_title);
        connections_relations_internal_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_internal_label.set_wrap(true);
        connections_relations_internal_label.set_use_markup(true);
        connections_relations_internal_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_internal_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_internal_section.append(connections_relations_internal_label);
        connections_relations_column.append(connections_relations_internal_section);

        connections_relations_scroller = new Gtk.ScrolledWindow();
        connections_relations_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        connections_relations_scroller.set_min_content_width(320);
        connections_relations_scroller.set_size_request(320, -1);
        connections_relations_scroller.set_hexpand(false);
        connections_relations_scroller.set_vexpand(true);
        connections_relations_scroller.update_property(Gtk.AccessibleProperty.LABEL, "Relations panel", -1);
        connections_relations_scroller.set_child(connections_relations_column);
        connections_main_pane.set_end_child(connections_relations_scroller);
        queue_apply_default_relations_split();

        refresh_connections_structure();
        set_graph_empty_state("Select a card to view graph links.");
        return root;
    }

    private bool apply_default_relations_split() {
        if (relations_default_split_applied || connections_main_pane == null) {
            return Source.REMOVE;
        }
        int total_width = connections_main_pane.get_width();
        if (total_width <= 0) {
            return Source.CONTINUE;
        }
        int desired_relations = 320;
        int min_graph = 520;
        int pane_position = total_width - desired_relations;
        if (pane_position < min_graph) {
            pane_position = min_graph;
        }
        if (pane_position > total_width - 260) {
            pane_position = total_width - 260;
        }
        connections_main_pane.set_position(pane_position);
        relations_default_split_applied = true;
        relations_default_split_idle_id = 0;
        return Source.REMOVE;
    }

    private void queue_apply_default_relations_split() {
        if (relations_default_split_applied || relations_default_split_idle_id != 0) {
            return;
        }
        relations_default_split_idle_id = Timeout.add(30, () => {
            return apply_default_relations_split();
        });
    }

    public void set_internal_links(Gee.ArrayList<string> link_targets) {
        if (controller.internal_links_equal(internal_links_cache, link_targets)) {
            return;
        }
        internal_links_cache.clear();
        note_graph_refresh_content_changed();
        if (link_targets == null || link_targets.size == 0) {
            queue_connections_graph_refresh();
            return;
        }
        foreach (var target in link_targets) {
            internal_links_cache.add(target);
        }
        queue_connections_graph_refresh();
    }
    private void set_graph_empty_state(string message) {
        clear_fixed_children(connections_board_nodes_layer);
        board_nodes.clear();
        board_edges.clear();
        has_committed_board = false;
        connections_board_empty_label.set_text(message);
        connections_board_empty_label.set_visible(true);
        set_relations_overview(message);
        ensure_board_canvas_size(BOARD_MIN_WIDTH, BOARD_MIN_HEIGHT);
        connections_board_canvas.queue_draw();
        update_add_graph_link_button_state();
    }

    private string link_markup(string kind, string id, string title) {
        var href = "%s:%s".printf(kind, Uri.escape_string(id, null, false));
        return "<a href=\"%s\">%s</a>".printf(
            Markup.escape_text(href),
            Markup.escape_text(controller.ellipsize_title(title))
        );
    }

    private void set_relations_overview(string text) {
        if (connections_relations_structure_label == null) {
            return;
        }
        var escaped = Markup.escape_text(text);
        connections_relations_structure_label.set_markup(escaped);
        connections_relations_structure_label.update_property(Gtk.AccessibleProperty.LABEL, text, -1);
        connections_relations_outgoing_label.set_markup("None");
        connections_relations_outgoing_label.update_property(Gtk.AccessibleProperty.LABEL, "None", -1);
        connections_relations_backlinks_label.set_markup("None");
        connections_relations_backlinks_label.update_property(Gtk.AccessibleProperty.LABEL, "None", -1);
        connections_relations_internal_label.set_markup("None");
        connections_relations_internal_label.update_property(Gtk.AccessibleProperty.LABEL, "None", -1);
        connections_relations_outgoing_section.set_visible(false);
        connections_relations_backlinks_section.set_visible(false);
        connections_relations_internal_section.set_visible(false);
    }

    private void set_relations_for_card(Project project,
                                        CardSummary selected_card,
                                        Gee.ArrayList<CardLink> outgoing,
                                        Gee.ArrayList<CardLink> backlinks) {
        connections_relations_outgoing_section.set_visible(true);
        connections_relations_backlinks_section.set_visible(true);
        connections_relations_internal_section.set_visible(true);
        var structure_markup = controller.compact_structure_markup(project, selected_card, snapshot_cards());
        connections_relations_structure_label.set_markup(structure_markup);
        connections_relations_structure_label.update_property(
            Gtk.AccessibleProperty.LABEL,
            plain_text_from_markup(structure_markup),
            -1
        );
        var outgoing_markup = format_link_lines(outgoing, true);
        connections_relations_outgoing_label.set_markup(outgoing_markup);
        connections_relations_outgoing_label.update_property(
            Gtk.AccessibleProperty.LABEL,
            plain_text_from_markup(outgoing_markup),
            -1
        );
        var backlinks_markup = format_link_lines(backlinks, false);
        connections_relations_backlinks_label.set_markup(backlinks_markup);
        connections_relations_backlinks_label.update_property(
            Gtk.AccessibleProperty.LABEL,
            plain_text_from_markup(backlinks_markup),
            -1
        );
        var internal_markup = format_internal_lines(project.project_id);
        connections_relations_internal_label.set_markup(internal_markup);
        connections_relations_internal_label.update_property(
            Gtk.AccessibleProperty.LABEL,
            plain_text_from_markup(internal_markup),
            -1
        );
    }

    private string plain_text_from_markup(string markup) {
        var text = new StringBuilder();
        bool in_tag = false;
        for (int i = 0; i < markup.length; i++) {
            char c = markup[i];
            if (c == '<') {
                in_tag = true;
                continue;
            }
            if (c == '>') {
                in_tag = false;
                continue;
            }
            if (!in_tag) {
                text.append_c(c);
            }
        }
        return text.str
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&amp;", "&")
            .replace("&quot;", "\"")
            .replace("&apos;", "'");
    }

    private string format_link_lines(Gee.ArrayList<CardLink> links, bool outgoing) {
        if (links.size == 0) {
            return "None";
        }
        var cards = snapshot_cards();
        var groups = controller.group_links_by_kind(links);
        var lines = new Gee.ArrayList<string>();
        foreach (var group in groups) {
            var targets = new Gee.ArrayList<string>();
            foreach (var link in group.links) {
                var target_id = outgoing ? link.to_card_id : link.from_card_id;
                if ((outgoing ? link.to_type : "card") == "card") {
                    targets.add(link_markup("card", target_id, controller.title_for_card_id(target_id, cards)));
                } else {
                    targets.add(Markup.escape_text(target_id));
                }
            }
            lines.add("%s: %s".printf(Markup.escape_text(group.kind), string.joinv(", ", targets.to_array())));
        }
        return string.joinv("\n", lines.to_array());
    }

    private string format_internal_lines(string project_id) {
        if (internal_links_cache.size == 0) {
            return "None";
        }
        var cards = snapshot_cards();
        var links = new Gee.ArrayList<string>();
        foreach (var target in internal_links_cache) {
            var card_id = controller.resolve_internal_link_target_card_id(target, project_id, cards);
            if (card_id != null) {
                links.add(link_markup("card", card_id, controller.title_for_card_id(card_id, cards)));
            } else {
                links.add(Markup.escape_text(target));
            }
        }
        return string.joinv("\n", links.to_array());
    }

    private void update_add_graph_link_button_state() {
        if (connections_add_graph_link_btn == null) {
            return;
        }
        if (show_projects_root) {
            connections_add_graph_link_btn.set_sensitive(false);
            return;
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        var has_target = controller.has_graph_link_targets(selected_card, snapshot_cards());
        connections_add_graph_link_btn.set_sensitive(api != null && selected_card != null && has_target);
    }

    private void open_add_graph_link_dialog() {
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (selected_card == null || card_store == null || api == null) {
            return;
        }

        var options = controller.build_graph_link_target_options(selected_card, snapshot_cards());
        var target_ids = new Gee.ArrayList<string>();
        var target_titles = new Gtk.StringList(null);
        foreach (var option in options) {
            target_ids.add(option.card_id);
            target_titles.append(option.display_text);
        }
        if (target_ids.size == 0) {
            toast_requested("No other cards in this project to link.");
            return;
        }

        var root = widget.get_root() as Gtk.Window;
        if (root == null) {
            return;
        }

        var dialog = new Adw.MessageDialog(root, "Add Graph Connection", "Create an explicit card-to-card connection.");
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("add", "Add");
        dialog.set_response_appearance("add", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("add");
        dialog.set_close_response("cancel");

        var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);

        var target_label = new Gtk.Label("Target card") { xalign = 0.0f };
        var target_dropdown = new Gtk.DropDown(target_titles, null);
        target_dropdown.update_property(Gtk.AccessibleProperty.LABEL, "Target card", -1);
        target_dropdown.set_selected(0);
        content.append(target_label);
        content.append(target_dropdown);

        var kind_label = new Gtk.Label("Kind") { xalign = 0.0f };
        var kind_options = new Gtk.StringList(null);
        var available_kinds = controller.list_available_link_kinds(settings);
        foreach (var kind_option in available_kinds) {
            kind_options.append(kind_option);
        }
        kind_options.append("custom");
        var kind_dropdown = new Gtk.DropDown(kind_options, null);
        kind_dropdown.update_property(Gtk.AccessibleProperty.LABEL, "Kind", -1);
        kind_dropdown.set_selected(0);
        var custom_kind_entry = new Gtk.Entry();
        custom_kind_entry.set_placeholder_text("custom kind");
        custom_kind_entry.update_property(Gtk.AccessibleProperty.LABEL, "Custom kind", -1);
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
        label_entry.update_property(Gtk.AccessibleProperty.LABEL, "Connection label", -1);
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
                controller.remember_custom_link_kind(settings, kind);
            }
            toast_requested("Graph link added.");
            note_graph_refresh_content_changed();
            queue_connections_graph_refresh();
        } catch (Error e) {
            error_reported("Failed to add graph link", e.message);
        }
    }

    private void queue_connections_graph_refresh() {
        var target = current_graph_refresh_target();
        var target_key = target.to_key();
        if (!graph_refresh_in_flight
            && pending_graph_refresh_id == 0
            && !pending_refresh_when_visible
            && committed_graph_refresh_target != null
            && committed_graph_refresh_target.to_key() == target_key
            && committed_graph_refresh_generation == connections_graph_generation) {
            debug_graph_refresh("skipped unchanged target", target);
            return;
        }
        if (!is_tool_visible) {
            if (pending_refresh_when_visible
                && pending_graph_refresh_target != null
                && pending_graph_refresh_target.to_key() == target_key) {
                debug_graph_refresh("suppressed hidden duplicate", target);
                return;
            }
            connections_graph_generation++;
            pending_refresh_when_visible = true;
            pending_graph_refresh_target = target;
            debug_graph_refresh("suppressed while hidden", target);
            return;
        }
        pending_refresh_when_visible = false;
        if (pending_graph_refresh_id != 0
            && pending_graph_refresh_target != null
            && pending_graph_refresh_target.to_key() == target_key) {
            debug_graph_refresh("coalesced pending duplicate", target);
            return;
        }
        if (graph_refresh_in_flight) {
            if (in_flight_graph_refresh_target != null
                && in_flight_graph_refresh_target.to_key() == target_key) {
                debug_graph_refresh("suppressed same target in flight", target);
                return;
            }
            if (pending_graph_refresh_after_flight
                && pending_graph_refresh_target != null
                && pending_graph_refresh_target.to_key() == target_key) {
                debug_graph_refresh("coalesced duplicate after flight", target);
                return;
            }
            connections_graph_generation++;
            pending_graph_refresh_after_flight = true;
            pending_graph_refresh_target = target;
            debug_graph_refresh("coalesced after in-flight refresh", target);
            return;
        }
        if (pending_graph_refresh_id != 0) {
            Source.remove(pending_graph_refresh_id);
            pending_graph_refresh_id = 0;
        }
        connections_graph_generation++;
        pending_graph_refresh_target = target;
        pending_graph_refresh_id = Timeout.add(GRAPH_REFRESH_DEBOUNCE_MS, () => {
            var dispatch_target = pending_graph_refresh_target;
            pending_graph_refresh_id = 0;
            pending_graph_refresh_target = null;
            if (graph_refresh_in_flight) {
                pending_graph_refresh_after_flight = true;
                if (dispatch_target != null) {
                    debug_graph_refresh("coalesced at debounce dispatch", dispatch_target);
                }
                return Source.REMOVE;
            }
            clear_pending_project_empty_state();
            connections_graph_refresh_serial++;
            in_flight_graph_refresh_target = dispatch_target;
            refresh_connections_graph.begin(
                connections_graph_refresh_serial,
                connections_graph_generation,
                dispatch_target ?? target
            );
            return Source.REMOVE;
        });
    }

    private async void refresh_connections_graph(uint request_serial,
                                                uint request_generation,
                                                ConnectionsGraphRefreshTarget request_target) {
        graph_refresh_in_flight = true;
        try {
            if (request_serial != connections_graph_refresh_serial
                || request_generation != connections_graph_generation) {
                debug_graph_refresh("dropped stale preflight", request_target);
                return;
            }
            if (connections_board_overlay == null || connections_board_nodes_layer == null || connections_board_canvas == null) {
                return;
            }
            if (show_projects_root) {
                if (request_serial != connections_graph_refresh_serial
                    || request_generation != connections_graph_generation) {
                    debug_graph_refresh("dropped stale projects root", request_target);
                    return;
                }
                committed_graph_refresh_target = request_target;
                committed_graph_refresh_generation = request_generation;
                render_projects_root_board();
                update_add_graph_link_button_state();
                return;
            }
            var selected_project = project_selection != null
                ? project_selection.get_selected_item() as Project
                : null;
            var selected_card = card_selection != null
                ? card_selection.get_selected_item() as CardSummary
                : null;
            if (selected_project == null) {
                if (request_serial != connections_graph_refresh_serial
                    || request_generation != connections_graph_generation) {
                    debug_graph_refresh("dropped stale missing project", request_target);
                    return;
                }
                // During project/card transitions, selection can briefly pass through null.
                // Keep the committed board to avoid flashing a transient empty state.
                if (!has_committed_board) {
                    set_graph_empty_state("Select a project to view connections.");
                }
                return;
            }
            if (selected_card != null && selected_card.project_id != selected_project.project_id) {
                selected_card = null;
            }

            if (selected_card != null) {
                var expected_card_id = selected_card.card_id;
                var result = yield controller.load_graph_links(api, selected_card);

                if (request_serial != connections_graph_refresh_serial
                    || request_generation != connections_graph_generation) {
                    debug_graph_refresh("dropped stale card result", request_target);
                    return;
                }
                var still_selected = card_selection != null
                    ? card_selection.get_selected_item() as CardSummary
                    : null;
                if (still_selected == null || still_selected.card_id != expected_card_id) {
                    debug_graph_refresh("dropped stale card selection", request_target);
                    return;
                }
                if (!result.success || result.outgoing == null || result.backlinks == null) {
                    if (!has_committed_board) {
                        set_graph_empty_state(result.outgoing_empty_text);
                    }
                    if (result.debug_message.strip().length > 0) {
                        debug_log_requested(result.debug_message);
                    }
                    return;
                }
                committed_graph_refresh_target = request_target;
                committed_graph_refresh_generation = request_generation;
                render_card_mode_board(selected_project, selected_card, result.outgoing, result.backlinks);
                update_add_graph_link_button_state();
                return;
            }

            if (api == null) {
                if (request_serial != connections_graph_refresh_serial
                    || request_generation != connections_graph_generation) {
                    debug_graph_refresh("dropped stale api unavailable", request_target);
                    return;
                }
                set_graph_empty_state("API unavailable.");
                return;
            }
            var cards = snapshot_cards();
            var project_links = new Gee.ArrayList<CardLink>();
            var project_card_ids = new Gee.HashSet<string>();
            foreach (var card in cards) {
                if (card.project_id == selected_project.project_id) {
                    project_card_ids.add(card.card_id);
                }
            }
            foreach (var card in cards) {
                if (card.project_id != selected_project.project_id) {
                    continue;
                }
                if (request_serial != connections_graph_refresh_serial
                    || request_generation != connections_graph_generation) {
                    debug_graph_refresh("dropped stale project result", request_target);
                    return;
                }
                try {
                    var links = yield api.list_card_links(card.card_id);
                    foreach (var link in links) {
                        if (link.to_type == "card" && project_card_ids.contains(link.to_card_id)) {
                            project_links.add(link);
                        }
                    }
                } catch (Error e) {
                    if (!has_committed_board) {
                        set_graph_empty_state("Failed to load project graph links.");
                    }
                    debug_log_requested("Project graph links refresh failed: %s".printf(e.message));
                    return;
                }
            }
            if (request_serial != connections_graph_refresh_serial
                || request_generation != connections_graph_generation) {
                debug_graph_refresh("dropped stale project completion", request_target);
                return;
            }
            committed_graph_refresh_target = request_target;
            committed_graph_refresh_generation = request_generation;
            render_project_mode_board(selected_project, cards, project_links);
            update_add_graph_link_button_state();
        } finally {
            graph_refresh_in_flight = false;
            in_flight_graph_refresh_target = null;
            if (pending_graph_refresh_after_flight) {
                pending_graph_refresh_after_flight = false;
                queue_connections_graph_refresh();
            }
        }
    }

    private void render_card_mode_board(Project project,
                                        CardSummary selected_card,
                                        Gee.ArrayList<CardLink> outgoing,
                                        Gee.ArrayList<CardLink> backlinks) {
        var cards = snapshot_cards();
        var project_cards = new Gee.ArrayList<CardSummary>();
        foreach (var card in cards) {
            if (card.project_id == project.project_id) {
                project_cards.add(card);
            }
        }

        var nodes_by_id = new Gee.HashMap<string, ConnectionsBoardNode>();
        nodes_by_id.set(selected_card.card_id, new ConnectionsBoardNode(
            selected_card.card_id,
            controller.ellipsize_title(selected_card.title),
            selected_card.updated_at,
            controller.child_count_for(selected_card.card_id, cards)
        ));
        var edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        var edge_keys = new Gee.HashSet<string>();

        foreach (var link in outgoing) {
            if (link.to_type != "card") {
                continue;
            }
            controller.add_board_edge(nodes_by_id, edge_keys, edges, link.from_card_id, link.to_card_id, controller.normalized_link_kind(link.kind), false, cards);
        }
        foreach (var link in backlinks) {
            if (link.to_type != "card") {
                continue;
            }
            controller.add_board_edge(nodes_by_id, edge_keys, edges, link.from_card_id, link.to_card_id, controller.normalized_link_kind(link.kind), false, cards);
        }

        var structural = controller.build_structural_edges_for_selected(selected_card, project_cards);
        foreach (var edge in structural) {
            controller.add_board_edge(nodes_by_id, edge_keys, edges, edge.from_card_id, edge.to_card_id, edge.kind, true, cards);
        }
        foreach (var target in internal_links_cache) {
            var target_card_id = controller.resolve_internal_link_target_card_id(target, project.project_id, cards);
            if (target_card_id != null && target_card_id != selected_card.card_id) {
                controller.add_board_edge(nodes_by_id, edge_keys, edges, selected_card.card_id, target_card_id, "internal", true, cards);
            }
        }

        var node_list = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var node in nodes_by_id.values) {
            node_list.add(node);
        }
        node_list.sort((a, b) => strcmp(a.title.down(), b.title.down()));
        controller.layout_card_mode_nodes(
            selected_card.card_id,
            node_list,
            BOARD_MIN_WIDTH,
            BOARD_NODE_WIDTH,
            BOARD_NODE_HEIGHT,
            BOARD_PADDING,
            controller.target_board_height_for_count(node_list.size)
        );
        controller.spread_nodes_to_avoid_overlap(node_list, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        render_board(node_list, edges, "Card-focused graph.");
        set_relations_for_card(project, selected_card, outgoing, backlinks);
    }

    private void render_project_mode_board(Project project,
                                           Gee.ArrayList<CardSummary> cards,
                                           Gee.ArrayList<CardLink> project_links) {
        var project_cards = new Gee.ArrayList<CardSummary>();
        foreach (var card in cards) {
            if (card.project_id == project.project_id) {
                project_cards.add(card);
            }
        }
        if (project_cards.size == 0) {
            if (project_has_known_cards(project)) {
                // Project metadata says cards exist, so an empty local snapshot is
                // likely transitional while selection/data updates settle.
                schedule_project_empty_state_if_still_empty(project.project_id);
                return;
            }
            if (!has_committed_board) {
                set_graph_empty_state("No cards in this project yet.");
                return;
            }
            schedule_project_empty_state_if_still_empty(project.project_id);
            return;
        }
        clear_pending_project_empty_state();

        var all_edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        var edge_keys = new Gee.HashSet<string>();
        var counts = new Gee.HashMap<string, int>();
        foreach (var link in project_links) {
            var kind = controller.normalized_link_kind(link.kind);
            if (controller.add_edge_to_list(edge_keys, all_edges, link.from_card_id, link.to_card_id, kind, false)) {
                controller.increment_count(counts, kind);
            }
        }
        foreach (var edge in controller.build_structural_edges_for_project(project_cards)) {
            if (controller.add_edge_to_list(edge_keys, all_edges, edge.from_card_id, edge.to_card_id, edge.kind, true)) {
                controller.increment_count(counts, edge.kind);
            }
        }

        var degree = new Gee.HashMap<string, int>();
        foreach (var card in project_cards) {
            degree.set(card.card_id, 0);
        }
        foreach (var edge in all_edges) {
            degree.set(edge.from_card_id, degree.get(edge.from_card_id) + 1);
            degree.set(edge.to_card_id, degree.get(edge.to_card_id) + 1);
        }

        project_cards.sort((a, b) => {
            var da = degree.get(a.card_id);
            var db = degree.get(b.card_id);
            if (da != db) {
                return db - da;
            }
            return strcmp(a.title.down(), b.title.down());
        });
        var keep = new Gee.HashSet<string>();
        for (int i = 0; i < project_cards.size && i < PROJECT_MODE_MAX_NODES; i++) {
            keep.add(project_cards[i].card_id);
        }
        var nodes = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var card in project_cards) {
            if (!keep.contains(card.card_id)) {
                continue;
            }
            nodes.add(new ConnectionsBoardNode(
                card.card_id,
                controller.ellipsize_title(card.title),
                card.updated_at,
                controller.child_count_for(card.card_id, project_cards)
            ));
        }
        var edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        foreach (var edge in all_edges) {
            if (keep.contains(edge.from_card_id) && keep.contains(edge.to_card_id)) {
                edges.add(edge);
            }
        }
        controller.layout_project_mode_nodes(nodes, BOARD_PADDING, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        controller.spread_nodes_to_avoid_overlap(nodes, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        var summary = controller.format_counts_summary(counts);
        render_board(nodes, edges, summary);
        set_relations_overview(summary);
    }

    private void clear_pending_project_empty_state() {
        if (pending_project_empty_state_id != 0) {
            Source.remove(pending_project_empty_state_id);
            pending_project_empty_state_id = 0;
        }
    }

    private void schedule_project_empty_state_if_still_empty(string project_id) {
        clear_pending_project_empty_state();
        var expected_generation = connections_graph_generation;
        pending_project_empty_state_id = Timeout.add(PROJECT_EMPTY_STATE_DELAY_MS, () => {
            pending_project_empty_state_id = 0;
            if (expected_generation != connections_graph_generation) {
                return Source.REMOVE;
            }
            if (show_projects_root) {
                return Source.REMOVE;
            }
            var selected_project = project_selection != null
                ? project_selection.get_selected_item() as Project
                : null;
            if (selected_project == null || selected_project.project_id != project_id) {
                return Source.REMOVE;
            }
            if (project_has_known_cards(selected_project)) {
                return Source.REMOVE;
            }
            var selected_card = card_selection != null
                ? card_selection.get_selected_item() as CardSummary
                : null;
            if (selected_card != null) {
                return Source.REMOVE;
            }
            int project_card_count = 0;
            foreach (var card in snapshot_cards()) {
                if (card.project_id == project_id) {
                    project_card_count++;
                    break;
                }
            }
            if (project_card_count == 0) {
                set_graph_empty_state("No cards in this project yet.");
            }
            return Source.REMOVE;
        });
    }

    private void render_projects_root_board() {
        if (project_selection == null) {
            set_graph_empty_state("No projects available.");
            return;
        }
        var model = project_selection.get_model();
        if (model == null) {
            set_graph_empty_state("No projects available.");
            return;
        }

        var nodes = new Gee.ArrayList<ConnectionsBoardNode>();
        for (uint i = 0; i < model.get_n_items(); i++) {
            var project = model.get_item(i) as Project;
            if (project == null) {
                continue;
            }
            nodes.add(new ConnectionsBoardNode(
                "project:%s".printf(project.project_id),
                controller.ellipsize_title(project.name),
                project.updated_at,
                project.root_card_count
            ));
        }
        if (nodes.size == 0) {
            set_graph_empty_state("No projects available.");
            return;
        }

        controller.layout_project_mode_nodes(nodes, BOARD_PADDING, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        controller.spread_nodes_to_avoid_overlap(nodes, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        render_board(nodes, new Gee.ArrayList<ConnectionsBoardEdge>(), "Select a project.");
        set_relations_overview("Select a project.");
    }

    private void render_board(Gee.ArrayList<ConnectionsBoardNode> nodes,
                              Gee.ArrayList<ConnectionsBoardEdge> edges,
                              string summary_text) {
        clear_fixed_children(connections_board_nodes_layer);
        board_nodes.clear();
        board_edges.clear();
        board_nodes.add_all(nodes);
        board_edges.add_all(edges);

        int required_w = BOARD_MIN_WIDTH;
        int required_h = controller.target_board_height_for_count(nodes.size);
        int content_bottom = 0;
        foreach (var node in nodes) {
            required_w = int.max(required_w, node.x + BOARD_NODE_WIDTH + BOARD_PADDING);
            content_bottom = int.max(content_bottom, node.y + BOARD_NODE_HEIGHT);
            var node_widget = build_board_node_widget(node);
            connections_board_nodes_layer.put(node_widget, node.x, node.y);
        }
        if (nodes.size > 0) {
            // Trim only the trailing space under the last node; keep node spacing/layout untouched.
            required_h = int.max(BOARD_MIN_HEIGHT, content_bottom + BOARD_BOTTOM_PADDING);
        }
        ensure_board_canvas_size(required_w, required_h);
        connections_board_empty_label.set_visible(nodes.size == 0);
        if (nodes.size == 0) {
            connections_board_empty_label.set_text("No connections to display.");
        }
        has_committed_board = true;
        connections_board_canvas.queue_draw();
    }

    private Gtk.Widget build_board_node_widget(ConnectionsBoardNode node) {
        var button = new Gtk.Button();
        button.add_css_class("flat");
        button.add_css_class("card");
        button.add_css_class("flowboard-tile");
        button.add_css_class("connections-board-node");
        if (node.child_count > 0) {
            button.add_css_class("flowboard-branch");
        }
        button.set_size_request(BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        var inner = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        inner.set_margin_top(8);
        inner.set_margin_bottom(10);
        inner.set_margin_start(8);
        inner.set_margin_end(8);

        var title = new Gtk.Label(node.title) { xalign = 0.0f };
        title.set_wrap(true);
        title.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        title.set_lines(2);
        title.set_ellipsize(Pango.EllipsizeMode.END);
        title.set_max_width_chars(32);
        title.add_css_class("title-5");
        title.set_hexpand(true);
        inner.append(title);

        var spacer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        spacer.set_vexpand(true);
        inner.append(spacer);

        var now = new DateTime.now_utc().to_unix();
        string meta_text;
        if (node.child_count > 0) {
            meta_text = "%d %s | %s".printf(
                node.child_count,
                node.child_count == 1 ? "item" : "items",
                TextUtils.format_relative_time(now, node.updated_at)
            );
        } else {
            meta_text = TextUtils.format_relative_time(now, node.updated_at);
        }
        var meta = new Gtk.Label(meta_text) { xalign = 0.0f };
        meta.add_css_class("dim-label");
        meta.set_xalign(1.0f);
        meta.set_halign(Gtk.Align.END);
        inner.append(meta);

        button.set_child(inner);
        button.clicked.connect(() => {
            if (node.card_id.has_prefix("project:")) {
                var project_id = node.card_id.substring("project:".length);
                focus_project_overview(project_id);
                return;
            }
            card_open_requested(node.card_id);
        });
        var context_click = new Gtk.GestureClick();
        context_click.set_button(Gdk.BUTTON_SECONDARY);
        context_click.pressed.connect((n_press, x, y) => {
            if (n_press != 1 || node.card_id.has_prefix("project:")) {
                return;
            }
            show_board_node_menu_at(button, node, x, y);
        });
        button.add_controller(context_click);
        return button;
    }

    private void show_board_node_menu_at(Gtk.Widget node_widget,
                                         ConnectionsBoardNode node,
                                         double x,
                                         double y) {
        var popover = new Gtk.Popover();
        popover.set_autohide(true);
        popover.set_parent(node_widget);

        var menu_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var open_btn = new Gtk.Button.with_label("Open");
        open_btn.add_css_class("flat");
        open_btn.clicked.connect(() => {
            popover.popdown();
            card_open_requested(node.card_id);
        });
        menu_box.append(open_btn);

        var create_child_btn = new Gtk.Button.with_label("Create Child Card");
        create_child_btn.add_css_class("flat");
        create_child_btn.clicked.connect(() => {
            popover.popdown();
            card_create_child_requested(node.card_id);
        });
        menu_box.append(create_child_btn);

        popover.set_child(menu_box);

        var rect = Gdk.Rectangle();
        rect.x = (int) x;
        rect.y = (int) y;
        rect.width = 1;
        rect.height = 1;
        popover.set_pointing_to(rect);
        popover.popup();
    }

    private void draw_connections_board(Cairo.Context cr) {
        if (board_edges.size == 0 || board_nodes.size == 0) {
            return;
        }
        var node_map = new Gee.HashMap<string, ConnectionsBoardNode>();
        foreach (var node in board_nodes) {
            node_map.set(node.card_id, node);
        }
        cr.set_line_width(1.6);
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.88);
        foreach (var edge in board_edges) {
            var from = node_map.get(edge.from_card_id);
            var to = node_map.get(edge.to_card_id);
            if (from == null || to == null) {
                continue;
            }
            double x0;
            double y0;
            point_on_node_edge(from, to, out x0, out y0);
            double x1;
            double y1;
            point_on_node_edge(to, from, out x1, out y1);
            if (edge.dashed) {
                double[] dashes = { 5.0, 4.0 };
                cr.set_dash(dashes, 0.0);
            } else {
                cr.set_dash(null, 0.0);
            }
            cr.move_to(x0, y0);
            cr.line_to(x1, y1);
            cr.stroke();
            draw_arrow_head(cr, x0, y0, x1, y1);
        }
        cr.set_dash(null, 0.0);
    }

    private void point_on_node_edge(ConnectionsBoardNode source,
                                    ConnectionsBoardNode target,
                                    out double out_x,
                                    out double out_y) {
        double cx = source.x + BOARD_NODE_WIDTH / 2.0;
        double cy = source.y + BOARD_NODE_HEIGHT / 2.0;
        double tx = target.x + BOARD_NODE_WIDTH / 2.0;
        double ty = target.y + BOARD_NODE_HEIGHT / 2.0;
        double dx = tx - cx;
        double dy = ty - cy;
        if (absd(dx) < 0.001 && absd(dy) < 0.001) {
            out_x = cx;
            out_y = cy;
            return;
        }
        if (absd(dx) >= absd(dy)) {
            out_x = dx >= 0 ? (source.x + BOARD_NODE_WIDTH) : source.x;
            out_y = cy;
            return;
        }
        out_x = cx;
        out_y = dy >= 0 ? (source.y + BOARD_NODE_HEIGHT) : source.y;
    }

    private void draw_arrow_head(Cairo.Context cr,
                                 double x0,
                                 double y0,
                                 double x1,
                                 double y1) {
        double dx = x1 - x0;
        double dy = y1 - y0;
        if (absd(dx) < 0.001 && absd(dy) < 0.001) {
            return;
        }
        if (absd(dx) >= absd(dy)) {
            double dir = dx >= 0 ? 1.0 : -1.0;
            cr.move_to(x1, y1);
            cr.line_to(x1 - (8.0 * dir), y1 - 3.5);
            cr.line_to(x1 - (8.0 * dir), y1 + 3.5);
            cr.close_path();
            cr.fill();
            return;
        }
        double dir = dy >= 0 ? 1.0 : -1.0;
        cr.move_to(x1, y1);
        cr.line_to(x1 - 3.5, y1 - (8.0 * dir));
        cr.line_to(x1 + 3.5, y1 - (8.0 * dir));
        cr.close_path();
        cr.fill();
    }

    private void ensure_board_canvas_size(int width, int height) {
        connections_board_overlay.set_size_request(width, height);
        connections_board_canvas.set_content_width(width);
        connections_board_canvas.set_content_height(height);
        connections_board_nodes_layer.set_size_request(width, height);
    }

    private double absd(double value) {
        return value < 0 ? -value : value;
    }

    private static void ensure_connections_css() {
        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
.connections-board-surface {
  border-radius: 0;
  border: none;
  background-color: @view_bg_color;
}

.connections-board-node {
  min-height: 76px;
}
""");
        gtk_style_context_add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private bool on_connections_link_activated(string uri) {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_project_id = selected_project != null ? selected_project.project_id : null;
        var action = controller.resolve_link_action(uri, selected_project_id, snapshot_cards());
        if (!action.handled) {
            return false;
        }
        if (action.select_card) {
            var card_id = action.target_id;
            Idle.add(() => {
                card_open_requested(card_id);
                return Source.REMOVE;
            });
        } else if (action.select_project) {
            var project_id = action.target_id;
            Idle.add(() => {
                focus_project_overview(project_id);
                return Source.REMOVE;
            });
        }
        return true;
    }

    private void focus_project_overview(string project_id) {
        show_projects_root = false;
        project_overview_requested(project_id);
        refresh_connections_structure();
        queue_connections_graph_refresh();
    }

    private void refresh_connections_structure() {
        refresh_relations_title();
        update_add_graph_link_button_state();
    }

    private void refresh_relations_title() {
        if (connections_relations_title_label == null) {
            return;
        }
        if (show_projects_root) {
            connections_relations_title_label.set_text("Projects");
            return;
        }
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;

        if (selected_card != null) {
            connections_relations_title_label.set_text(
                controller.ellipsize_title(selected_card.title)
            );
            return;
        }
        if (selected_project != null) {
            connections_relations_title_label.set_text(
                controller.ellipsize_title(selected_project.name)
            );
            return;
        }
        connections_relations_title_label.set_text("Relations");
    }

    private Gee.ArrayList<CardSummary> snapshot_cards() {
        var cards = new Gee.ArrayList<CardSummary>();
        if (card_store == null) {
            return cards;
        }
        for (uint i = 0; i < card_store.get_n_items(); i++) {
            var card = card_store.get_item(i) as CardSummary;
            if (card != null) {
                cards.add(card);
            }
        }
        return cards;
    }

    private void clear_fixed_children(Gtk.Fixed fixed) {
        Gtk.Widget? child = fixed.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            fixed.remove(child);
            child = next;
        }
    }

}

}
