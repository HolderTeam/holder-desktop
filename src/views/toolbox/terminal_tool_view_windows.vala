namespace HolderLinux {

private class TerminalSessionListRow : Gtk.ListBoxRow {
    public TerminalSession session { get; construct; }
    private Gtk.Label state_label;

    public TerminalSessionListRow(TerminalSession session) {
        Object(session: session);

        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        box.set_margin_top(8);
        box.set_margin_bottom(8);
        box.set_margin_start(10);
        box.set_margin_end(10);

        var title = new Gtk.Label(session.card_label ?? session.project_label);
        title.set_xalign(0.0f);
        title.set_ellipsize(Pango.EllipsizeMode.END);
        box.append(title);

        state_label = new Gtk.Label("");
        state_label.set_xalign(0.0f);
        state_label.add_css_class("dim-label");
        state_label.add_css_class("caption");
        box.append(state_label);

        set_child(box);
        refresh_state();
    }

    public void refresh_state() {
        var created = new DateTime.from_unix_local(session.created_at);
        state_label.set_text("%s · %s".printf(
            state_text(session.state),
            created.format("%d %b %H:%M")
        ));
    }

    private static string state_text(TerminalSessionState state) {
        switch (state) {
        case TerminalSessionState.ACTIVE:
            return "Recording";
        case TerminalSessionState.COMPLETED:
            return "Completed";
        default:
            return "Interrupted";
        }
    }
}

public class TerminalToolView : Object, IToolShellAdapter {
    private Gtk.Box actions_bar;
    private Gtk.Button new_terminal_button;
    private Gtk.Stack content_stack;
    private Gtk.Spinner checking_spinner;
    private Gtk.Label prerequisite_title;
    private Gtk.Label prerequisite_detail;
    private Gtk.Button install_button;
    private Gtk.Button check_again_button;
    private Gtk.LinkButton manual_install_link;
    private Gtk.ListBox session_list;
    private Gtk.Label empty_sessions_label;
    private Gtk.TextView transcript_view;
    private Gtk.Label transcript_title;
    private Gtk.Label transcript_state;
    private Gtk.Revealer interrupted_revealer;
    private Gtk.ToggleButton raw_toggle;
    private Gtk.Button copy_selection_button;
    private Gtk.Button copy_all_button;

    private PowerShellDiscoveryService discovery;
    private TerminalSessionStore session_store;
    private WindowsTerminalLauncher launcher;
    private PowerShellPrerequisites? prerequisites;
    private PowerShellTranscriptSnapshot? transcript_snapshot;
    private TerminalSession? active_session;
    private TerminalSessionListRow? active_row;
    private Gtk.SingleSelection? project_selection;
    private Gtk.SingleSelection? card_selection;
    private FileMonitor? transcript_monitor;
    private uint transcript_refresh_source = 0;
    private uint install_poll_source = 0;
    private int install_poll_count = 0;
    private bool discovery_in_progress = false;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "terminals"; }
    }
    public string tool_label {
        owned get { return "Terminals"; }
    }

    public signal void debug_log_requested(string line);
    public signal void toast_requested(string message);
    public signal void copy_to_card_requested(string text);

    public TerminalToolView() {
        discovery = new PowerShellDiscoveryService();
        session_store = new TerminalSessionStore();
        launcher = new WindowsTerminalLauncher();
        widget = build_ui();
        refresh_prerequisites.begin();
    }

    ~TerminalToolView() {
        cancel_transcript_monitor();
        if (install_poll_source != 0) {
            Source.remove(install_poll_source);
            install_poll_source = 0;
        }
    }

    public Gtk.Widget? get_actions_widget() {
        return actions_bar;
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project,
                                                 CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";
        var mode = selected_card != null
            ? ToolScopeMode.CARD_FOCUS
            : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            mode = ToolScopeMode.PROJECTS_ROOT;
            project_label = "Projects";
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
            mode,
            discovery_in_progress
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        return true;
    }

    public void bind_context(Gtk.SingleSelection project_selection,
                             Gtk.SingleSelection card_selection) {
        this.project_selection = project_selection;
        this.card_selection = card_selection;
        project_selection.notify["selected"].connect(() => {
            load_project_sessions();
        });
        load_project_sessions();
    }

    private Gtk.Widget build_ui() {
        actions_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions_bar.set_hexpand(true);
        new_terminal_button = new Gtk.Button.from_icon_name("list-add-symbolic");
        new_terminal_button.set_tooltip_text("Open a new Holder terminal");
        new_terminal_button.add_css_class("flat");
        new_terminal_button.set_sensitive(false);
        new_terminal_button.clicked.connect(open_new_terminal);
        actions_bar.append(new_terminal_button);

        content_stack = new Gtk.Stack();
        content_stack.set_vexpand(true);
        content_stack.set_hexpand(true);
        content_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE);
        content_stack.add_named(build_checking_page(), "checking");
        content_stack.add_named(build_prerequisite_page(), "prerequisite");
        content_stack.add_named(build_sessions_page(), "sessions");
        content_stack.set_visible_child_name("checking");
        return content_stack;
    }

    private Gtk.Widget build_checking_page() {
        var box = centered_box();
        checking_spinner = new Gtk.Spinner();
        checking_spinner.start();
        box.append(checking_spinner);
        var label = new Gtk.Label("Checking Windows terminal support…");
        label.add_css_class("dim-label");
        box.append(label);
        return box;
    }

    private Gtk.Widget build_prerequisite_page() {
        var box = centered_box();
        var icon = new Gtk.Image.from_icon_name("utilities-terminal-symbolic");
        icon.set_pixel_size(48);
        box.append(icon);

        prerequisite_title = new Gtk.Label("PowerShell 7 is required");
        prerequisite_title.add_css_class("title-3");
        box.append(prerequisite_title);

        prerequisite_detail = new Gtk.Label("");
        prerequisite_detail.set_wrap(true);
        prerequisite_detail.set_justify(Gtk.Justification.CENTER);
        prerequisite_detail.set_max_width_chars(62);
        prerequisite_detail.add_css_class("dim-label");
        box.append(prerequisite_detail);

        var buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        buttons.set_halign(Gtk.Align.CENTER);
        install_button = new Gtk.Button.with_label("Install PowerShell 7");
        install_button.add_css_class("suggested-action");
        install_button.clicked.connect(confirm_install);
        buttons.append(install_button);
        check_again_button = new Gtk.Button.with_label("Check Again");
        check_again_button.clicked.connect(() => refresh_prerequisites.begin());
        buttons.append(check_again_button);
        box.append(buttons);

        manual_install_link = new Gtk.LinkButton.with_label(
            "https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows",
            "Install manually from Microsoft"
        );
        box.append(manual_install_link);
        return box;
    }

    private Gtk.Widget build_sessions_page() {
        var paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
        paned.set_wide_handle(true);
        paned.set_position(260);

        var sessions_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        sessions_box.set_size_request(220, -1);
        var sessions_heading = new Gtk.Label("Project terminal sessions");
        sessions_heading.set_xalign(0.0f);
        sessions_heading.add_css_class("heading");
        sessions_heading.set_margin_start(8);
        sessions_heading.set_margin_top(8);
        sessions_box.append(sessions_heading);

        session_list = new Gtk.ListBox();
        session_list.set_selection_mode(Gtk.SelectionMode.SINGLE);
        session_list.add_css_class("boxed-list");
        session_list.row_selected.connect((row) => {
            set_active_row(row as TerminalSessionListRow);
        });
        var list_scroller = new Gtk.ScrolledWindow();
        list_scroller.set_vexpand(true);
        list_scroller.set_child(session_list);
        sessions_box.append(list_scroller);

        empty_sessions_label = new Gtk.Label("Select a project, then open a terminal.");
        empty_sessions_label.set_wrap(true);
        empty_sessions_label.add_css_class("dim-label");
        empty_sessions_label.set_margin_start(8);
        empty_sessions_label.set_margin_end(8);
        empty_sessions_label.set_margin_bottom(8);
        sessions_box.append(empty_sessions_label);
        paned.set_start_child(sessions_box);

        var transcript_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        transcript_box.set_margin_start(8);
        transcript_box.set_margin_end(8);
        transcript_box.set_margin_top(8);
        transcript_box.set_margin_bottom(8);

        var heading_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        transcript_title = new Gtk.Label("No terminal selected");
        transcript_title.set_xalign(0.0f);
        transcript_title.set_hexpand(true);
        transcript_title.add_css_class("heading");
        heading_row.append(transcript_title);
        transcript_state = new Gtk.Label("");
        transcript_state.add_css_class("dim-label");
        heading_row.append(transcript_state);
        raw_toggle = new Gtk.ToggleButton.with_label("Raw");
        raw_toggle.set_tooltip_text("Show the untrimmed PowerShell transcript");
        raw_toggle.toggled.connect(render_transcript);
        heading_row.append(raw_toggle);
        transcript_box.append(heading_row);

        interrupted_revealer = new Gtk.Revealer();
        var interrupted = new Gtk.Label(
            "Session ended unexpectedly. The final command's output may be incomplete."
        );
        interrupted.set_wrap(true);
        interrupted.set_xalign(0.0f);
        interrupted.add_css_class("warning");
        interrupted.set_margin_top(4);
        interrupted.set_margin_bottom(4);
        interrupted_revealer.set_child(interrupted);
        transcript_box.append(interrupted_revealer);

        transcript_view = new Gtk.TextView();
        transcript_view.set_editable(false);
        transcript_view.set_cursor_visible(true);
        transcript_view.set_monospace(true);
        transcript_view.set_wrap_mode(Gtk.WrapMode.NONE);
        transcript_view.set_left_margin(8);
        transcript_view.set_right_margin(8);
        transcript_view.set_top_margin(8);
        transcript_view.set_bottom_margin(8);
        var transcript_scroller = new Gtk.ScrolledWindow();
        transcript_scroller.set_vexpand(true);
        transcript_scroller.set_hexpand(true);
        transcript_scroller.set_child(transcript_view);
        transcript_box.append(transcript_scroller);

        var copy_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        copy_row.set_halign(Gtk.Align.END);
        copy_selection_button = new Gtk.Button.with_label("Copy Selection to Card");
        copy_selection_button.set_sensitive(false);
        copy_selection_button.clicked.connect(copy_selection_to_card);
        copy_row.append(copy_selection_button);
        copy_all_button = new Gtk.Button.with_label("Copy All to Card");
        copy_all_button.set_sensitive(false);
        copy_all_button.add_css_class("suggested-action");
        copy_all_button.clicked.connect(copy_all_to_card);
        copy_row.append(copy_all_button);
        transcript_box.append(copy_row);
        paned.set_end_child(transcript_box);
        return paned;
    }

    private static Gtk.Box centered_box() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        box.set_halign(Gtk.Align.CENTER);
        box.set_valign(Gtk.Align.CENTER);
        box.set_margin_top(24);
        box.set_margin_bottom(24);
        box.set_margin_start(24);
        box.set_margin_end(24);
        return box;
    }

    private async void refresh_prerequisites() {
        if (discovery_in_progress) {
            return;
        }
        discovery_in_progress = true;
        if (prerequisites == null) {
            content_stack.set_visible_child_name("checking");
        }
        prerequisites = yield discovery.discover();
        discovery_in_progress = false;
        render_prerequisites();
    }

    private void render_prerequisites() {
        var current = prerequisites;
        if (current == null) {
            return;
        }
        if (((!) current).ready) {
            content_stack.set_visible_child_name("sessions");
            stop_install_polling();
            load_project_sessions();
            return;
        }

        content_stack.set_visible_child_name("prerequisite");
        install_button.set_visible(false);
        install_button.set_sensitive(false);
        manual_install_link.set_visible(false);
        switch (((!) current).status) {
        case PowerShellPrerequisiteStatus.POWERSHELL_MISSING:
            prerequisite_title.set_text("PowerShell 7 is required");
            prerequisite_detail.set_text(
                power_shell_install_detail((!) current)
            );
            configure_install_button((!) current);
            manual_install_link.set_visible(true);
            break;
        case PowerShellPrerequisiteStatus.POWERSHELL_UNSUPPORTED:
            prerequisite_title.set_text("A newer PowerShell is required");
            prerequisite_detail.set_text(
                "Holder found PowerShell %s, but PowerShell 7 or newer is required. %s"
                    .printf(
                        ((!) current).powershell_version ?? "",
                        power_shell_install_detail((!) current)
                    )
            );
            configure_install_button((!) current);
            manual_install_link.set_visible(true);
            break;
        case PowerShellPrerequisiteStatus.WINDOWS_TERMINAL_MISSING:
            prerequisite_title.set_text("Windows Terminal is required");
            prerequisite_detail.set_text(
                "PowerShell 7 is ready, but Holder could not find Windows Terminal (wt.exe)."
            );
            break;
        default:
            prerequisite_title.set_text("Could not check PowerShell 7");
            prerequisite_detail.set_text(
                ((!) current).details.length > 0
                    ? ((!) current).details
                    : "Holder could not verify the PowerShell installation."
            );
            manual_install_link.set_visible(true);
            break;
        }
    }

    private void configure_install_button(PowerShellPrerequisites current) {
        var automatic_install_available = current.winget_path != null
                                           && current.windows_terminal_path != null;
        install_button.set_visible(automatic_install_available);
        install_button.set_sensitive(automatic_install_available);
    }

    private static string power_shell_install_detail(PowerShellPrerequisites current) {
        const string PURPOSE =
            "Holder uses PowerShell 7 to preserve useful terminal commands and output in your cards.";
        if (current.winget_path == null && current.windows_terminal_path == null) {
            return "%s Automatic installation is unavailable because Holder could not find Windows Terminal or WinGet; use the Microsoft link below."
                .printf(PURPOSE);
        }
        if (current.windows_terminal_path == null) {
            return "%s Automatic installation is unavailable because Holder could not find Windows Terminal; use the Microsoft link below."
                .printf(PURPOSE);
        }
        if (current.winget_path == null) {
            return "%s Automatic installation is unavailable because Holder could not find WinGet; use the Microsoft link below."
                .printf(PURPOSE);
        }
        return PURPOSE;
    }

    private void confirm_install() {
        var current = prerequisites;
        var parent = widget.get_root() as Gtk.Window;
        if (current == null || parent == null) {
            return;
        }
        var dialog = new Adw.MessageDialog(
            parent,
            "Install PowerShell 7?",
            "Holder will open Windows Terminal and ask WinGet to install Microsoft's official PowerShell package."
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("install", "Install");
        dialog.set_response_appearance("install", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("install");
        dialog.set_close_response("cancel");
        dialog.response.connect((response) => {
            if (response == "install") {
                try {
                    launcher.launch_install((!) current);
                    toast_requested("PowerShell installer opened. Holder will detect it when installation finishes.");
                    start_install_polling();
                } catch (Error e) {
                    debug_log_requested("PowerShell installer launch failed: %s".printf(e.message));
                    toast_requested("Could not open the PowerShell installer.");
                }
            }
            dialog.close();
        });
        dialog.present();
    }

    private void start_install_polling() {
        stop_install_polling();
        install_poll_count = 0;
        install_poll_source = Timeout.add_seconds(3, () => {
            install_poll_count++;
            refresh_prerequisites.begin();
            if (install_poll_count >= 40) {
                install_poll_source = 0;
                return Source.REMOVE;
            }
            return Source.CONTINUE;
        });
    }

    private void stop_install_polling() {
        if (install_poll_source != 0) {
            Source.remove(install_poll_source);
            install_poll_source = 0;
        }
    }

    private void open_new_terminal() {
        var current = prerequisites;
        var project = selected_project();
        if (current == null || !((!) current).ready) {
            toast_requested("PowerShell 7 is not ready yet.");
            return;
        }
        if (project == null) {
            toast_requested("Select a project first.");
            return;
        }
        var card = selected_card();
        try {
            var session = session_store.create_session(
                project.project_id,
                project.name,
                card != null ? card.card_id : null,
                card != null ? card.title : null,
                project.root_path
            );
            launcher.launch_session((!) current, session);
            append_session_row(session, true);
            toast_requested("Holder terminal opened in Windows Terminal.");
            debug_log_requested("Windows terminal session opened: %s".printf(session.session_id));
        } catch (Error e) {
            debug_log_requested("Windows terminal launch failed: %s".printf(e.message));
            toast_requested("Could not open Windows Terminal.");
        }
    }

    private Project? selected_project() {
        return project_selection != null
            ? ((!) project_selection).get_selected_item() as Project
            : null;
    }

    private CardSummary? selected_card() {
        return card_selection != null
            ? ((!) card_selection).get_selected_item() as CardSummary
            : null;
    }

    private void load_project_sessions() {
        clear_session_rows();
        var project = selected_project();
        new_terminal_button.set_sensitive(
            project != null && prerequisites != null && ((!) prerequisites).ready
        );
        if (project == null) {
            empty_sessions_label.set_text("Select a project, then open a terminal.");
            empty_sessions_label.set_visible(true);
            set_active_row(null);
            return;
        }
        try {
            var sessions = session_store.load_sessions(project.project_id);
            foreach (var session in sessions) {
                append_session_row(session, false);
            }
            empty_sessions_label.set_text("No terminal sessions for this project yet.");
            empty_sessions_label.set_visible(sessions.size == 0);
            if (sessions.size == 0) {
                set_active_row(null);
            } else {
                session_list.select_row(session_list.get_row_at_index(0));
            }
        } catch (Error e) {
            empty_sessions_label.set_text("Could not load terminal sessions.");
            empty_sessions_label.set_visible(true);
            debug_log_requested("Terminal session load failed: %s".printf(e.message));
        }
    }

    private void clear_session_rows() {
        while (session_list.get_first_child() != null) {
            session_list.remove((!) session_list.get_first_child());
        }
    }

    private void append_session_row(TerminalSession session, bool select) {
        var row = new TerminalSessionListRow(session);
        session_list.append(row);
        empty_sessions_label.set_visible(false);
        if (select) {
            session_list.select_row(row);
        }
    }

    private void set_active_row(TerminalSessionListRow? row) {
        cancel_transcript_monitor();
        active_row = row;
        active_session = row != null ? row.session : null;
        transcript_snapshot = null;
        raw_toggle.set_active(false);
        if (active_session == null) {
            transcript_title.set_text("No terminal selected");
            transcript_state.set_text("");
            interrupted_revealer.set_reveal_child(false);
            transcript_view.get_buffer().set_text("");
            copy_selection_button.set_sensitive(false);
            copy_all_button.set_sensitive(false);
            return;
        }
        transcript_title.set_text(
            ((!) active_session).card_label ?? ((!) active_session).project_label
        );
        refresh_active_transcript();
        start_transcript_monitor((!) active_session);
    }

    private void start_transcript_monitor(TerminalSession session) {
        try {
            var directory = File.new_for_path(Path.get_dirname(session.transcript_path));
            transcript_monitor = directory.monitor_directory(FileMonitorFlags.WATCH_MOVES, null);
            ((!) transcript_monitor).changed.connect((file, other_file, event_type) => {
                var changed_path = file.get_path();
                if (changed_path == session.transcript_path) {
                    queue_transcript_refresh();
                }
            });
        } catch (Error e) {
            debug_log_requested("Terminal transcript monitor failed: %s".printf(e.message));
        }
    }

    private void cancel_transcript_monitor() {
        if (transcript_monitor != null) {
            ((!) transcript_monitor).cancel();
            transcript_monitor = null;
        }
        if (transcript_refresh_source != 0) {
            Source.remove(transcript_refresh_source);
            transcript_refresh_source = 0;
        }
    }

    private void queue_transcript_refresh() {
        if (transcript_refresh_source != 0) {
            return;
        }
        transcript_refresh_source = Timeout.add(100, () => {
            transcript_refresh_source = 0;
            refresh_active_transcript();
            return Source.REMOVE;
        });
    }

    private void refresh_active_transcript() {
        var session = active_session;
        if (session == null) {
            return;
        }
        try {
            transcript_snapshot = session_store.read_transcript((!) session);
            if (((!) transcript_snapshot).completed) {
                ((!) session).state = TerminalSessionState.COMPLETED;
            }
            if (active_row != null) {
                ((!) active_row).refresh_state();
            }
            render_transcript();
        } catch (Error e) {
            debug_log_requested("Terminal transcript read failed: %s".printf(e.message));
            transcript_state.set_text("Could not read transcript");
        }
    }

    private void render_transcript() {
        var session = active_session;
        var snapshot = transcript_snapshot;
        if (session == null || snapshot == null) {
            return;
        }
        var text = raw_toggle.get_active()
            ? ((!) snapshot).raw_text
            : ((!) snapshot).useful_text;
        transcript_view.get_buffer().set_text(text);
        switch (((!) session).state) {
        case TerminalSessionState.ACTIVE:
            transcript_state.set_text("Recording");
            break;
        case TerminalSessionState.COMPLETED:
            transcript_state.set_text("Completed");
            break;
        default:
            transcript_state.set_text("Interrupted");
            break;
        }
        interrupted_revealer.set_reveal_child(
            ((!) session).state == TerminalSessionState.INTERRUPTED
        );
        copy_selection_button.set_sensitive(text.strip().length > 0);
        copy_all_button.set_sensitive(text.strip().length > 0);
    }

    private void copy_selection_to_card() {
        Gtk.TextIter start;
        Gtk.TextIter end;
        var buffer = transcript_view.get_buffer();
        if (!buffer.get_selection_bounds(out start, out end)) {
            toast_requested("Select terminal text first.");
            return;
        }
        var text = buffer.get_text(start, end, false);
        if (text.strip().length == 0) {
            toast_requested("Select terminal text first.");
            return;
        }
        copy_to_card_requested(text);
    }

    private void copy_all_to_card() {
        var snapshot = transcript_snapshot;
        if (snapshot == null) {
            toast_requested("Terminal has no text to copy.");
            return;
        }
        var text = raw_toggle.get_active()
            ? ((!) snapshot).raw_text
            : ((!) snapshot).useful_text;
        if (text.strip().length == 0) {
            toast_requested("Terminal has no text to copy.");
            return;
        }
        copy_to_card_requested(text);
    }
}

}
