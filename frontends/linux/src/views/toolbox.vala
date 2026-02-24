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
    private Gtk.ListBox ai_catalog_list;
    private Gtk.Notebook terminal_notebook;
    private int next_terminal_index = 1;
    private Gtk.Entry git_remote_entry;
    private Gtk.Entry git_branch_entry;
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
    }

    public void set_settings(Settings? settings) {
        this.settings = settings;
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

        var connections_page = stack.add_titled(build_connections_tab(), "connections", "Connections");
        connections_page.set_icon_name("network-wired-symbolic");

        var resources_page = stack.add_titled(
            build_placeholder_tab("Resource tools are scaffolded and planned."),
            "resources",
            "Resources"
        );
        resources_page.set_icon_name("view-list-symbolic");

        flowboard = new FlowboardPane();
        var flowboard_page = stack.add_titled(flowboard.widget, "flowboard", "Flowboard");
        flowboard_page.set_icon_name("view-grid-symbolic");

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

        var trash_page = stack.add_titled(
            build_placeholder_tab("Trash tools are scaffolded and planned."),
            "trash",
            "Trash"
        );
        trash_page.set_icon_name("user-trash-symbolic");

        var debug_page = stack.add_titled(build_debug_tab(), "debug", "Debug");
        debug_page.set_icon_name("view-reveal-symbolic");

        stack.set_visible_child_name("terminals");
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
        columns.append(graph_scroller);

        var divider = new Gtk.Separator(Gtk.Orientation.VERTICAL);
        columns.append(divider);

        var context_scroller = new Gtk.ScrolledWindow();
        context_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        context_scroller.set_size_request(200, -1);
        context_scroller.set_hexpand(false);
        context_scroller.set_vexpand(true);
        context_scroller.set_child(context_column);
        columns.append(context_scroller);

        connections_card_title_label = new Gtk.Label("No card selected") { xalign = 0.0f };
        connections_card_title_label.add_css_class("title-5");
        connections_card_title_label.set_ellipsize(Pango.EllipsizeMode.END);
        connections_card_title_label.set_max_width_chars(30);
        connections_card_title_label.set_margin_start(0);
        connections_structure_label = new Gtk.Label("") { xalign = 0.0f };
        connections_structure_label.set_wrap(true);
        connections_structure_label.set_use_markup(true);
        connections_structure_label.add_css_class("dim-label");
        connections_structure_label.set_lines(4);
        connections_structure_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        connections_structure_label.set_yalign(0.0f);
        connections_structure_label.set_margin_top(4);
        connections_structure_label.set_margin_start(0);
        connections_structure_label.activate_link.connect((uri) => {
            return on_connections_link_activated(uri);
        });
        connections_internal_links_label = new Gtk.Label("Internal Links:") { xalign = 0.0f };
        connections_internal_links_label.add_css_class("dim-label");
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

        var backlinks_title = new Gtk.Label("Backlinks") { xalign = 0.0f };
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

    private Gtk.Widget build_placeholder_tab(string message) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var info = new Gtk.Label(message) { xalign = 0.0f };
        info.set_wrap(true);
        info.add_css_class("dim-label");
        box.append(info);
        return box;
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
        var project_parts = new Gee.ArrayList<string>();
        if (project != null) {
            project_parts.add("Project: %s".printf(link_markup("project", project.project_id, project.name)));
        } else {
            project_parts.add("Project: None");
        }

        if (selected_card != null && card_store != null) {
            var parent_id = normalize_parent(selected_card.parent_card_id);
            if (parent_id != null) {
                for (uint i = 0; i < card_store.get_n_items(); i++) {
                    var maybe_parent = card_store.get_item(i) as CardSummary;
                    if (maybe_parent != null && maybe_parent.card_id == parent_id) {
                        project_parts.add(
                            "Parent: %s".printf(link_markup("card", maybe_parent.card_id, maybe_parent.title))
                        );
                        break;
                    }
                }
            }
        }
        lines.add(string.joinv("   ", project_parts.to_array()));

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
        kind_label.add_css_class("heading");
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
