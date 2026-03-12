namespace HolderLinux {

public class ConnectionsToolView : Object {
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
    private Gtk.Label connections_structure_label;
    private Gtk.SingleSelection? project_selection;
    private GLib.ListStore? card_store;
    private Gtk.SingleSelection? card_selection;
    private IHolderApi? api;
    private Settings? settings;
    private uint connections_graph_refresh_serial = 0;
    private ConnectionsController controller;

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

    public void set_internal_links(Gee.ArrayList<string> link_targets) {
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
    private string link_markup(string kind, string id, string title) {
        var href = "%s:%s".printf(kind, Uri.escape_string(id, null, false));
        return "<a href=\"%s\">%s</a>".printf(
            Markup.escape_text(href),
            Markup.escape_text(controller.ellipsize_title(title))
        );
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
        if (connections_graph_outgoing_list == null || connections_graph_backlinks_list == null) {
            return;
        }
        var selected_card = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;

        var expected_card_id = selected_card != null ? selected_card.card_id : "";
        var result = yield controller.load_graph_links(api, selected_card);

        if (request_serial != connections_graph_refresh_serial) {
            return;
        }
        var still_selected = card_selection != null
            ? card_selection.get_selected_item() as CardSummary
            : null;
        if (still_selected == null && expected_card_id != "") {
            return;
        }
        if (expected_card_id != "" && (still_selected == null || still_selected.card_id != expected_card_id)) {
            return;
        }

        if (result.success) {
            if (result.outgoing == null || result.backlinks == null) {
                return;
            }
            populate_graph_rows(result.outgoing, true);
            populate_graph_rows(result.backlinks, false);
            update_add_graph_link_button_state();
        } else {
            set_graph_empty_state(result.outgoing_empty_text, result.backlinks_empty_text);
            if (result.debug_message.strip().length > 0) {
                debug_log_requested(result.debug_message);
            }
        }
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

        var groups = controller.group_links_by_kind(links);
        foreach (var group in groups) {
            var kind = group.kind;
            var bucket = group.links;

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
                controller.ellipsize_title(controller.title_for_card_id(target_id, snapshot_cards()))
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
        var target_title = controller.title_for_card_id(target_id, snapshot_cards());

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
        var available_kinds = controller.list_available_link_kinds(settings);
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
        var result = yield controller.update_graph_link_flow(
            api,
            old_link,
            new_kind,
            new_label,
            remember_kind,
            settings
        );
        if (result.ignored) {
            return;
        }
        if (result.success) {
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            queue_connections_graph_refresh();
            return;
        }
        error_reported(result.error_title, result.error_details);
    }

    private async void delete_graph_link(CardLink link) {
        var result = yield controller.delete_graph_link_flow(api, link);
        if (result.ignored) {
            return;
        }
        if (result.success) {
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            queue_connections_graph_refresh();
            return;
        }
        error_reported(result.error_title, result.error_details);
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
                    ? controller.ellipsize_title(selected_card.title)
                    : "No card selected"
            );
        }
        connections_structure_label.set_markup(
            controller.compact_structure_markup(selected_project, selected_card, snapshot_cards())
        );
        update_add_graph_link_button_state();
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
