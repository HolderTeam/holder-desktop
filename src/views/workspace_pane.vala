namespace HolderLinux {

public class WorkspacePane : Object {
    private const double DEFAULT_TOOLBOX_FRACTION = 0.5;
    private const int MIN_AI_PANEL_WIDTH = 360;
    private const int MAX_AI_PANEL_WIDTH = 720;
    private const double DEFAULT_AI_PANEL_FRACTION = 0.38;
    private Gtk.Label title_label;
    private Gtk.ToggleButton explorer_toggle_btn;
    private Gtk.ToggleButton search_toggle_btn;
    private Gtk.ToggleButton editor_toggle_btn;
    private Gtk.ToggleButton toolbox_toggle_btn;
    private Gtk.Label save_state_label;
    private Gtk.Revealer message_revealer;
    private Gtk.Label message_label;
    private Gtk.Button message_debug_button;
    private Gtk.Box search_row;
    private Gtk.Revealer find_revealer;
    private Gtk.Box replace_row;
    private Gtk.Entry find_entry;
    private Gtk.Entry replace_entry;
    private Gtk.Paned content_paned;
    private int last_ai_panel_width = -1;
    private bool ai_panel_width_user_set = false;
    private bool suppress_ai_position_persist = false;
    private bool ai_panel_visible = false;
    public Gtk.Widget widget { get; private set; }
    public GtkSource.Buffer editor_buffer { get; private set; }
    public GtkSource.View editor_view { get; private set; }
    public Spelling.TextBufferAdapter? spelling_adapter { get; private set; }
    public Gtk.SearchEntry search_entry { get; private set; }
    public Gtk.Stack content_stack { get; private set; }
    public Gtk.Label search_summary_label { get; private set; }
    public Gtk.SingleSelection search_selection { get; private set; }
    public Gtk.ListView search_list { get; private set; }
    public Gtk.Paned ai_split { get; private set; }
    public AiPanel ai_panel { get; private set; }
    public ToolboxPane toolbox { get; private set; }

    public signal void refresh_requested();
    public signal void new_project_requested();
    public signal void new_card_requested();
    public signal void explorer_panel_toggled(bool visible);
    public signal void ai_panel_toggled(bool visible);
    public signal void toolbox_toggled(bool visible);
    public signal void open_debug_panel_requested();
    public signal void search_activated();
    public signal void search_changed();
    public signal void search_cleared();
    public signal void search_focus_results_requested();
    public signal void search_result_activated(uint position);
    public signal void find_next_requested();
    public signal void replace_requested();
    public signal void replace_all_requested();

    public WorkspacePane(GLib.ListModel search_model) {
        widget = build_ui(search_model);
    }

    public void set_window_title_text(string title_text) {
        title_label.set_text(title_text);
    }

    public void set_save_state_text(string text) {
        if (text == null || text.strip().length == 0) {
            save_state_label.set_text("");
            save_state_label.set_visible(false);
            return;
        }
        save_state_label.set_text(text);
        save_state_label.set_visible(true);
    }

    public void set_app_message(string? text) {
        if (text == null || text.strip().length == 0) {
            message_label.set_text("");
            message_debug_button.set_visible(false);
            message_revealer.set_reveal_child(false);
            return;
        }
        message_label.set_text(text);
        message_debug_button.set_visible(true);
        message_revealer.set_reveal_child(true);
    }

    public void set_editor_state(string text, bool editable) {
        Gtk.TextIter start;
        Gtk.TextIter end;
        editor_buffer.get_bounds(out start, out end);
        var current_text = editor_buffer.get_text(start, end, false);
        if (current_text != text) {
            editor_buffer.set_text(text, -1);
        }
        if (editor_view.get_editable() != editable) {
            editor_view.set_editable(editable);
        }
    }

    public void show_editor_mode() {
        content_stack.set_visible_child_name("editor");
    }

    public void show_search_mode() {
        content_stack.set_visible_child_name("search");
    }

    public void toggle_toolbox() {
        if (toolbox_toggle_btn == null) {
            return;
        }
        toolbox_toggle_btn.set_active(!toolbox_toggle_btn.get_active());
    }

    public void show_find_replace_bar(bool show_replace) {
        replace_row.set_visible(show_replace);
        find_revealer.set_reveal_child(true);
        find_entry.grab_focus();
        find_entry.select_region(0, -1);
    }

    public void toggle_find_replace_bar(bool show_replace) {
        if (find_revealer.get_reveal_child()) {
            hide_find_replace_bar();
            return;
        }
        show_find_replace_bar(show_replace);
    }

    public void hide_find_replace_bar() {
        find_revealer.set_reveal_child(false);
    }

    public string get_find_text() {
        return find_entry.get_text();
    }

    public string get_replace_text() {
        return replace_entry.get_text();
    }

    public void set_spell_check_enabled(bool enabled) {
        if (spelling_adapter != null) {
            spelling_adapter.set_enabled(enabled);
        }
    }

    public void set_toolbox_visible(bool visible) {
        if (visible) {
            toolbox.widget.set_visible(true);
            toolbox.set_reveal_child(true);
            if (content_paned.get_position() <= 0) {
                apply_initial_toolbox_position(true);
            }
        } else {
            toolbox.set_reveal_child(false);
            toolbox.widget.set_visible(false);
        }
    }

    public void set_ai_panel_visible(bool visible) {
        ai_panel_visible = visible;
        ai_panel.widget.set_visible(visible);
        if (visible) {
            apply_initial_ai_panel_position(true);
        }
    }

    public bool is_ai_panel_visible() {
        return ai_panel_visible;
    }

    public void set_ai_panel_width(int width) {
        if (width > 0) {
            last_ai_panel_width = clamp_ai_panel_width(width);
            ai_panel_width_user_set = true;
        } else {
            last_ai_panel_width = -1;
            ai_panel_width_user_set = false;
        }
    }

    public int get_ai_panel_width_for_persist() {
        if (!ai_panel_width_user_set || last_ai_panel_width <= 0) {
            return 0;
        }
        return clamp_ai_panel_width(last_ai_panel_width);
    }

    private void apply_initial_toolbox_position(bool allow_defer) {
        var paned_height = content_paned.get_height();
        if (paned_height <= 0) {
            if (allow_defer) {
                Idle.add(() => {
                    apply_initial_toolbox_position(false);
                    return Source.REMOVE;
                });
            }
            return;
        }

        var target_top = (int) ((double) paned_height * (1.0 - DEFAULT_TOOLBOX_FRACTION));
        var min_top = content_paned.min_position;
        var max_top = content_paned.max_position;
        if (max_top < min_top) {
            max_top = min_top;
        }
        if (target_top < min_top) {
            target_top = min_top;
        } else if (target_top > max_top) {
            target_top = max_top;
        }
        content_paned.set_position(target_top);
    }

    private void apply_initial_ai_panel_position(bool allow_defer) {
        var split_width = ai_split.get_width();
        if (split_width <= 0) {
            if (allow_defer) {
                Idle.add(() => {
                    apply_initial_ai_panel_position(false);
                    return Source.REMOVE;
                });
            }
            return;
        }

        var desired_width = ai_panel_width_user_set && last_ai_panel_width > 0
            ? clamp_ai_panel_width(last_ai_panel_width)
            : default_ai_panel_width(split_width);
        var target_start = split_width - desired_width;
        var min_start = ai_split.min_position;
        var max_start = ai_split.max_position;
        if (max_start < min_start) {
            max_start = min_start;
        }
        if (target_start < min_start) {
            target_start = min_start;
        } else if (target_start > max_start) {
            target_start = max_start;
        }
        suppress_ai_position_persist = true;
        ai_split.set_position(target_start);
        Idle.add(() => {
            suppress_ai_position_persist = false;
            return Source.REMOVE;
        });
    }

    private int default_ai_panel_width(int split_width) {
        var width = (int) ((double) split_width * DEFAULT_AI_PANEL_FRACTION);
        return clamp_ai_panel_width(width);
    }

    private static int clamp_ai_panel_width(int width) {
        if (width < MIN_AI_PANEL_WIDTH) {
            return MIN_AI_PANEL_WIDTH;
        }
        if (width > MAX_AI_PANEL_WIDTH) {
            return MAX_AI_PANEL_WIDTH;
        }
        return width;
    }

    private void maybe_move_cursor_for_context_menu(Gtk.GestureClick click, int n_press, double x, double y) {
        var sequence = click.get_current_sequence();
        var event = click.get_last_event(sequence);
        if (n_press != 1 || event == null || !event.triggers_context_menu()) {
            return;
        }

        Gtk.TextIter selection_begin;
        Gtk.TextIter selection_end;
        if (editor_buffer.get_selection_bounds(out selection_begin, out selection_end)) {
            return;
        }

        int buffer_x;
        int buffer_y;
        editor_view.window_to_buffer_coords(
            Gtk.TextWindowType.WIDGET,
            (int) x,
            (int) y,
            out buffer_x,
            out buffer_y
        );

        Gtk.TextIter iter;
        if (!editor_view.get_iter_at_location(out iter, buffer_x, buffer_y)) {
            return;
        }

        editor_buffer.select_range(iter, iter);
    }

    private Gtk.Widget build_ui(GLib.ListModel search_model) {
        var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var header = new Adw.HeaderBar();
        title_label = new Gtk.Label("Editor");
        save_state_label = new Gtk.Label("");
        save_state_label.add_css_class("caption");
        save_state_label.add_css_class("dim-label");
        save_state_label.set_visible(false);
        var title_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        title_box.append(title_label);
        title_box.append(save_state_label);
        header.set_title_widget(title_box);

        var refresh_btn = new Gtk.Button.from_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Refresh projects and cards");
        refresh_btn.clicked.connect(() => {
            refresh_requested();
        });

        var new_project_btn = new Gtk.Button.from_icon_name("folder-new-symbolic");
        new_project_btn.set_tooltip_text("Create a new project");
        new_project_btn.clicked.connect(() => {
            new_project_requested();
        });

        var new_card_btn = new Gtk.Button.from_icon_name("list-add-symbolic");
        new_card_btn.set_tooltip_text("Create a new card");
        new_card_btn.clicked.connect(() => {
            new_card_requested();
        });

        explorer_toggle_btn = new Gtk.ToggleButton();
        explorer_toggle_btn.set_icon_name("sidebar-show-symbolic");
        explorer_toggle_btn.set_tooltip_text("Toggle explorer panel");
        explorer_toggle_btn.set_active(true);
        explorer_toggle_btn.toggled.connect(() => {
            explorer_panel_toggled(explorer_toggle_btn.get_active());
        });

        search_toggle_btn = new Gtk.ToggleButton();
        search_toggle_btn.set_icon_name("system-search-symbolic");
        search_toggle_btn.set_tooltip_text("Toggle search panel");
        search_toggle_btn.set_active(true);
        search_toggle_btn.toggled.connect(() => {
            if (search_row != null) {
                search_row.set_visible(search_toggle_btn.get_active());
            }
        });

        editor_toggle_btn = new Gtk.ToggleButton();
        editor_toggle_btn.set_icon_name("emblem-documents-symbolic");
        editor_toggle_btn.set_tooltip_text("Toggle card editor");
        editor_toggle_btn.set_active(true);
        editor_toggle_btn.toggled.connect(() => {
            if (content_stack != null) {
                content_stack.set_visible(editor_toggle_btn.get_active());
            }
        });

        var find_replace_btn = new Gtk.Button.from_icon_name("edit-find-replace-symbolic");
        find_replace_btn.set_tooltip_text("Find and replace");
        find_replace_btn.clicked.connect(() => {
            toggle_find_replace_bar(true);
        });

        var ai_toggle_btn = new Gtk.ToggleButton();
        ai_toggle_btn.set_icon_name("preferences-desktop-keyboard-symbolic");
        ai_toggle_btn.set_tooltip_text("Toggle AI panel");
        ai_toggle_btn.toggled.connect(() => {
            ai_panel_toggled(ai_toggle_btn.get_active());
        });

        toolbox_toggle_btn = new Gtk.ToggleButton();
        toolbox_toggle_btn.set_icon_name("applications-science-symbolic");
        toolbox_toggle_btn.set_tooltip_text("Toggle project toolbox panel");
        toolbox_toggle_btn.toggled.connect(() => {
            toolbox_toggled(toolbox_toggle_btn.get_active());
        });

        var main_menu = new GLib.Menu();
        var editing_section = new GLib.Menu();
        editing_section.append("Find/Replace", "win.find-replace");
        editing_section.append("Print", "win.print");
        var local_section = new GLib.Menu();
        local_section.append("Local info", "win.show-local-info");
        var app_section = new GLib.Menu();
        app_section.append("Preferences", "win.show-preferences");
        app_section.append("About", "win.show-about");
        main_menu.append_section(null, editing_section);
        main_menu.append_section(null, local_section);
        main_menu.append_section(null, app_section);

        var main_menu_btn = new Gtk.MenuButton();
        main_menu_btn.set_icon_name("open-menu-symbolic");
        main_menu_btn.set_tooltip_text("Main Menu");
        main_menu_btn.set_menu_model(main_menu);

        header.pack_start(refresh_btn);
        header.pack_end(main_menu_btn);
        header.pack_end(toolbox_toggle_btn);
        header.pack_end(ai_toggle_btn);
        header.pack_end(editor_toggle_btn);
        header.pack_end(find_replace_btn);
        header.pack_end(search_toggle_btn);
        header.pack_end(explorer_toggle_btn);
        header.pack_end(new_project_btn);
        header.pack_end(new_card_btn);
        outer.append(header);

        message_revealer = new Gtk.Revealer();
        message_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        message_revealer.set_reveal_child(false);

        var message_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        message_box.set_margin_top(6);
        message_box.set_margin_bottom(0);
        message_box.set_margin_start(8);
        message_box.set_margin_end(8);
        message_box.add_css_class("card");

        message_label = new Gtk.Label("") { xalign = 0.0f };
        message_label.set_wrap(true);
        message_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        message_label.set_hexpand(true);
        message_label.set_margin_top(10);
        message_label.set_margin_bottom(10);
        message_label.set_margin_start(12);
        message_label.set_margin_end(12);
        message_box.append(message_label);

        message_debug_button = new Gtk.Button.with_label("Open Debug Panel");
        message_debug_button.set_halign(Gtk.Align.END);
        message_debug_button.set_valign(Gtk.Align.CENTER);
        message_debug_button.set_margin_top(8);
        message_debug_button.set_margin_bottom(8);
        message_debug_button.set_margin_end(8);
        message_debug_button.set_visible(false);
        message_debug_button.clicked.connect(() => {
            open_debug_panel_requested();
        });
        message_box.append(message_debug_button);

        message_revealer.set_child(message_box);
        outer.append(message_revealer);

        search_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        search_row.set_margin_top(8);
        search_row.set_margin_bottom(8);
        search_row.set_margin_start(8);
        search_row.set_margin_end(8);
        search_row.set_visible(search_toggle_btn.get_active());

        search_entry = new Gtk.SearchEntry();
        search_entry.set_placeholder_text("Search cards in current project...");
        search_entry.set_hexpand(true);
        search_entry.activate.connect(() => {
            search_activated();
        });
        search_entry.search_changed.connect(() => {
            search_changed();
        });

        var search_key = new Gtk.EventControllerKey();
        search_key.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Down) {
                search_focus_results_requested();
                return true;
            }
            return false;
        });
        search_entry.add_controller(search_key);

        var clear_search_btn = new Gtk.Button.from_icon_name("edit-clear-symbolic");
        clear_search_btn.set_tooltip_text("Clear search");
        clear_search_btn.clicked.connect(() => {
            search_cleared();
        });

        search_row.append(search_entry);
        search_row.append(clear_search_btn);
        outer.append(search_row);

        find_revealer = build_find_replace_revealer();
        outer.append(find_revealer);

        editor_buffer = new GtkSource.Buffer(null);
        editor_buffer.set_highlight_syntax(true);
        editor_buffer.set_highlight_matching_brackets(true);
        Spelling.init();

        var lm = GtkSource.LanguageManager.get_default();
        var markdown = lm.get_language("markdown");
        if (markdown == null) {
            markdown = lm.guess_language("note.md", null);
        }
        if (markdown != null) {
            editor_buffer.set_language(markdown);
        }

        editor_view = new GtkSource.View.with_buffer(editor_buffer);
        editor_view.set_monospace(true);
        editor_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
        editor_view.set_show_line_numbers(true);
        editor_view.set_vexpand(true);
        editor_view.set_hexpand(true);

        var context_click = new Gtk.GestureClick();
        context_click.set_button(0);
        context_click.pressed.connect((n_press, x, y) => {
            maybe_move_cursor_for_context_menu(context_click, n_press, x, y);
        });
        editor_view.add_controller(context_click);

        var checker = Spelling.Checker.get_default();
        if (checker != null) {
            spelling_adapter = new Spelling.TextBufferAdapter(editor_buffer, checker);
            spelling_adapter.set_enabled(true);
            editor_view.insert_action_group("spelling", spelling_adapter);
            editor_view.set_extra_menu(spelling_adapter.get_menu_model());
        }

        var editor_scroll = new Gtk.ScrolledWindow();
        editor_scroll.set_child(editor_view);
        editor_scroll.set_vexpand(true);

        var search_page = build_search_page(search_model);

        content_stack = new Gtk.Stack();
        content_stack.set_vexpand(true);
        content_stack.set_hexpand(true);
        content_stack.add_named(editor_scroll, "editor");
        content_stack.add_named(search_page, "search");
        content_stack.set_visible_child_name("editor");

        toolbox = new ToolboxPane();

        content_paned = new Gtk.Paned(Gtk.Orientation.VERTICAL);
        content_paned.set_start_child(content_stack);
        content_paned.set_end_child(toolbox.widget);
        content_paned.set_resize_start_child(true);
        content_paned.set_resize_end_child(false);
        content_paned.set_shrink_start_child(false);
        content_paned.set_shrink_end_child(true);
        content_paned.set_wide_handle(true);
        content_paned.set_vexpand(true);
        content_paned.set_hexpand(true);
        toolbox.widget.set_visible(false);

        ai_panel = new AiPanel();
        ai_split = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        ai_split.set_start_child(content_paned);
        ai_split.set_end_child(ai_panel.widget);
        ai_split.set_resize_start_child(true);
        ai_split.set_resize_end_child(false);
        ai_split.set_shrink_start_child(false);
        ai_split.set_shrink_end_child(true);
        ai_split.set_wide_handle(true);
        ai_panel.widget.set_visible(false);
        ai_split.set_vexpand(true);
        ai_split.set_hexpand(true);
        ai_split.notify["position"].connect(() => {
            if (suppress_ai_position_persist || !ai_panel.widget.get_visible()) {
                return;
            }
            var split_width = ai_split.get_width();
            if (split_width <= 0) {
                return;
            }
            var panel_width = split_width - ai_split.get_position();
            if (panel_width <= 0) {
                return;
            }
            last_ai_panel_width = clamp_ai_panel_width(panel_width);
            ai_panel_width_user_set = true;
        });

        outer.append(ai_split);
        return outer;
    }

    private Gtk.Revealer build_find_replace_revealer() {
        var revealer = new Gtk.Revealer();
        revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN);
        revealer.set_reveal_child(false);

        var frame = new Gtk.Frame(null);
        frame.add_css_class("card");
        frame.set_margin_top(6);
        frame.set_margin_bottom(6);
        frame.set_margin_start(8);
        frame.set_margin_end(8);

        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        var find_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var find_label = new Gtk.Label("Find") { xalign = 0.0f };
        find_label.set_width_chars(8);
        find_entry = new Gtk.Entry();
        find_entry.set_hexpand(true);
        find_entry.set_placeholder_text("Search text");
        find_entry.update_property(Gtk.AccessibleProperty.LABEL, "Find text", -1);
        find_entry.activate.connect(() => {
            find_next_requested();
        });
        var find_next_btn = new Gtk.Button.with_label("Find Next");
        find_next_btn.clicked.connect(() => {
            find_next_requested();
        });
        var close_btn = new Gtk.Button.from_icon_name("window-close-symbolic");
        close_btn.set_tooltip_text("Close find and replace");
        close_btn.clicked.connect(() => {
            hide_find_replace_bar();
        });
        find_row.append(find_label);
        find_row.append(find_entry);
        find_row.append(find_next_btn);
        find_row.append(close_btn);

        replace_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var replace_label = new Gtk.Label("Replace") { xalign = 0.0f };
        replace_label.set_width_chars(8);
        replace_entry = new Gtk.Entry();
        replace_entry.set_hexpand(true);
        replace_entry.set_placeholder_text("Replacement text");
        replace_entry.update_property(Gtk.AccessibleProperty.LABEL, "Replacement text", -1);
        replace_entry.activate.connect(() => {
            replace_requested();
        });
        var replace_btn = new Gtk.Button.with_label("Replace");
        replace_btn.clicked.connect(() => {
            replace_requested();
        });
        var replace_all_btn = new Gtk.Button.with_label("Replace All");
        replace_all_btn.clicked.connect(() => {
            replace_all_requested();
        });
        replace_row.append(replace_label);
        replace_row.append(replace_entry);
        replace_row.append(replace_btn);
        replace_row.append(replace_all_btn);

        var key = new Gtk.EventControllerKey();
        key.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape) {
                hide_find_replace_bar();
                editor_view.grab_focus();
                return true;
            }
            return false;
        });
        find_entry.add_controller(key);
        var replace_key = new Gtk.EventControllerKey();
        replace_key.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape) {
                hide_find_replace_bar();
                editor_view.grab_focus();
                return true;
            }
            return false;
        });
        replace_entry.add_controller(replace_key);

        box.append(find_row);
        box.append(replace_row);
        frame.set_child(box);
        revealer.set_child(frame);
        return revealer;
    }

    private Gtk.Widget build_search_page(GLib.ListModel search_model) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(8);
        box.set_margin_end(8);

        search_summary_label = new Gtk.Label("Search results will appear here.") { xalign = 0.0f };
        search_summary_label.add_css_class("dim-label");
        box.append(search_summary_label);

        search_selection = new Gtk.SingleSelection(search_model);
        var search_factory = new Gtk.SignalListItemFactory();
        search_factory.setup.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var row = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            var title = new Gtk.Label("") { xalign = 0.0f };
            title.add_css_class("title-5");
            title.set_ellipsize(Pango.EllipsizeMode.END);
            var snippet = new Gtk.Label("") { xalign = 0.0f };
            snippet.add_css_class("dim-label");
            snippet.set_wrap(true);
            snippet.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            snippet.set_max_width_chars(80);
            row.append(title);
            row.append(snippet);
            list_item.set_child(row);
        });
        search_factory.bind.connect((item) => {
            var list_item = (Gtk.ListItem) item;
            var result = list_item.get_item() as SearchCardResult;
            var row = list_item.get_child() as Gtk.Box;
            var title = row.get_first_child() as Gtk.Label;
            var snippet = title.get_next_sibling() as Gtk.Label;
            if (result == null) {
                title.set_text("");
                snippet.set_text("");
                return;
            }
            title.set_text(result.title);
            snippet.set_text(result.snippet);
        });

        search_list = new Gtk.ListView(search_selection, search_factory);
        search_list.activate.connect((position) => {
            search_result_activated((uint) position);
        });

        var scroll = new Gtk.ScrolledWindow();
        scroll.set_vexpand(true);
        scroll.set_child(search_list);
        box.append(scroll);

        return box;
    }
}

}
