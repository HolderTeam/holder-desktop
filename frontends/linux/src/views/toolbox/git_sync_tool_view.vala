namespace HolderLinux {

public class GitSyncToolView : Object {
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

    public Gtk.Widget widget { get; private set; }

    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);

    public GitSyncToolView() {
        controller = new GitSyncController();
        widget = build_git_sync_tab();
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
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
                refresh_guided_repo_name_default();
                refresh_provider_setup_defaults();
            });
        }
        refresh_guided_repo_name_default();
        refresh_provider_setup_defaults();
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

        GitTestRemoteResult? test_result = null;
        GitPushResult? push_result = null;
        try {
            var apply_result = yield controller.configure_remote_and_sync(
                api,
                selected_project.project_id,
                remote_url,
                branch
            );
            test_result = apply_result.test_result;
            push_result = apply_result.push_result;
            if (test_result != null && test_result.status == "reachable" && status_label != null) {
                status_label.set_text("Remote reachable. Pushing project data...");
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
        var stored = controller.get_saved_github_username();
        git_guided_username_entry.set_text(stored);
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

        var create_result = yield controller.create_private_repo_and_verify(username, repo_name);
        var create_ok = create_result.created_ok;
        if (!create_result.exists) {
            var details = create_result.details.strip();
            if (details.length == 0) {
                details = "Repository could not be created.";
            }
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text("GitHub CLI setup failed: %s".printf(details));
            }
            error_reported("GitHub CLI setup failed", details);
            refresh_git_cli_controls();
            return;
        }

        var remote_url = "git@github.com:%s/%s.git".printf(username, repo_name);
        GitTestRemoteResult? test_result = null;
        GitPushResult? push_result = null;

        try {
            if (git_gh_cli_status_label != null) {
                git_gh_cli_status_label.set_text("Saving remote and testing connectivity...");
            }
            var apply_result = yield controller.configure_remote_and_sync(
                api,
                selected_project.project_id,
                remote_url,
                ""
            );
            test_result = apply_result.test_result;
            push_result = apply_result.push_result;
            if (test_result != null && test_result.status == "reachable") {
                if (git_gh_cli_status_label != null) {
                    git_gh_cli_status_label.set_text("Remote reachable. Pushing cards...");
                }
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

        var remote_url = controller.fill_remote_template(template_text, namespace_value, repo_value, host_value);
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

        var repo_check = yield controller.check_repository_exists_via_ssh(username, repo_name);
        var exists = repo_check.exists;

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

        var details = repo_check.error_text.length > 0 ? repo_check.error_text : "Repository not found.";
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
            var apply_result = yield controller.configure_remote_and_sync(
                api,
                selected_project.project_id,
                remote_url,
                ""
            );
            test_result = apply_result.test_result;
            push_result = apply_result.push_result;
            if (test_result != null && test_result.status == "reachable") {
                if (git_guided_push_status_label != null) {
                    git_guided_push_status_label.set_text("Remote reachable. Pushing project data...");
                }
            } else if (test_result != null) {
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

        var probe_plain = (yield controller.probe_github_ssh()).strip();
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

}

}
