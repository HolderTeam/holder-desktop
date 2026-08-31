namespace HolderLinux {

public class GitSyncToolView : Object, IToolShellAdapter {
    private const string WINDOWS_MONOSPACE_CLASS = "holder-windows-monospace";
    private static bool windows_monospace_css_installed = false;

    [CCode(cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    private static extern void gtk_style_context_add_provider_for_display(
        Gdk.Display display,
        Gtk.StyleProvider provider,
        uint priority
    );

    private IHolderApi? api;
    private GitSyncController controller;
    private Gtk.SingleSelection? project_selection;

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
    private Gtk.Stack git_start_state_stack;
    private Gtk.Button git_setup_cancel_btn;
    private Gtk.Label git_configured_project_label;
    private Gtk.Label git_configured_repository_label;
    private Gtk.Label git_configured_remote_label;
    private Gtk.Label git_configured_status_label;
    private Gtk.Label git_configured_detail_label;
    private Gtk.Button git_configured_sync_btn;
    private Gtk.Button git_configured_open_btn;
    private Gtk.Button git_configured_copy_btn;
    private Gtk.Button git_configured_change_btn;
    private Gtk.Button git_configured_disconnect_btn;
    private Project? git_configured_project;
    private string git_configured_web_url = "";
    private string git_locally_disconnected_project_id = "";
    private bool git_editing_remote = false;
    private uint git_state_refresh_generation = 0;
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
    private bool auto_check_github_cli;

    public Gtk.Widget widget { get; private set; }
    public string tool_id {
        owned get { return "git"; }
    }
    public string tool_label {
        owned get { return "Git Sync"; }
    }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? card_id,
                                          ActivityDetails? details);

    public GitSyncToolView(bool auto_check_github_cli = true) {
        this.auto_check_github_cli = auto_check_github_cli;
        controller = new GitSyncController();
        controller.activity_requested.connect((kind, message, project_id, card_id, details) => {
            activity_requested(kind, message, project_id, card_id, details);
        });
        widget = build_git_sync_tab();
    }

    public Gtk.Widget get_content_widget() {
        return widget;
    }

    public Gtk.Widget? get_actions_widget() {
        return null;
    }

    public ToolScopeSnapshot get_scope_snapshot(Project? selected_project, CardSummary? selected_card) {
        var project_id = selected_project != null ? selected_project.project_id : null;
        var project_label = selected_project != null ? selected_project.name : "(none)";
        var card_id = selected_card != null ? selected_card.card_id : null;
        var card_label = selected_card != null ? selected_card.title : "Overview";

        ToolScopeMode scope_mode = selected_card != null
            ? ToolScopeMode.CARD_FOCUS
            : ToolScopeMode.PROJECT_ROOT;
        if (project_id == null) {
            scope_mode = ToolScopeMode.PROJECTS_ROOT;
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
            scope_mode,
            false
        );
    }

    public async bool navigate_to_projects_root(string? selected_project_id) {
        if (git_sync_stack != null) {
            git_sync_stack.set_visible_child_name("start");
        }
        git_editing_remote = false;
        refresh_git_configured_state.begin();
        return true;
    }

    public async bool navigate_to_project_root(string project_id) {
        if (git_sync_stack != null) {
            git_sync_stack.set_visible_child_name("start");
        }
        git_editing_remote = false;
        refresh_git_configured_state.begin();
        return true;
    }

    public async bool navigate_to_card(string card_id) {
        if (git_sync_stack != null) {
            git_sync_stack.set_visible_child_name("start");
        }
        git_editing_remote = false;
        refresh_git_configured_state.begin();
        return true;
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        refresh_git_configured_state.begin();
    }

    public void set_settings(Settings? settings) {
        controller.set_settings(settings);
        refresh_guided_github_username();
        check_github_cli_state.begin();
    }

    public void set_project_selection(Gtk.SingleSelection? project_selection) {
        this.project_selection = project_selection;
        if (this.project_selection != null) {
            this.project_selection.notify["selected"].connect(() => {
                git_editing_remote = false;
                refresh_guided_repo_name_default();
                refresh_provider_setup_defaults();
                refresh_git_configured_state.begin();
            });
        }
        refresh_guided_repo_name_default();
        refresh_provider_setup_defaults();
        refresh_git_configured_state.begin();
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
        git_start_state_stack = new Gtk.Stack();
        git_start_state_stack.set_name("git-start-state-stack");
        git_start_state_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE);
        git_start_state_stack.add_named(build_git_sync_setup_page(), "setup");
        git_start_state_stack.add_named(build_git_sync_configured_page(), "configured");
        git_start_state_stack.set_visible_child_name("setup");
        return git_start_state_stack;
    }

    private Gtk.Widget build_git_sync_setup_page() {
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

        git_setup_cancel_btn = new Gtk.Button.with_label("Cancel changes");
        git_setup_cancel_btn.set_halign(Gtk.Align.START);
        git_setup_cancel_btn.set_visible(false);
        git_setup_cancel_btn.clicked.connect(() => {
            git_editing_remote = false;
            render_git_project_state(git_configured_project);
        });
        box.append(git_setup_cancel_btn);

        if (auto_check_github_cli) {
            check_github_cli_state.begin();
        }

        return box;
    }

    private Gtk.Widget build_git_sync_configured_page() {
        var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);

        var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        card.add_css_class("card");
        card.set_margin_top(4);
        card.set_margin_bottom(4);
        card.set_margin_start(4);
        card.set_margin_end(4);

        var title_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        title_row.set_margin_top(12);
        title_row.set_margin_start(12);
        title_row.set_margin_end(12);
        var configured_icon = new Gtk.Image.from_icon_name("emblem-ok-symbolic");
        configured_icon.set_name("git-configured-success-icon");
        configured_icon.add_css_class("success");
        configured_icon.set_tooltip_text("Git sync configured");
        title_row.append(configured_icon);
        var title = new Gtk.Label("Git sync configured") { xalign = 0.0f };
        title.add_css_class("title-4");
        title_row.append(title);
        card.append(title_row);

        var configured_summary = new Gtk.Label(
            "Your cards are safely stored in a remote repository, ready to sync to your other devices and share when you choose."
        ) { xalign = 0.0f };
        configured_summary.set_name("git-configured-summary");
        configured_summary.set_wrap(true);
        configured_summary.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        configured_summary.add_css_class("dim-label");
        configured_summary.set_margin_start(12);
        configured_summary.set_margin_end(12);
        card.append(configured_summary);

        git_configured_project_label = new Gtk.Label("") { xalign = 0.0f };
        git_configured_project_label.set_name("git-configured-project");
        git_configured_project_label.add_css_class("dim-label");
        git_configured_project_label.set_margin_start(12);
        git_configured_project_label.set_margin_end(12);
        card.append(git_configured_project_label);

        git_configured_repository_label = new Gtk.Label("") { xalign = 0.0f };
        git_configured_repository_label.set_name("git-configured-repository");
        git_configured_repository_label.add_css_class("heading");
        git_configured_repository_label.set_selectable(true);
        git_configured_repository_label.set_margin_start(12);
        git_configured_repository_label.set_margin_end(12);
        card.append(git_configured_repository_label);

        git_configured_remote_label = new Gtk.Label("") { xalign = 0.0f };
        git_configured_remote_label.set_name("git-configured-remote");
        git_configured_remote_label.set_selectable(true);
        git_configured_remote_label.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
        git_configured_remote_label.add_css_class("dim-label");
        git_configured_remote_label.set_margin_start(12);
        git_configured_remote_label.set_margin_end(12);
        card.append(git_configured_remote_label);

        var status_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        status_row.set_margin_top(4);
        status_row.set_margin_start(12);
        status_row.set_margin_end(12);
        git_configured_status_label = new Gtk.Label("") { xalign = 0.0f };
        git_configured_status_label.set_name("git-configured-status");
        git_configured_status_label.add_css_class("heading");
        status_row.append(git_configured_status_label);
        card.append(status_row);

        git_configured_detail_label = new Gtk.Label("") { xalign = 0.0f };
        git_configured_detail_label.set_name("git-configured-detail");
        git_configured_detail_label.set_wrap(true);
        git_configured_detail_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        git_configured_detail_label.add_css_class("dim-label");
        git_configured_detail_label.set_margin_start(12);
        git_configured_detail_label.set_margin_end(12);
        card.append(git_configured_detail_label);

        var actions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions.set_margin_top(6);
        actions.set_margin_bottom(12);
        actions.set_margin_start(12);
        actions.set_margin_end(12);

        git_configured_sync_btn = new Gtk.Button.with_label("Sync now");
        git_configured_sync_btn.add_css_class("suggested-action");
        git_configured_sync_btn.clicked.connect(() => sync_configured_project.begin());
        actions.append(git_configured_sync_btn);

        git_configured_open_btn = new Gtk.Button.with_label("Open repository");
        git_configured_open_btn.clicked.connect(open_configured_repository);
        actions.append(git_configured_open_btn);

        git_configured_copy_btn = new Gtk.Button.with_label("Copy URL");
        git_configured_copy_btn.clicked.connect(copy_configured_remote);
        actions.append(git_configured_copy_btn);

        git_configured_change_btn = new Gtk.Button.with_label("Change remote");
        git_configured_change_btn.clicked.connect(begin_change_remote);
        actions.append(git_configured_change_btn);

        git_configured_disconnect_btn = new Gtk.Button.with_label("Disconnect…");
        git_configured_disconnect_btn.add_css_class("destructive-action");
        git_configured_disconnect_btn.clicked.connect(confirm_disconnect_remote);
        actions.append(git_configured_disconnect_btn);
        card.append(actions);

        page.append(card);
        var note = new Gtk.Label(
            "Holder will keep this project synced in the background. Disconnecting Holder does not delete the remote repository."
        ) { xalign = 0.0f };
        note.set_wrap(true);
        note.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
        note.add_css_class("dim-label");
        page.append(note);
        return page;
    }

    private Project? selected_project() {
        return project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
    }

    private Project project_snapshot_with_remote(Project source, string? remote_url) {
        return new Project(
            source.project_id,
            source.name,
            source.privacy_mode,
            source.root_path,
            source.created_at,
            source.updated_at,
            remote_url,
            source.sync,
            source.card_count,
            source.root_card_count
        );
    }

    private async void refresh_git_configured_state(Project? optimistic_project = null) {
        var selected = selected_project();
        var generation = ++git_state_refresh_generation;
        if (selected == null) {
            render_git_project_state(null);
            return;
        }

        // Render the selection immediately, then replace it with the backend's current
        // immutable Project snapshot. This is especially important just after configuring
        // a remote, because the selection still contains the old git_remote_url.
        render_git_project_state(optimistic_project ?? selected);
        if (api == null) {
            return;
        }

        try {
            var projects = yield api.list_projects();
            if (generation != git_state_refresh_generation) {
                return;
            }
            var current = selected_project();
            if (current == null || current.project_id != selected.project_id) {
                return;
            }
            foreach (var project in projects) {
                if (project.project_id == selected.project_id) {
                    if (git_locally_disconnected_project_id == project.project_id &&
                        (project.git_remote_url == null || project.git_remote_url.strip().length == 0)) {
                        git_locally_disconnected_project_id = "";
                    }
                    render_git_project_state(project);
                    return;
                }
            }
        } catch (Error e) {
            // Keep the last known durable state visible. Other API error surfaces provide
            // diagnostics; losing the configured card here would recreate the original UX bug.
        }
    }

    private void render_git_project_state(Project? project) {
        if (git_start_state_stack == null) {
            return;
        }
        var remote_url = project != null && project.git_remote_url != null &&
                         project.project_id != git_locally_disconnected_project_id
            ? project.git_remote_url.strip()
            : "";
        if (git_editing_remote || project == null || remote_url.length == 0) {
            git_start_state_stack.set_visible_child_name("setup");
            if (git_setup_cancel_btn != null) {
                git_setup_cancel_btn.set_visible(git_editing_remote && git_configured_project != null);
            }
            return;
        }

        git_configured_project = project;
        var presentation = GitSyncPresenter.configured_state(
            project,
            new DateTime.now_utc().to_unix()
        );
        git_configured_web_url = presentation.web_url;
        git_configured_project_label.set_text("Project: %s".printf(project.name));
        git_configured_repository_label.set_text(presentation.repository_text);
        git_configured_remote_label.set_text(presentation.remote_url);
        git_configured_status_label.set_text(presentation.status_text);
        git_configured_status_label.remove_css_class("success");
        git_configured_status_label.remove_css_class("warning");
        git_configured_status_label.remove_css_class("error");
        git_configured_status_label.remove_css_class("accent");
        git_configured_status_label.add_css_class(presentation.status_class);
        git_configured_detail_label.set_text(presentation.detail_text);
        git_configured_open_btn.set_sensitive(git_configured_web_url.length > 0);
        git_setup_cancel_btn.set_visible(false);
        git_start_state_stack.set_visible_child_name("configured");
    }

    private async void sync_configured_project() {
        var project = git_configured_project;
        if (project == null || api == null) {
            toast_requested("Select a configured project first.");
            return;
        }
        git_configured_sync_btn.set_sensitive(false);
        git_configured_status_label.set_text("Syncing…");
        try {
            var result = yield api.push_project_git(project.project_id, "", true);
            if (result.status == "pushed") {
                toast_requested("Project synced.");
            } else if (result.status == "up_to_date") {
                toast_requested("Project is already up to date.");
            } else {
                var details = result.error_message.strip();
                if (details.length == 0) {
                    details = "Git sync returned: %s".printf(result.status);
                }
                error_reported("Git sync failed", details);
            }
            yield refresh_git_configured_state(project);
        } catch (Error e) {
            git_configured_status_label.set_text("Needs attention");
            error_reported("Git sync failed", e.message);
        }
        git_configured_sync_btn.set_sensitive(true);
    }

    private void open_configured_repository() {
        if (git_configured_web_url.length == 0) {
            return;
        }
        try {
            AppInfo.launch_default_for_uri(git_configured_web_url, null);
        } catch (Error e) {
            error_reported("Could not open repository", e.message);
        }
    }

    private void copy_configured_remote() {
        if (git_configured_project == null || git_configured_project.git_remote_url == null) {
            return;
        }
        var display = widget.get_display();
        if (display == null) {
            return;
        }
        display.get_clipboard().set_text(git_configured_project.git_remote_url);
        toast_requested("Repository URL copied.");
    }

    private void begin_change_remote() {
        var project = git_configured_project;
        if (project == null || project.git_remote_url == null) {
            return;
        }
        git_editing_remote = true;
        git_remote_entry.set_text(project.git_remote_url);
        git_branch_entry.set_text("");
        git_manual_status_label.set_text(
            "Changing this updates Holder's remote; it does not delete the existing repository."
        );
        render_git_project_state(project);
        git_remote_entry.grab_focus();
    }

    private void confirm_disconnect_remote() {
        var project = git_configured_project;
        var root_window = widget.get_root() as Gtk.Window;
        if (project == null || root_window == null) {
            return;
        }
        var dialog = new Adw.MessageDialog(
            root_window,
            "Disconnect Git sync?",
            "Holder will stop syncing “%s”. Your cards and the remote repository will not be deleted.".printf(
                project.name
            )
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("disconnect", "Disconnect");
        dialog.set_response_appearance("disconnect", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        dialog.set_close_response("cancel");
        dialog.response.connect((response) => {
            if (response == "disconnect") {
                disconnect_configured_remote.begin(project);
            }
            dialog.close();
        });
        dialog.present();
    }

    private async void disconnect_configured_remote(Project project) {
        if (api == null) {
            return;
        }
        git_configured_disconnect_btn.set_sensitive(false);
        try {
            yield api.set_project_git_remote(
                project.project_id,
                null,
                new DateTime.now_utc().to_unix()
            );
            git_state_refresh_generation++;
            git_locally_disconnected_project_id = project.project_id;
            git_configured_project = null;
            git_configured_web_url = "";
            git_editing_remote = false;
            git_remote_entry.set_text("");
            git_branch_entry.set_text("");
            git_manual_status_label.set_text("Git sync disconnected. The remote repository was not deleted.");
            git_start_state_stack.set_visible_child_name("setup");
            toast_requested("Git sync disconnected.");
        } catch (Error e) {
            error_reported("Could not disconnect Git sync", e.message);
        }
        git_configured_disconnect_btn.set_sensitive(true);
    }

    private async void run_manual_remote_setup() {
        var project = selected_project();
        var remote_url = git_remote_entry != null ? git_remote_entry.get_text().strip() : "";
        var branch = git_branch_entry != null ? git_branch_entry.get_text().strip() : "";
        var validation = controller.validate_remote_setup_inputs(project, api, remote_url);
        if (!validation.ok) {
            if (validation.is_toast) {
                toast_requested(validation.message);
            } else {
                error_reported(validation.error_title, validation.error_details);
            }
            return;
        }
        yield apply_project_git_remote_and_sync(
            (Project) project,
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

        try {
            var result = yield controller.apply_project_git_remote_and_sync(
                api,
                selected_project,
                remote_url,
                branch
            );
            if (status_label != null) {
                status_label.set_text(result.summary_text);
            }
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            git_locally_disconnected_project_id = "";
            git_editing_remote = false;
            git_sync_stack.set_visible_child_name("start");
            yield refresh_git_configured_state(project_snapshot_with_remote(selected_project, remote_url));
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
        var stored = controller.get_saved_github_username();
        git_guided_username_entry.set_text(stored);
        refresh_guided_next_button_state();
    }

    private void refresh_git_cli_controls() {
        var presentation = GitSyncPresenter.git_cli_controls(
            git_gh_available,
            git_gh_authenticated,
            git_gh_login
        );
        if (git_guided_repo_mode_label != null) {
            git_guided_repo_mode_label.set_text(presentation.repo_mode_text);
        }
        if (git_guided_repo_manual_label != null) {
            git_guided_repo_manual_label.set_text(presentation.repo_manual_label);
        }
        if (git_guided_repo_manual_instructions_label != null) {
            git_guided_repo_manual_instructions_label.set_markup(
                presentation.repo_manual_instructions_markup
            );
        }

        if (git_gh_cli_status_label != null) {
            git_gh_cli_status_label.set_text(presentation.cli_status_text);
        }
        if (git_gh_cli_auto_btn != null) {
            git_gh_cli_auto_btn.set_visible(presentation.cli_buttons_visible);
            git_gh_cli_auto_btn.set_sensitive(presentation.cli_buttons_sensitive);
        }
        if (git_gh_cli_guided_btn != null) {
            git_gh_cli_guided_btn.set_visible(presentation.cli_buttons_visible);
            git_gh_cli_guided_btn.set_sensitive(presentation.cli_buttons_sensitive);
        }
        if (git_guided_create_repo_cli_btn != null) {
            git_guided_create_repo_cli_btn.set_visible(presentation.cli_buttons_sensitive);
            git_guided_create_repo_cli_btn.set_sensitive(presentation.cli_buttons_sensitive);
        }
    }

    private async void check_github_cli_state() {
        var state = yield controller.detect_github_cli_state();
        git_gh_available = state.available;
        git_gh_authenticated = state.authenticated;
        git_gh_login = state.login;
        if (git_gh_login.length > 0) {
            controller.set_saved_github_username(git_gh_login);
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

        var create_result = yield controller.create_private_repo_and_verify(username, repo_name);
        var created_ok = create_result.created_ok;
        var exists = create_result.exists;

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

        var details = create_result.details.strip();
        if (details.length == 0) {
            details = "Repository could not be created.";
        }
        if (git_guided_repo_status_label != null) {
            git_guided_repo_status_label.set_text(details);
        }
        error_reported("GitHub CLI repository creation failed", details);
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
        var repo_name = controller.normalize_repository_name(selected_project.name ?? "");

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

        try {
            var flow_result = yield controller.run_github_cli_auto_sync_flow(
                api,
                selected_project,
                username
            );
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text(flow_result.status_text);
            }
            if (flow_result.error_title.strip().length > 0) {
                error_reported(flow_result.error_title, flow_result.error_details);
            } else if (flow_result.toast_message.strip().length > 0) {
                toast_requested(flow_result.toast_message);
            }
            if (flow_result.error_title.strip().length == 0) {
                git_locally_disconnected_project_id = "";
                git_editing_remote = false;
                git_sync_stack.set_visible_child_name("start");
                var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
                yield refresh_git_configured_state(
                    project_snapshot_with_remote(selected_project, remote_url)
                );
                return;
            }
        } catch (Error e) {
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text("GitHub CLI setup failed: %s".printf(e.message));
            }
            error_reported("Git sync failed", e.message);
            refresh_git_cli_controls();
            return;
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
        configure_monospace(git_guided_pubkey_view);
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
            git_provider_repo_entry.set_text(controller.normalize_repository_name(name));
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
        var preview = GitSyncPresenter.provider_remote_preview(
            provider,
            selected_provider_transport(),
            namespace_value,
            repo_value,
            host_value
        );
        if (git_provider_host_row != null) {
            git_provider_host_row.set_visible(preview.needs_host);
            if (preview.clear_host) {
                git_provider_host_entry.set_text("");
            }
        }
        git_provider_remote_entry.set_text(preview.remote_url);
        if (git_provider_template_label != null) {
            git_provider_template_label.set_text(preview.template_label);
        }
    }

    private async void run_provider_remote_setup() {
        var selected_project = project_selection != null
            ? project_selection.get_selected_item() as Project
            : null;
        var remote_url = git_provider_remote_entry != null ? git_provider_remote_entry.get_text().strip() : "";
        var branch = git_provider_branch_entry != null ? git_provider_branch_entry.get_text().strip() : "";
        var validation = controller.validate_remote_setup_inputs(selected_project, api, remote_url);
        if (!validation.ok) {
            if (validation.is_toast) {
                toast_requested(validation.message);
            } else {
                error_reported(validation.error_title, validation.error_details);
            }
            return;
        }
        yield apply_project_git_remote_and_sync(
            (Project) selected_project,
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
        return controller.get_saved_github_username();
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

        var verify_result = yield controller.verify_github_repository_exists_flow(username, repo_name);

        if (git_guided_repo_next_btn != null) {
            git_guided_repo_next_btn.set_sensitive(true);
        }

        if (verify_result.exists) {
            git_guided_repo_status_label.set_text(verify_result.status_text);
            git_guided_part4_username = username;
            git_guided_part4_repo_name = repo_name;
            if (git_guided_push_intro_label != null) {
                git_guided_push_intro_label.set_text(verify_result.push_intro_text);
            }
            if (git_guided_push_status_label != null) {
                git_guided_push_status_label.set_text("");
            }
            git_sync_stack.set_visible_child_name("guided-part4");
            return;
        }

        git_guided_repo_status_label.set_text(verify_result.status_text);
        error_reported(verify_result.error_title, verify_result.error_details);
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

        if (git_guided_push_btn != null) {
            git_guided_push_btn.set_sensitive(false);
        }
        if (git_guided_push_status_label != null) {
            git_guided_push_status_label.set_text("Saving remote and testing connectivity...");
        }

        try {
            var result = yield controller.run_github_guided_sync_flow(
                api,
                selected_project,
                username,
                repo_name
            );
            if (git_guided_push_status_label != null) {
                git_guided_push_status_label.set_text(result.status_text);
            }
            if (result.toast_message.strip().length > 0) {
                toast_requested(result.toast_message);
            }
            git_locally_disconnected_project_id = "";
            git_editing_remote = false;
            git_sync_stack.set_visible_child_name("start");
            var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
            yield refresh_git_configured_state(
                project_snapshot_with_remote(selected_project, remote_url)
            );
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
    }

    private void set_guided_key_ui_visibility(bool has_key) {
        var presentation = GitSyncPresenter.guided_ssh_key_ui(
            has_key,
            git_guided_github_authenticated,
            git_guided_public_key
        );
        if (git_guided_missing_key_box != null) {
            git_guided_missing_key_box.set_visible(presentation.missing_key_visible);
        }
        if (git_guided_key_ready_box != null) {
            git_guided_key_ready_box.set_visible(presentation.key_ready_visible);
        }
        if (git_guided_copy_key_btn != null) {
            git_guided_copy_key_btn.set_sensitive(presentation.copy_key_sensitive);
        }
        if (git_guided_open_keys_btn != null) {
            git_guided_open_keys_btn.set_visible(presentation.open_keys_visible);
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

        var probe_result = GitSyncPresenter.guided_ssh_probe_status(
            yield controller.probe_github_ssh()
        );
        git_guided_github_authenticated = probe_result.authenticated;
        set_guided_key_ui_visibility(true);
        git_guided_ssh_status_label.set_text(probe_result.status_text);
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
        var keygen_result = yield controller.generate_ssh_key(email, key_path);
        git_guided_generate_key_btn.set_sensitive(true);

        if (!FileUtils.test("%s.pub".printf(key_path), FileTest.EXISTS)) {
            error_reported("SSH key generation failed",
                           keygen_result.output.strip().length > 0
                               ? keygen_result.output.strip()
                               : "ssh-keygen did not create a public key.");
            return;
        }

        toast_requested("SSH key generated.");
        check_guided_ssh_state.begin();
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
        if (git_guided_username_entry == null) {
            return;
        }
        var username = git_guided_username_entry.get_text().strip();
        controller.set_saved_github_username(username);
    }

    private void refresh_guided_next_button_state() {
        if (git_guided_next_btn == null || git_guided_username_entry == null) {
            return;
        }
        git_guided_next_btn.set_sensitive(git_guided_username_entry.get_text().strip().length > 0);
    }

    private static void configure_monospace(Gtk.TextView view) {
        if (Path.DIR_SEPARATOR_S != "\\") {
            view.set_monospace(true);
            return;
        }

        ensure_windows_monospace_css();
        view.add_css_class(WINDOWS_MONOSPACE_CLASS);
    }

    private static void ensure_windows_monospace_css() {
        if (windows_monospace_css_installed) {
            return;
        }
        var display = Gdk.Display.get_default();
        if (display == null) {
            return;
        }

        var provider = new Gtk.CssProvider();
        provider.load_from_string("""
.holder-windows-monospace,
.holder-windows-monospace text {
  font-family: "Cascadia Mono", "Consolas", monospace;
}
""");
        gtk_style_context_add_provider_for_display(
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        windows_monospace_css_installed = true;
    }

}

}
