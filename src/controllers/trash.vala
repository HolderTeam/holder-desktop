namespace HolderLinux {

public class TrashConfirmDialogSpec : Object {
    public string title { get; construct; }
    public string body { get; construct; }
    public string confirm_response_id { get; construct; }
    public string confirm_label { get; construct; }
    public string cancel_response_id { get; construct; }
    public string cancel_label { get; construct; }

    public TrashConfirmDialogSpec(string title,
                                  string body,
                                  string confirm_response_id,
                                  string confirm_label,
                                  string cancel_response_id = "cancel",
                                  string cancel_label = "Cancel") {
        Object(
            title: title,
            body: body,
            confirm_response_id: confirm_response_id,
            confirm_label: confirm_label,
            cancel_response_id: cancel_response_id,
            cancel_label: cancel_label
        );
    }
}

public class TrashController : Object {
    public const string ACTIVITY_KIND_RESTORED = "result.trash.restore";

    public static bool is_restored_activity(string kind) {
        return kind == ACTIVITY_KIND_RESTORED;
    }

    private IHolderApi? api;
    private Gtk.SingleSelection? project_selection;
    private uint refresh_serial = 0;
    private uint filter_index = 0;
    private ulong project_selection_handler_id = 0;
    // The project the items in the store were listed for. It is what a restore or delete belongs to:
    // the selection may already have moved on while the next project's list is still loading.
    private string? committed_project_id = null;

    public GLib.ListStore items_store { get; private set; }
    public string scope_text { get; private set; default = "Projects / (none) / Trash"; }
    public string empty_text { get; private set; default = "No deleted items in this project."; }
    public bool empty_visible { get; private set; default = false; }
    public bool empty_trash_sensitive { get; private set; default = false; }

    public signal void state_changed();
    public signal void error_reported(string title, string details);
    public signal void toast_requested(string message);
    public signal void activity_requested(string kind,
                                          string message,
                                          string? project_id,
                                          string? card_id,
                                          ActivityDetails? details);

    public TrashController() {
        items_store = new GLib.ListStore(typeof(TrashItem));
    }

    public void set_api_client(IHolderApi? api) {
        this.api = api;
        queue_refresh();
    }

    public void set_project_selection(Gtk.SingleSelection? project_selection) {
        if (this.project_selection != null && project_selection_handler_id != 0) {
            this.project_selection.disconnect(project_selection_handler_id);
        }
        project_selection_handler_id = 0;
        this.project_selection = project_selection;
        if (this.project_selection != null) {
            project_selection_handler_id = this.project_selection.notify["selected"].connect(() => {
                queue_refresh();
            });
        }
        queue_refresh();
    }

    public Project? selected_project() {
        if (project_selection == null) {
            return null;
        }
        return project_selection.get_selected_item() as Project;
    }

    public void set_filter_index(uint idx) {
        filter_index = idx;
        queue_refresh();
    }

    public void queue_refresh() {
        refresh_serial++;
        refresh.begin(refresh_serial);
    }

    public async void refresh(uint serial) {
        if (serial != refresh_serial) {
            return;
        }

        var project = selected_project();
        if (project == null) {
            if (serial != refresh_serial) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: stale no-project guard already covered behaviorally
            }
            scope_text = "Projects / (none) / Trash";
            empty_text = "Select a project to view trash.";
            clear_store();
            empty_visible = true;
            empty_trash_sensitive = false;
            committed_project_id = null;
            state_changed();
            return;
        }

        if (api == null) {
            if (serial != refresh_serial) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: stale no-api guard already covered behaviorally
            }
            scope_text = "Projects / %s / Trash".printf(project.name);
            empty_text = "API unavailable.";
            clear_store();
            empty_visible = true;
            empty_trash_sensitive = false;
            committed_project_id = null;
            state_changed();
            return;
        }

        try {
            var items = yield api.list_trash_items(project.project_id, selected_filter_type());
            if (serial != refresh_serial) {
                return;
            }
            scope_text = "Projects / %s / Trash".printf(project.name);
            clear_store();
            foreach (var item in items) {
                items_store.append(item);
            }
            empty_visible = items_store.get_n_items() == 0;
            if (empty_visible) {
                empty_text = "No deleted items in this project.";
            }
            empty_trash_sensitive = items_store.get_n_items() > 0;
            committed_project_id = project.project_id;
            state_changed();
        } catch (Error e) {
            if (serial != refresh_serial) {
                return; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: stale async error guard depends on superseding refresh race timing
            }
            // A failed refresh keeps what is already shown only when it is this project's own list;
            // another project's items must not stay on screen under the new project's name.
            if (committed_project_id != project.project_id) {
                scope_text = "Projects / %s / Trash".printf(project.name);
                empty_text = "Failed to load trash.";
                clear_store();
                empty_visible = true;
                empty_trash_sensitive = false;
                committed_project_id = null;
                state_changed();
            }
            error_reported("Trash refresh failed", e.message);
        }
    }

    public async void restore_item(TrashItem item) {
        if (api == null) {
            return;
        }
        var project_id = owning_project_id();
        try {
            yield api.restore_trash_item(item.item_type, item.item_id);
            activity_requested(
                ACTIVITY_KIND_RESTORED,
                "Restored %s: %s".printf(item.item_type, item.title),
                project_id,
                item.item_id,
                new TrashActionDetails(item.item_type, item.title)
            );
            toast_requested("Item restored.");
            queue_refresh();
        } catch (Error e) {
            activity_requested(
                "result.trash.restore_failed",
                "Failed to restore %s: %s".printf(item.item_type, e.message),
                project_id,
                item.item_id,
                null
            );
            error_reported("Failed to restore item", e.message);
        }
    }

    public async void hard_delete_item(TrashItem item) {
        if (api == null) {
            return;
        }
        var project_id = owning_project_id();
        try {
            yield api.hard_delete_trash_item(item.item_type, item.item_id);
            activity_requested(
                "result.trash.delete",
                "Permanently deleted %s: %s".printf(item.item_type, item.title),
                project_id,
                item.item_id,
                new TrashActionDetails(item.item_type, item.title)
            );
            toast_requested("Item permanently deleted.");
            queue_refresh();
        } catch (Error e) {
            activity_requested(
                "result.trash.delete_failed",
                "Failed to permanently delete %s: %s".printf(item.item_type, e.message),
                project_id,
                item.item_id,
                null
            );
            error_reported("Failed to permanently delete item", e.message);
        }
    }

    public async void empty_trash(string project_id) {
        if (api == null) {
            return;
        }
        try {
            yield api.empty_trash(project_id, "all");
            activity_requested(
                "result.trash.empty",
                "Emptied trash",
                project_id,
                null,
                new TrashActionDetails("all", "all")
            );
            toast_requested("Trash emptied.");
            queue_refresh();
        } catch (Error e) {
            activity_requested(
                "result.trash.empty_failed",
                "Failed to empty trash: %s".printf(e.message),
                project_id,
                null,
                null
            );
            error_reported("Failed to empty trash", e.message);
        }
    }

    public string pretty_type(string item_type) {
        switch (item_type) {
            case "card":
                return "Card";
            case "ai_message":
                return "AI message";
            default:
                return item_type;
        }
    }

    public string format_epoch(int64 epoch_seconds) {
        if (epoch_seconds <= 0) {
            return "";
        }
        var dt = new DateTime.from_unix_local(epoch_seconds);
        return dt.format("%Y-%m-%d %H:%M");
    }

    public string hard_delete_dialog_title() {
        return "Delete Permanently";
    }

    public string hard_delete_dialog_body(TrashItem item) {
        return "Permanently delete \"%s\"?".printf(item.title);
    }

    public string empty_trash_dialog_title() {
        return "Empty Trash";
    }

    public string empty_trash_dialog_body(Project project) {
        return "Permanently delete all trash items in %s?".printf(project.name);
    }

    public TrashConfirmDialogSpec hard_delete_confirmation(TrashItem item) {
        return new TrashConfirmDialogSpec(
            hard_delete_dialog_title(),
            hard_delete_dialog_body(item),
            "delete",
            "Delete"
        );
    }

    public TrashConfirmDialogSpec empty_trash_confirmation(Project project) {
        return new TrashConfirmDialogSpec(
            empty_trash_dialog_title(),
            empty_trash_dialog_body(project),
            "empty",
            "Empty Trash"
        );
    }

    // The project the listed items belong to, falling back to the selected one before any list has
    // arrived.
    private string? owning_project_id() {
        if (committed_project_id != null) {
            return committed_project_id;
        }
        var project = selected_project();
        return project != null ? project.project_id : null;
    }

    private string selected_filter_type() {
        switch (filter_index) {
            case 1:
                return "card";
            case 2:
                return "ai_message";
            default:
                return "all";
        }
    }

    private void clear_store() {
        while (items_store.get_n_items() > 0) {
            items_store.remove(items_store.get_n_items() - 1);
        }
    }
}

}
