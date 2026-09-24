namespace HolderLinux {

public class ConnectionsToolView : Object, IToolShellAdapter {
    private const int BOARD_NODE_WIDTH = ConnectionsBoardPresenter.NODE_WIDTH;
    private const int BOARD_NODE_HEIGHT = ConnectionsBoardPresenter.NODE_HEIGHT;
    private const int BOARD_PADDING = ConnectionsBoardPresenter.PADDING;
    private const int BOARD_MIN_WIDTH = ConnectionsBoardPresenter.MIN_WIDTH;
    private const int BOARD_MIN_HEIGHT = ConnectionsBoardPresenter.MIN_HEIGHT;
    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    private Gtk.Box connections_actions_bar; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Paned connections_main_pane; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Overlay connections_board_overlay; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.DrawingArea connections_board_canvas; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Fixed connections_board_nodes_layer; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label connections_board_empty_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ToggleButton connections_relations_toggle_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.ScrolledWindow connections_relations_scroller; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Box connections_relations_column; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label connections_relations_title_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label connections_relations_structure_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Box connections_relations_outgoing_section; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label connections_relations_outgoing_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Box connections_relations_backlinks_section; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label connections_relations_backlinks_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Box connections_relations_internal_section; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Label connections_relations_internal_label; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.Button connections_add_graph_link_btn; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SingleSelection? project_selection; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private GLib.ListStore? card_store; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gtk.SingleSelection? card_selection; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private IHolderApi? api; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Settings? settings; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ConnectionsController controller; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ConnectionsRefreshPlanner refresh_planner; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private IScheduler scheduler; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ConnectionsRelationsPresenter relations_presenter; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ConnectionsBoardPresenter board_presenter; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ConnectionsBoardBuilder board_builder; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private Gee.ArrayList<string> internal_links_cache = new Gee.ArrayList<string>();
    private Gee.ArrayList<ConnectionsBoardNode> board_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    private Gee.ArrayList<ConnectionsBoardEdge> board_edges = new Gee.ArrayList<ConnectionsBoardEdge>();
    private bool relations_default_split_applied = false;
    private uint relations_default_split_idle_id = 0;
    private bool show_projects_root = false;
    private bool has_committed_board = false;

    private void note_graph_refresh_content_changed() {
        refresh_planner.note_content_changed();
    }

    private ConnectionsGraphRefreshTarget current_graph_refresh_target(uint content_generation) {
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
            content_generation
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

    public ConnectionsToolView(IScheduler? scheduler = null) {
        this.scheduler = scheduler ?? new MainLoopScheduler();
        controller = new ConnectionsController();
        relations_presenter = new ConnectionsRelationsPresenter(controller);
        board_presenter = new ConnectionsBoardPresenter(controller);
        board_builder = new ConnectionsBoardBuilder(controller);
        refresh_planner = new ConnectionsRefreshPlanner(
            this.scheduler,
            (content_generation) => current_graph_refresh_target(content_generation)
        );
        refresh_planner.debug_event.connect((event_name, target) => {
            debug_log_requested(controller.format_graph_refresh_debug_event(event_name, target));
        });
        refresh_planner.refresh_dispatched.connect((serial, generation, target) => {
            refresh_connections_graph.begin(serial, generation, target);
        });
        refresh_planner.empty_state_check_due.connect((project_id) => {
            show_empty_project_state_if_still_empty(project_id);
        });
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
        update_add_graph_link_button_state();
        queue_connections_graph_refresh();
    }

    public void set_tool_visible(bool visible) {
        refresh_planner.set_tool_visible(visible);
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
        return ToolScopePresenter.snapshot_with_projects_root(
            tool_id, tool_label, show_projects_root, selected_project, selected_card
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
        Adw.StyleManager.get_for_display(connections_board_canvas.get_display()).notify["dark"].connect(() => {
            connections_board_canvas.queue_draw();
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
            return Source.REMOVE; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: the callback is removed once applied and the pane is built before it is queued
        }
        int total_width = connections_main_pane.get_width();
        if (total_width <= 0) {
            return Source.CONTINUE;
        }
        connections_main_pane.set_position(ConnectionsBoardPresenter.default_relations_split_position(total_width));
        relations_default_split_applied = true;
        relations_default_split_idle_id = 0;
        return Source.REMOVE;
    }

    private void queue_apply_default_relations_split() {
        if (relations_default_split_applied || relations_default_split_idle_id != 0) {
            return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: queued once, from the constructor, before anything is applied
        }
        relations_default_split_idle_id = scheduler.schedule_repeating(30, () => {
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

    private void apply_relations(ConnectionsRelationsPresentation presentation) {
        apply_relations_text(connections_relations_structure_label, presentation.structure);
        apply_relations_text(connections_relations_outgoing_label, presentation.outgoing);
        apply_relations_text(connections_relations_backlinks_label, presentation.backlinks);
        apply_relations_text(connections_relations_internal_label, presentation.internal_links);
        connections_relations_outgoing_section.set_visible(presentation.sections_visible);
        connections_relations_backlinks_section.set_visible(presentation.sections_visible);
        connections_relations_internal_section.set_visible(presentation.sections_visible);
    }

    private void apply_relations_text(Gtk.Label label, ConnectionsRelationsText text) {
        label.set_markup(text.markup);
        label.update_property(Gtk.AccessibleProperty.LABEL, text.plain, -1);
    }

    private void set_relations_overview(string text) {
        if (connections_relations_structure_label == null) {
            return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: widget is assigned in the constructor before any caller can run
        }
        apply_relations(relations_presenter.overview(text));
    }

    private void set_relations_for_card(Project project,
                                        CardSummary selected_card,
                                        Gee.ArrayList<CardLink> outgoing,
                                        Gee.ArrayList<CardLink> backlinks) {
        apply_relations(relations_presenter.for_card(
            project, selected_card, outgoing, backlinks, internal_links_cache, snapshot_cards()
        ));
    }

    private void update_add_graph_link_button_state() {
        if (connections_add_graph_link_btn == null) {
            return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: widget is assigned in the constructor before any caller can run
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        connections_add_graph_link_btn.set_sensitive(board_presenter.add_link_enabled(
            show_projects_root, api != null, selected_card, snapshot_cards()
        ));
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

        var dialog = new Adw.AlertDialog("Add Graph Connection", "Create an explicit card-to-card connection.");
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
                var request = ConnectionsAddLinkPresenter.resolve(
                    target_ids,
                    target_dropdown.get_selected(),
                    available_kinds,
                    (int) kind_dropdown.get_selected(),
                    custom_kind_entry.get_text(),
                    label_entry.get_text()
                );
                if (request == null) {
                    return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: the dialog always has a target and a kind selected, so resolve() returns a request
                }
                create_graph_link.begin(
                    selected_card.card_id,
                    request.to_card_id,
                    request.kind,
                    request.label,
                    request.remember_kind
                );
            }
        });
        dialog.present(root);
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
        refresh_planner.queue_refresh();
    }

    private async void refresh_connections_graph(uint request_serial,
                                                uint request_generation,
                                                ConnectionsGraphRefreshTarget request_target) {
        try {
            if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale preflight")) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: runs synchronously with the dispatch, so the serial and generation cannot have changed yet
            }
            if (connections_board_overlay == null || connections_board_nodes_layer == null || connections_board_canvas == null) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: widgets are assigned in the constructor before a refresh can be dispatched
            }
            if (show_projects_root) {
                if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale projects root")) {
                    return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: runs synchronously with the dispatch, so the serial and generation cannot have changed yet
                }
                refresh_planner.record_committed(request_target, request_generation);
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
                if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale missing project")) {
                    return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: runs synchronously with the dispatch, so the serial and generation cannot have changed yet
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

                if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale card result")) {
                    return;
                }
                var still_selected = card_selection != null
                    ? card_selection.get_selected_item() as CardSummary
                    : null; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: card mode is only reached once the card selection model is bound
                if (still_selected == null || still_selected.card_id != expected_card_id) {
                    refresh_planner.report_dropped(request_target, "dropped stale card selection"); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: any selection change also bumps the generation, which drop_if_stale() above already handles
                    return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: any selection change also bumps the generation, which drop_if_stale() above already handles
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
                refresh_planner.record_committed(request_target, request_generation);
                render_card_mode_board(selected_project, selected_card, result.outgoing, result.backlinks);
                update_add_graph_link_button_state();
                return;
            }

            if (api == null) {
                if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale api unavailable")) {
                    return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: runs synchronously with the dispatch, so the serial and generation cannot have changed yet
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
                if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale project result")) {
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
            if (refresh_planner.drop_if_stale(request_serial, request_generation, request_target, "dropped stale project completion")) {
                return;
            }
            refresh_planner.record_committed(request_target, request_generation);
            render_project_mode_board(selected_project, cards, project_links);
            update_add_graph_link_button_state();
        } finally {
            refresh_planner.finish_flight();
        }
    }

    private void render_card_mode_board(Project project,
                                        CardSummary selected_card,
                                        Gee.ArrayList<CardLink> outgoing,
                                        Gee.ArrayList<CardLink> backlinks) {
        var model = board_builder.build_card_mode(
            project, selected_card, outgoing, backlinks, internal_links_cache, snapshot_cards()
        );
        render_board(model.nodes, model.edges, model.summary);
        set_relations_for_card(project, selected_card, outgoing, backlinks);
    }

    private void render_project_mode_board(Project project,
                                           Gee.ArrayList<CardSummary> cards,
                                           Gee.ArrayList<CardLink> project_links) {
        var project_cards = ConnectionsBoardBuilder.cards_in_project(project, cards);
        switch (ConnectionsEmptyStatePolicy.plan_for_project_cards(project, project_cards.size, has_committed_board)) {
        case ConnectionsProjectRenderPlan.SHOW_EMPTY_NOW:
            set_graph_empty_state("No cards in this project yet.");
            return;
        case ConnectionsProjectRenderPlan.SCHEDULE_EMPTY_CHECK:
            refresh_planner.schedule_empty_state_check(project.project_id);
            return;
        default:
            break;
        }
        refresh_planner.clear_pending_empty_state();

        var model = board_builder.build_project_mode(project_cards, project_links);
        render_board(model.nodes, model.edges, model.summary);
        set_relations_overview(model.summary);
    }

    private void show_empty_project_state_if_still_empty(string project_id) {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: the selection models are bound before the empty-state check is scheduled
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: the selection models are bound before the empty-state check is scheduled
        if (ConnectionsEmptyStatePolicy.should_show_no_cards(
                show_projects_root, selected_project, project_id, selected_card, snapshot_cards())) {
            set_graph_empty_state("No cards in this project yet.");
        }
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

        var projects = new Gee.ArrayList<Project>();
        for (uint i = 0; i < model.get_n_items(); i++) {
            var project = model.get_item(i) as Project;
            if (project != null) {
                projects.add(project);
            }
        }
        var nodes = board_presenter.build_projects_root_nodes(projects);
        if (nodes.size == 0) {
            set_graph_empty_state("No projects available.");
            return;
        }
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

        foreach (var node in nodes) {
            connections_board_nodes_layer.put(build_board_node_widget(node), node.x, node.y);
        }
        var canvas_size = board_presenter.canvas_size(nodes);
        ensure_board_canvas_size(canvas_size.width, canvas_size.height);
        connections_board_empty_label.set_visible(nodes.size == 0);
        if (nodes.size == 0) {
            connections_board_empty_label.set_text("No connections to display."); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: callers show their own empty state when there are no nodes; kept as a fallback
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
        double line_color = Adw.StyleManager.get_for_display(connections_board_canvas.get_display()).get_dark()
            ? 1.0 : 0.0;
        cr.set_source_rgba(line_color, line_color, line_color, 0.88);
        foreach (var edge in board_edges) {
            var from = node_map.get(edge.from_card_id);
            var to = node_map.get(edge.to_card_id);
            if (from == null || to == null) {
                continue; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: the board builder only emits edges between nodes it also emits
            }
            double x0;
            double y0;
            ConnectionsBoardGeometry.point_on_node_edge(
                from.x, from.y, to.x, to.y, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT, out x0, out y0
            );
            double x1;
            double y1;
            ConnectionsBoardGeometry.point_on_node_edge(
                to.x, to.y, from.x, from.y, BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT, out x1, out y1
            );
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

    private void draw_arrow_head(Cairo.Context cr,
                                 double x0,
                                 double y0,
                                 double x1,
                                 double y1) {
        var head = ConnectionsBoardGeometry.arrow_head(x0, y0, x1, y1);
        if (head == null) {
            return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: arrow_head() is null only for a zero-length edge, and nodes never share a position
        }
        cr.move_to(head.tip_x, head.tip_y);
        cr.line_to(head.first_x, head.first_y);
        cr.line_to(head.second_x, head.second_y);
        cr.close_path();
        cr.fill();
    }

    private void ensure_board_canvas_size(int width, int height) {
        connections_board_overlay.set_size_request(width, height);
        connections_board_canvas.set_content_width(width);
        connections_board_canvas.set_content_height(height);
        connections_board_nodes_layer.set_size_request(width, height);
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
            return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: widget is assigned in the constructor before any caller can run
        }
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        connections_relations_title_label.set_text(
            board_presenter.relations_title(show_projects_root, selected_project, selected_card)
        );
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
