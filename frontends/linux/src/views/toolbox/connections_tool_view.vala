namespace HolderLinux {

private class ConnectionsBoardNode : Object {
    public string card_id { get; construct; }
    public string title { get; construct; }
    public int x { get; set; }
    public int y { get; set; }

    public ConnectionsBoardNode(string card_id, string title, int x = 0, int y = 0) {
        Object(card_id: card_id, title: title, x: x, y: y);
    }
}

private class ConnectionsBoardEdge : Object {
    public string from_card_id { get; construct; }
    public string to_card_id { get; construct; }
    public string kind { get; construct; }
    public bool dashed { get; construct; }

    public ConnectionsBoardEdge(string from_card_id, string to_card_id, string kind, bool dashed = false) {
        Object(from_card_id: from_card_id, to_card_id: to_card_id, kind: kind, dashed: dashed);
    }
}

public class ConnectionsToolView : Object {
    private const int BOARD_NODE_WIDTH = 220;
    private const int BOARD_NODE_HEIGHT = 76;
    private const int BOARD_PADDING = 48;
    private const int BOARD_MIN_WIDTH = 900;
    private const int BOARD_MIN_HEIGHT = 620;
    private const int PROJECT_MODE_MAX_NODES = 12;
    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    private Gtk.Box connections_breadcrumb_bar;
    private Gtk.Paned connections_main_pane;
    private Gtk.Overlay connections_board_overlay;
    private Gtk.DrawingArea connections_board_canvas;
    private Gtk.Fixed connections_board_nodes_layer;
    private Gtk.Box connections_graph_summary_row;
    private Gtk.Label connections_graph_summary_label;
    private Gtk.Label connections_board_empty_label;
    private Gtk.ToggleButton connections_relations_toggle_btn;
    private Gtk.ScrolledWindow connections_relations_scroller;
    private Gtk.Box connections_relations_column;
    private Gtk.Label connections_relations_structure_label;
    private Gtk.Label connections_relations_outgoing_label;
    private Gtk.Label connections_relations_backlinks_label;
    private Gtk.Label connections_relations_internal_label;
    private Gtk.Button connections_add_graph_link_btn;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    private uint connections_graph_refresh_serial = 0;
    private ConnectionsController controller;
    private Gee.ArrayList<string> internal_links_cache = new Gee.ArrayList<string>();
    private Gee.ArrayList<ConnectionsBoardNode> board_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    private Gee.ArrayList<ConnectionsBoardEdge> board_edges = new Gee.ArrayList<ConnectionsBoardEdge>();

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void debug_log_requested(string line);

    public ConnectionsToolView() {
        controller = new ConnectionsController();
        ensure_connections_css();
        widget = build_connections_tab();
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_connections_graph_refresh();
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

        project_selection.notify["selected"].connect(() => {
            refresh_connections_structure();
            queue_connections_graph_refresh();
        });
        card_selection.notify["selected"].connect(() => {
            refresh_connections_structure();
            queue_connections_graph_refresh();
        });
        card_store.items_changed.connect((position, removed, added) => {
            refresh_connections_structure();
            queue_connections_graph_refresh();
        });

        refresh_connections_structure();
        queue_connections_graph_refresh();
    }

    private Gtk.Widget build_connections_tab() {
        var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        connections_breadcrumb_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        connections_breadcrumb_bar.set_margin_top(6);
        connections_breadcrumb_bar.set_margin_bottom(6);
        connections_breadcrumb_bar.set_margin_start(6);
        connections_breadcrumb_bar.set_margin_end(6);
        root.append(connections_breadcrumb_bar);

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

        var graph_header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var graph_title = new Gtk.Label("Graph Connections") { xalign = 0.0f };
        graph_title.add_css_class("title-5");
        graph_title.set_hexpand(true);
        connections_add_graph_link_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        connections_add_graph_link_btn.set_tooltip_text("Add graph link");
        connections_add_graph_link_btn.set_sensitive(false);
        connections_add_graph_link_btn.clicked.connect(() => {
            open_add_graph_link_dialog();
        });
        connections_relations_toggle_btn = new Gtk.ToggleButton();
        connections_relations_toggle_btn.add_css_class("flat");
        connections_relations_toggle_btn.set_icon_name("sidebar-show-right-symbolic");
        connections_relations_toggle_btn.set_tooltip_text("Toggle relations panel");
        connections_relations_toggle_btn.set_active(true);
        connections_relations_toggle_btn.toggled.connect(() => {
            bool visible = connections_relations_toggle_btn.get_active();
            connections_relations_scroller.set_visible(visible);
        });
        graph_header.append(graph_title);
        graph_header.append(connections_relations_toggle_btn);
        graph_header.append(connections_add_graph_link_btn);
        graph_column.append(graph_header);

        connections_graph_summary_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        connections_graph_summary_label = new Gtk.Label("") { xalign = 0.0f };
        connections_graph_summary_label.add_css_class("caption");
        connections_graph_summary_label.add_css_class("dim-label");
        connections_graph_summary_label.set_wrap(true);
        connections_graph_summary_row.append(connections_graph_summary_label);
        graph_column.append(connections_graph_summary_row);

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

        var relations_title = new Gtk.Label("Relations") { xalign = 0.0f };
        relations_title.add_css_class("title-5");
        connections_relations_column.append(relations_title);

        connections_relations_structure_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_structure_label.set_wrap(true);
        connections_relations_structure_label.set_use_markup(true);
        connections_relations_structure_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_structure_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_column.append(connections_relations_structure_label);

        var outgoing_title = new Gtk.Label("Outgoing") { xalign = 0.0f };
        outgoing_title.add_css_class("heading");
        connections_relations_column.append(outgoing_title);
        connections_relations_outgoing_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_outgoing_label.set_wrap(true);
        connections_relations_outgoing_label.set_use_markup(true);
        connections_relations_outgoing_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_outgoing_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_column.append(connections_relations_outgoing_label);

        var incoming_title = new Gtk.Label("Incoming") { xalign = 0.0f };
        incoming_title.add_css_class("heading");
        connections_relations_column.append(incoming_title);
        connections_relations_backlinks_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_backlinks_label.set_wrap(true);
        connections_relations_backlinks_label.set_use_markup(true);
        connections_relations_backlinks_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_backlinks_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_column.append(connections_relations_backlinks_label);

        var internal_title = new Gtk.Label("Internal") { xalign = 0.0f };
        internal_title.add_css_class("heading");
        connections_relations_column.append(internal_title);
        connections_relations_internal_label = new Gtk.Label("") { xalign = 0.0f };
        connections_relations_internal_label.set_wrap(true);
        connections_relations_internal_label.set_use_markup(true);
        connections_relations_internal_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_relations_internal_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_relations_column.append(connections_relations_internal_label);

        connections_relations_scroller = new Gtk.ScrolledWindow();
        connections_relations_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        connections_relations_scroller.set_min_content_width(320);
        connections_relations_scroller.set_hexpand(false);
        connections_relations_scroller.set_vexpand(true);
        connections_relations_scroller.set_child(connections_relations_column);
        connections_main_pane.set_end_child(connections_relations_scroller);

        refresh_connections_structure();
        refresh_connections_breadcrumbs();
        set_graph_empty_state("Select a card to view graph links.");
        return root;
    }

    public void set_internal_links(Gee.ArrayList<string> link_targets) {
        internal_links_cache.clear();
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
        connections_board_empty_label.set_text(message);
        connections_board_empty_label.set_visible(true);
        connections_graph_summary_label.set_text("");
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
        connections_relations_outgoing_label.set_markup("None");
        connections_relations_backlinks_label.set_markup("None");
        connections_relations_internal_label.set_markup("None");
    }

    private void set_relations_for_card(Project project,
                                        CardSummary selected_card,
                                        Gee.ArrayList<CardLink> outgoing,
                                        Gee.ArrayList<CardLink> backlinks) {
        connections_relations_structure_label.set_markup(
            controller.compact_structure_markup(project, selected_card, snapshot_cards())
        );
        connections_relations_outgoing_label.set_markup(format_link_lines(outgoing, true));
        connections_relations_backlinks_label.set_markup(format_link_lines(backlinks, false));
        connections_relations_internal_label.set_markup(format_internal_lines(project.project_id));
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
        var available_kinds = controller.list_available_link_kinds(settings);
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
                controller.remember_custom_link_kind(settings, kind);
            }
            toast_requested("Graph link added.");
            queue_connections_graph_refresh();
        } catch (Error e) {
            error_reported("Failed to add graph link", e.message);
        }
    }

    private void queue_connections_graph_refresh() {
        connections_graph_refresh_serial++;
        refresh_connections_graph.begin(connections_graph_refresh_serial);
    }

    private async void refresh_connections_graph(uint request_serial) {
        if (connections_board_overlay == null || connections_board_nodes_layer == null || connections_board_canvas == null) {
            return;
        }
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (selected_project == null) {
            set_graph_empty_state("Select a project to view connections.");
            return;
        }
        if (selected_card != null && selected_card.project_id != selected_project.project_id) {
            selected_card = null;
        }

        if (selected_card != null) {
            var expected_card_id = selected_card.card_id;
            var result = yield controller.load_graph_links(api, selected_card);

            if (request_serial != connections_graph_refresh_serial) {
                return;
            }
            var still_selected = card_selection != null
                ? card_selection.get_selected_item() as CardSummary
                : null;
            if (still_selected == null || still_selected.card_id != expected_card_id) {
                return;
            }
            if (!result.success || result.outgoing == null || result.backlinks == null) {
                set_graph_empty_state(result.outgoing_empty_text);
                if (result.debug_message.strip().length > 0) {
                    debug_log_requested(result.debug_message);
                }
                return;
            }
            render_card_mode_board(selected_project, selected_card, result.outgoing, result.backlinks);
            update_add_graph_link_button_state();
            return;
        }

        if (api == null) {
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
            if (request_serial != connections_graph_refresh_serial) {
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
                set_graph_empty_state("Failed to load project graph links.");
                debug_log_requested("Project graph links refresh failed: %s".printf(e.message));
                return;
            }
        }
        if (request_serial != connections_graph_refresh_serial) {
            return;
        }
        render_project_mode_board(selected_project, cards, project_links);
        update_add_graph_link_button_state();
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
            controller.ellipsize_title(selected_card.title)
        ));
        var edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        var edge_keys = new Gee.HashSet<string>();

        foreach (var link in outgoing) {
            if (link.to_type != "card") {
                continue;
            }
            add_board_edge(nodes_by_id, edge_keys, edges, link.from_card_id, link.to_card_id, normalized_kind(link.kind), false, cards);
        }
        foreach (var link in backlinks) {
            if (link.to_type != "card") {
                continue;
            }
            add_board_edge(nodes_by_id, edge_keys, edges, link.from_card_id, link.to_card_id, normalized_kind(link.kind), false, cards);
        }

        var structural = build_structural_edges_for_selected(selected_card, project_cards);
        foreach (var edge in structural) {
            add_board_edge(nodes_by_id, edge_keys, edges, edge.from_card_id, edge.to_card_id, edge.kind, true, cards);
        }
        foreach (var target in internal_links_cache) {
            var target_card_id = controller.resolve_internal_link_target_card_id(target, project.project_id, cards);
            if (target_card_id != null && target_card_id != selected_card.card_id) {
                add_board_edge(nodes_by_id, edge_keys, edges, selected_card.card_id, target_card_id, "internal", true, cards);
            }
        }

        var node_list = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var node in nodes_by_id.values) {
            node_list.add(node);
        }
        node_list.sort((a, b) => strcmp(a.title.down(), b.title.down()));
        layout_card_mode_nodes(selected_card.card_id, node_list);
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
            set_graph_empty_state("No cards in this project yet.");
            return;
        }

        var all_edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        var edge_keys = new Gee.HashSet<string>();
        var counts = new Gee.HashMap<string, int>();
        foreach (var link in project_links) {
            var kind = normalized_kind(link.kind);
            if (add_edge_to_list(edge_keys, all_edges, link.from_card_id, link.to_card_id, kind, false)) {
                increment_count(counts, kind);
            }
        }
        foreach (var edge in build_structural_edges_for_project(project_cards)) {
            if (add_edge_to_list(edge_keys, all_edges, edge.from_card_id, edge.to_card_id, edge.kind, true)) {
                increment_count(counts, edge.kind);
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
            nodes.add(new ConnectionsBoardNode(card.card_id, controller.ellipsize_title(card.title)));
        }
        var edges = new Gee.ArrayList<ConnectionsBoardEdge>();
        foreach (var edge in all_edges) {
            if (keep.contains(edge.from_card_id) && keep.contains(edge.to_card_id)) {
                edges.add(edge);
            }
        }
        layout_project_mode_nodes(nodes);
        var summary = format_counts_summary(counts);
        render_board(nodes, edges, summary);
        set_relations_overview(summary);
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
        int required_h = BOARD_MIN_HEIGHT;
        foreach (var node in nodes) {
            required_w = int.max(required_w, node.x + BOARD_NODE_WIDTH + BOARD_PADDING);
            required_h = int.max(required_h, node.y + BOARD_NODE_HEIGHT + BOARD_PADDING);
            var node_widget = build_board_node_widget(node);
            connections_board_nodes_layer.put(node_widget, node.x, node.y);
        }
        ensure_board_canvas_size(required_w, required_h);
        connections_board_empty_label.set_visible(nodes.size == 0);
        if (nodes.size == 0) {
            connections_board_empty_label.set_text("No connections to display.");
        }
        connections_graph_summary_label.set_text(summary_text);
        connections_board_canvas.queue_draw();
    }

    private Gtk.Widget build_board_node_widget(ConnectionsBoardNode node) {
        var button = new Gtk.Button();
        button.add_css_class("flat");
        button.add_css_class("flowboard-tile");
        button.add_css_class("connections-board-node");
        button.set_size_request(BOARD_NODE_WIDTH, BOARD_NODE_HEIGHT);
        var inner = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        inner.set_margin_top(10);
        inner.set_margin_bottom(10);
        inner.set_margin_start(12);
        inner.set_margin_end(12);

        var title = new Gtk.Label(node.title) { xalign = 0.0f };
        title.set_ellipsize(Pango.EllipsizeMode.END);
        title.set_max_width_chars(32);
        title.add_css_class("heading");
        inner.append(title);

        var subtitle = new Gtk.Label(node.card_id) { xalign = 0.0f };
        subtitle.add_css_class("caption");
        subtitle.add_css_class("dim-label");
        subtitle.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
        subtitle.set_max_width_chars(24);
        inner.append(subtitle);

        button.set_child(inner);
        button.clicked.connect(() => {
            select_card_by_id(node.card_id);
        });
        return button;
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

    private string normalized_kind(string? kind) {
        if (kind == null) {
            return "ref";
        }
        var cleaned = kind.strip();
        return cleaned.length > 0 ? cleaned : "ref";
    }

    private bool add_edge_to_list(Gee.HashSet<string> edge_keys,
                                  Gee.ArrayList<ConnectionsBoardEdge> edges,
                                  string from_card_id,
                                  string to_card_id,
                                  string kind,
                                  bool dashed) {
        if (from_card_id == to_card_id) {
            return false;
        }
        var key = "%s|%s|%s".printf(from_card_id, to_card_id, kind);
        if (edge_keys.contains(key)) {
            return false;
        }
        edge_keys.add(key);
        edges.add(new ConnectionsBoardEdge(from_card_id, to_card_id, kind, dashed));
        return true;
    }

    private void add_board_edge(Gee.HashMap<string, ConnectionsBoardNode> nodes_by_id,
                                Gee.HashSet<string> edge_keys,
                                Gee.ArrayList<ConnectionsBoardEdge> edges,
                                string from_card_id,
                                string to_card_id,
                                string kind,
                                bool dashed,
                                Gee.ArrayList<CardSummary> cards) {
        if (!add_edge_to_list(edge_keys, edges, from_card_id, to_card_id, kind, dashed)) {
            return;
        }
        ensure_node(nodes_by_id, from_card_id, cards);
        ensure_node(nodes_by_id, to_card_id, cards);
    }

    private void ensure_node(Gee.HashMap<string, ConnectionsBoardNode> nodes_by_id,
                             string card_id,
                             Gee.ArrayList<CardSummary> cards) {
        if (nodes_by_id.has_key(card_id)) {
            return;
        }
        var title = controller.ellipsize_title(controller.title_for_card_id(card_id, cards));
        nodes_by_id.set(card_id, new ConnectionsBoardNode(card_id, title));
    }

    private Gee.ArrayList<ConnectionsBoardEdge> build_structural_edges_for_selected(CardSummary selected_card,
                                                                                     Gee.ArrayList<CardSummary> project_cards) {
        var out = new Gee.ArrayList<ConnectionsBoardEdge>();
        var siblings = sibling_cards(selected_card, project_cards);
        int selected_index = -1;
        for (int i = 0; i < siblings.size; i++) {
            if (siblings[i].card_id == selected_card.card_id) {
                selected_index = i;
                break;
            }
        }
        if (selected_index > 0) {
            out.add(new ConnectionsBoardEdge(siblings[selected_index - 1].card_id, selected_card.card_id, "next", true));
        }
        if (selected_index >= 0 && selected_index < siblings.size - 1) {
            out.add(new ConnectionsBoardEdge(selected_card.card_id, siblings[selected_index + 1].card_id, "next", true));
        }
        var parent_id = normalize_parent(selected_card.parent_card_id);
        if (parent_id != null) {
            out.add(new ConnectionsBoardEdge(parent_id, selected_card.card_id, "child", true));
        }
        foreach (var card in project_cards) {
            if (normalize_parent(card.parent_card_id) == selected_card.card_id) {
                out.add(new ConnectionsBoardEdge(selected_card.card_id, card.card_id, "child", true));
            }
        }
        return out;
    }

    private Gee.ArrayList<ConnectionsBoardEdge> build_structural_edges_for_project(Gee.ArrayList<CardSummary> project_cards) {
        var out = new Gee.ArrayList<ConnectionsBoardEdge>();
        var parent_groups = new Gee.HashMap<string, Gee.ArrayList<CardSummary>>();
        foreach (var card in project_cards) {
            var parent_key = normalize_parent(card.parent_card_id) ?? "";
            var group = parent_groups.get(parent_key);
            if (group == null) {
                group = new Gee.ArrayList<CardSummary>();
                parent_groups.set(parent_key, group);
            }
            group.add(card);
            if (parent_key.length > 0) {
                out.add(new ConnectionsBoardEdge(parent_key, card.card_id, "child", true));
            }
        }
        foreach (var group in parent_groups.values) {
            group.sort((a, b) => compare_sibling_order(a, b));
            for (int i = 0; i < group.size - 1; i++) {
                out.add(new ConnectionsBoardEdge(group[i].card_id, group[i + 1].card_id, "next", true));
            }
        }
        return out;
    }

    private void layout_card_mode_nodes(string center_card_id, Gee.ArrayList<ConnectionsBoardNode> nodes) {
        int cx = BOARD_MIN_WIDTH / 2 - BOARD_NODE_WIDTH / 2;
        int cy = BOARD_MIN_HEIGHT / 2 - BOARD_NODE_HEIGHT / 2;
        var ring = new Gee.ArrayList<ConnectionsBoardNode>();
        foreach (var node in nodes) {
            if (node.card_id == center_card_id) {
                node.x = cx;
                node.y = cy;
            } else {
                ring.add(node);
            }
        }
        if (ring.size == 0) {
            return;
        }
        int step_x = BOARD_NODE_WIDTH + 56;
        int step_y = BOARD_NODE_HEIGHT + 34;
        int placed = 0;
        for (int radius = 1; placed < ring.size; radius++) {
            for (int grid_y = -radius; grid_y <= radius && placed < ring.size; grid_y++) {
                for (int grid_x = -radius; grid_x <= radius && placed < ring.size; grid_x++) {
                    if (imax(iabs(grid_x), iabs(grid_y)) != radius) {
                        continue;
                    }
                    ring[placed].x = int.max(BOARD_PADDING / 2, cx + grid_x * step_x);
                    ring[placed].y = int.max(BOARD_PADDING / 2, cy + grid_y * step_y);
                    placed++;
                }
            }
        }
    }

    private void layout_project_mode_nodes(Gee.ArrayList<ConnectionsBoardNode> nodes) {
        if (nodes.size == 0) {
            return;
        }
        int cols = 1;
        while ((cols * cols) < nodes.size) {
            cols++;
        }
        int gap_x = 36;
        int gap_y = 36;
        int start_x = BOARD_PADDING;
        int start_y = BOARD_PADDING + 12;
        for (int i = 0; i < nodes.size; i++) {
            int col = i % cols;
            int row = i / cols;
            nodes[i].x = start_x + col * (BOARD_NODE_WIDTH + gap_x);
            nodes[i].y = start_y + row * (BOARD_NODE_HEIGHT + gap_y);
        }
    }

    private double absd(double value) {
        return value < 0 ? -value : value;
    }

    private int iabs(int value) {
        return value < 0 ? -value : value;
    }

    private int imax(int a, int b) {
        return a >= b ? a : b;
    }

    private string format_counts_summary(Gee.HashMap<string, int> counts) {
        if (counts.size == 0) {
            return "No graph relationships yet.";
        }
        var keys = new Gee.ArrayList<string>();
        foreach (var key in counts.keys) {
            keys.add(key);
        }
        keys.sort((a, b) => {
            var ca = counts.get(a);
            var cb = counts.get(b);
            if (ca != cb) {
                return cb - ca;
            }
            return strcmp(a, b);
        });
        var parts = new Gee.ArrayList<string>();
        foreach (var key in keys) {
            parts.add("%s: %d".printf(key, counts.get(key)));
        }
        return "Project relationship summary  •  %s".printf(string.joinv("  •  ", parts.to_array()));
    }

    private void increment_count(Gee.HashMap<string, int> counts, string kind) {
        if (counts.has_key(kind)) {
            counts.set(kind, counts.get(kind) + 1);
            return;
        }
        counts.set(kind, 1);
    }

    private Gee.ArrayList<CardSummary> sibling_cards(CardSummary selected_card, Gee.ArrayList<CardSummary> project_cards) {
        var siblings = new Gee.ArrayList<CardSummary>();
        var target_parent = normalize_parent(selected_card.parent_card_id);
        foreach (var card in project_cards) {
            if (normalize_parent(card.parent_card_id) == target_parent) {
                siblings.add(card);
            }
        }
        siblings.sort((a, b) => compare_sibling_order(a, b));
        return siblings;
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

    private static void ensure_connections_css() {
        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
.connections-board-surface {
  border-radius: 10px;
  border: 1px solid alpha(@borders, 0.70);
  background-color: #090909;
}

.connections-board-node {
  border-radius: 8px;
  border: 1px solid alpha(@borders, 0.75);
  box-shadow: none;
  background-image: none;
  background-color: alpha(@card_bg_color, 0.35);
  color: @view_fg_color;
}

.connections-board-node:hover {
  background-color: alpha(@card_bg_color, 0.50);
}
""");
        gtk_style_context_add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
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
                select_card_by_id(card_id);
                return Source.REMOVE;
            });
        } else if (action.select_project) {
            var project_id = action.target_id;
            Idle.add(() => {
                select_project_by_id(project_id);
                return Source.REMOVE;
            });
        }
        return true;
    }

    private void refresh_connections_structure() {
        refresh_connections_breadcrumbs();
        update_add_graph_link_button_state();
    }

    private void refresh_connections_breadcrumbs() {
        if (connections_breadcrumb_bar == null) {
            return;
        }
        clear_box_children(connections_breadcrumb_bar);

        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var leaf_label = selected_card != null
            ? controller.ellipsize_title(selected_card.title)
            : "Overview";
        string[] segments = { "Projects", project_label, leaf_label };

        for (int i = 0; i < segments.length; i++) {
            var btn = new Gtk.Button.with_label(segments[i]);
            btn.add_css_class("flat");
            btn.set_focusable(false);
            connections_breadcrumb_bar.append(btn);
            if (i < segments.length - 1) {
                var sep = new Gtk.Label(" / ");
                sep.add_css_class("dim-label");
                connections_breadcrumb_bar.append(sep);
            }
        }
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

    private void clear_box_children(Gtk.Box box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }
}

}
