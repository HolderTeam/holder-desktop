using GLib;

namespace HolderLinuxTests {

private HolderLinux.ResourceAsset rvd_asset(string id, string resource_id, string filename) {
    return new HolderLinux.ResourceAsset(id, resource_id, filename, "image/png", 5, "");
}

private void rvd_add_value(Gee.HashMap<string, Gee.ArrayList<string>> map, string key, string value) {
    var values = map.get(key);
    if (values == null) {
        values = new Gee.ArrayList<string>();
        map.set(key, values);
    }
    values.add(value);
}

private HolderLinux.ResourceCardReference rvd_reference(string card_id, string title, string[] kinds) {
    var link_kinds = new Gee.ArrayList<string>();
    foreach (var kind in kinds) {
        link_kinds.add(kind);
    }
    return new HolderLinux.ResourceCardReference(card_id, title, 1, link_kinds);
}

private ResourcesViewHarness rvd_harness_with(HolderLinux.ProjectResource[] items) {
    var h = new ResourcesViewHarness();
    foreach (var item in items) {
        h.api.resources.add(item);
    }
    h.view.request_refresh();
    assert(h.wait_for_resources(items.length));
    return h;
}

private Gtk.Label? rvd_find_label(Gtk.Widget root, string text, string? tooltip = null) {
    foreach (var widget in rv_descendants(root)) {
        var label = widget as Gtk.Label;
        if (label != null && ((!) label).get_text() == text &&
            (tooltip == null || ((!) label).get_tooltip_text() == tooltip)) {
            return label;
        }
    }
    return null;
}

// Row widgets only exist once the ColumnView has been allocated, so keep allocating while waiting.
private bool rvd_wait_for_label(ResourcesViewHarness h, string text, string? tooltip = null) {
    return wait_for_condition(() => {
        rv_allocate(h.view.widget);
        return rvd_find_label(h.view.widget, text, tooltip) != null;
    });
}

private bool rvd_wait_for_button(ResourcesViewHarness h, string label) {
    return wait_for_condition(() => {
        rv_allocate(h.view.widget);
        return rv_button_labeled(h.view.widget, label) != null;
    });
}

// Presses a response button of an Adw.AlertDialog the way a user would, so the dialog also closes.
private void rvd_press(Adw.AlertDialog dialog, string button_label) {
    rv_button(dialog, button_label).clicked();
}

private Adw.AlertDialog rvd_open_add_dialog(ResourcesViewHarness h) {
    rv_tooltip_button(h.actions(), "Add resource").clicked();
    assert(h.wait_for_dialog());
    return (!) h.dialog();
}

private Adw.AlertDialog rvd_open_edit_dialog(ResourcesViewHarness h) {
    rv_button(h.actions(), "Edit").clicked();
    assert(h.wait_for_dialog());
    return (!) h.dialog();
}

private Gtk.Widget rvd_content(Adw.AlertDialog dialog) {
    var content = dialog.get_extra_child();
    assert(content != null);
    return (!) content;
}

private Gtk.Entry rvd_label_entry(Adw.AlertDialog dialog) {
    return rv_entry_after_label(rvd_content(dialog), "Label (required)");
}

private Gtk.Label? rvd_error_label(Adw.AlertDialog dialog) {
    foreach (var widget in rv_descendants(rvd_content(dialog))) {
        if (widget is Gtk.Label && widget.has_css_class("error")) {
            return (Gtk.Label) widget;
        }
    }
    return null;
}

// ---- list rendering --------------------------------------------------------------------------

private void test_list_cells_render_presenter_text_and_tooltips() {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(rvd_asset("a1", "r1", "pic.png"));
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "document", "https://example.test/doc", "Example", "Docs", null, assets)
    });
    var root = h.view.widget;

    assert(rvd_wait_for_label(h, "Example", "Example"));
    assert(rvd_find_label(root, "document", "document") != null);
    assert(rvd_find_label(root, "1", "1 attached asset") != null);
    assert(rvd_find_label(root, "Docs", "Docs") != null);
    var updated = new DateTime.from_unix_local(1700000100).format("%Y-%m-%d %H:%M");
    assert(rvd_find_label(root, updated, "1700000100") != null);
    assert(rvd_find_label(root, "—") != null);
}

private void test_list_cell_ellipsizes_long_labels_but_keeps_the_full_tooltip() {
    var long_label = string.nfill(60, 'x');
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", long_label)
    });

    assert(rvd_wait_for_label(h, string.nfill(44, 'x') + "...", long_label));
}

private void test_usage_column_shows_card_reference_buttons_that_open_the_card() {
    var references = new Gee.ArrayList<HolderLinux.ResourceCardReference>();
    references.add(rvd_reference("c1", "Alpha notes", { "attachment", "reference" }));
    references.add(rvd_reference("c2", "Beta plan", {}));
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", "Example", null, null, null, references)
    });

    assert(rvd_wait_for_button(h, "Alpha notes"));
    var alpha = rv_button(h.view.widget, "Alpha notes");
    var beta = rv_button(h.view.widget, "Beta plan");
    assert(alpha.get_tooltip_text() == "Alpha notes · Attachment, Reference");
    assert(beta.get_tooltip_text() == "Beta plan");
    assert(rvd_find_label(h.view.widget, "·") != null);
    assert(rv_button_labeled(h.view.widget, "+0 more") == null);

    beta.clicked();
    alpha.clicked();
    assert(h.card_opens.size == 2);
    assert(h.card_opens[0] == "c2");
    assert(h.card_opens[1] == "c1");
}

private void test_usage_column_collapses_many_references_into_a_more_button() {
    var references = new Gee.ArrayList<HolderLinux.ResourceCardReference>();
    references.add(rvd_reference("c1", "Alpha notes", {}));
    references.add(rvd_reference("c2", "Beta plan", {}));
    references.add(rvd_reference("c3", "Gamma log", {}));
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", "Example", null, null, null, references)
    });

    assert(rvd_wait_for_button(h, "+2 more"));
    assert(rv_button_labeled(h.view.widget, "Alpha notes") != null);
    assert(rv_button_labeled(h.view.widget, "Beta plan") == null);
    var more = rv_button(h.view.widget, "+2 more");
    assert(more.get_tooltip_text() == "Alpha notes\nBeta plan\nGamma log");

    more.clicked();
    assert(h.reference_requests.size == 1);
    assert(h.reference_requests[0] == "r1");
    assert(h.card_opens.size == 0);
}

// ---- selection and open ---------------------------------------------------------------------

private void test_actions_are_disabled_when_the_filter_removes_every_row() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", "Example")
    });
    assert(wait_for_condition(() => rv_button(h.actions(), "Open").get_sensitive()));

    rvd_set_filter(h, "nothing-matches");
    assert(wait_for_condition(() => !rv_button(h.actions(), "Open").get_sensitive()));
    assert(!rv_button(h.actions(), "Edit").get_sensitive());
    assert(!rv_button(h.actions(), "Delete").get_sensitive());
}

private void rvd_set_filter(ResourcesViewHarness h, string text) {
    foreach (var widget in rv_descendants(h.actions())) {
        if (widget is Gtk.SearchEntry) {
            ((Gtk.SearchEntry) widget).set_text(text);
            return;
        }
    }
    assert_not_reached();
}

private void test_open_button_previews_the_first_asset() {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(rvd_asset("a1", "r1", "pic.png"));
    assets.add(rvd_asset("a2", "r1", "other.png"));
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "image", "", "Picture", null, null, assets)
    });

    rv_button(h.actions(), "Open").clicked();

    assert(h.previews.size == 1);
    assert(h.previews[0] == "r1|a1");
    assert(h.toasts.size == 0);
}

private void test_open_button_explains_a_resource_with_nothing_to_open() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "thing", "", "Nothing")
    });

    rv_button(h.actions(), "Open").clicked();

    assert(h.toasts.size == 1);
    assert(h.toasts[0] == "This Resource has no Asset or identifier to open.");
    assert(h.previews.size == 0);
}

private void test_open_button_without_a_selection_does_nothing() {
    var h = new ResourcesViewHarness();

    rv_button(h.actions(), "Open").clicked();
    rv_button(h.actions(), "Edit").clicked();
    rv_button(h.actions(), "Delete").clicked();

    assert(h.toasts.size == 0);
    assert(h.previews.size == 0);
    assert(h.dialog() == null);
}

private void test_open_button_reports_a_uri_that_cannot_be_launched() {
    if (Path.DIR_SEPARATOR == '\\') {
        // The Windows shell would show its "open with" picker for an unregistered scheme.
        Test.skip("launching an unregistered URI scheme is interactive on Windows");
        return;
    }
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "x-holder-no-such-scheme-9f3a:probe", "Unlaunchable")
    });

    rv_button(h.actions(), "Open").clicked();

    assert(h.errors.size == 1);
    assert(h.errors[0].has_prefix("Failed to open resource|"));
}

private void test_activating_a_row_selects_and_opens_it() {
    var assets = new Gee.ArrayList<HolderLinux.ResourceAsset>();
    assets.add(rvd_asset("a2", "r2", "pic.png"));
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "thing", "", "First"),
        rv_resource("r2", "image", "", "Second", null, null, assets)
    });
    assert(rv_selected_id(h.view) == "r1");

    rv_column_view(h.view).activate(1);

    assert(rv_selected_id(h.view) == "r2");
    assert(h.previews.size == 1);
    assert(h.previews[0] == "r2|a2");
}

// ---- view level -----------------------------------------------------------------------------

private void test_project_selection_change_reloads_resources_for_the_new_project() {
    var h = new ResourcesViewHarness();
    assert(wait_for_condition(() => h.loaded_projects.contains("p1")));
    assert(h.api.last_resource_project_id == "p1");

    ((!) h.projects).set_selected(1);

    assert(wait_for_condition(() => h.loaded_projects.contains("p2")));
    assert(h.api.last_resource_project_id == "p2");
}

private void test_navigation_and_shell_accessors_refresh_the_list() {
    var h = new ResourcesViewHarness();
    assert(h.view.tool_id == "resources");
    assert(h.view.tool_label == "Resources");
    assert(h.view.get_content_widget() == h.view.widget);
    assert(h.view.get_actions_widget() != null);
    var snapshot = h.view.get_scope_snapshot(null, null);
    assert(snapshot.tool_id == "resources");

    var before = h.api.list_resources_calls;
    bool done = false;
    bool ok_root = false;
    h.view.navigate_to_projects_root.begin("p1", (obj, res) => {
        ok_root = h.view.navigate_to_projects_root.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(ok_root);
    assert(h.api.list_resources_calls > before);

    before = h.api.list_resources_calls;
    done = false;
    bool ok_card = false;
    h.view.navigate_to_card.begin("c1", (obj, res) => {
        ok_card = h.view.navigate_to_card.end(res);
        done = true;
    });
    assert(wait_for_condition(() => done));
    assert(ok_card);
    assert(h.api.list_resources_calls > before);
}

private void test_missing_api_reports_it_in_the_empty_state() {
    var h = new ResourcesViewHarness();
    h.view.set_api_client(null);

    assert(wait_for_condition(() => rv_named_label(h.view.widget, "resources-empty-state") != null &&
                                    ((!) rv_named_label(h.view.widget, "resources-empty-state")).get_visible()));
    assert(((!) rv_named_label(h.view.widget, "resources-empty-state")).get_text() == "API unavailable.");
}

// ---- add / edit / delete dialogs -------------------------------------------------------------

private void test_add_button_without_a_project_asks_for_one() {
    var h = new ResourcesViewHarness(false);

    rv_tooltip_button(h.actions(), "Add resource").clicked();

    assert(h.toasts.size == 1);
    assert(h.toasts[0] == "Select a project first.");
    assert(h.dialog() == null);
}

private void test_add_button_outside_a_window_does_nothing() {
    var h = new ResourcesViewHarness(true, false);

    rv_tooltip_button(h.actions(), "Add resource").clicked();

    assert(h.toasts.size == 0);
    assert(h.dialog() == null);
}

private void test_add_dialog_starts_empty_and_enables_save_only_with_a_label() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    var content = rvd_content(dialog);

    assert(dialog.get_heading() == "Add Resource");
    assert(!dialog.get_response_enabled("save"));
    assert(rv_dropdown(content).get_selected() == 0);
    assert(!rv_entry(content, "custom kind").get_visible());
    assert(rvd_label_entry(dialog).get_text() == "");

    rvd_label_entry(dialog).set_text("   ");
    assert(!dialog.get_response_enabled("save"));
    rvd_label_entry(dialog).set_text("Example");
    assert(dialog.get_response_enabled("save"));
}

private void test_saving_the_add_dialog_creates_the_resource_with_trimmed_values() {
    var h = new ResourcesViewHarness();
    assert(h.wait_for_locations_refresh());
    var dialog = rvd_open_add_dialog(h);
    var content = rvd_content(dialog);
    rv_entry_after_label(content, "Identifier (optional)").set_text("  https://example.test/x  ");
    rvd_label_entry(dialog).set_text("  My thing ");
    var before = h.api.list_resources_calls;

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.api.create_resource_calls == 1));
    assert(h.api.last_resource_project_id == "p1");
    assert(h.api.last_resource_kind == "thing");
    assert(h.api.last_resource_uri == "https://example.test/x");
    assert(h.api.last_resource_label == "My thing");
    assert(h.api.last_resource_desc == null);
    assert(h.wait_for_toast("Resource added."));
    assert(wait_for_condition(() => h.api.list_resources_calls > before));
}

private void test_description_is_sent_when_it_is_not_blank() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    rvd_label_entry(dialog).set_text("Documented");
    rv_entry_after_label(rvd_content(dialog), "Description (optional)").set_text(" Some docs ");

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.api.create_resource_calls == 1));
    assert(h.api.last_resource_desc == "Some docs");
}

private void test_kind_dropdown_selection_becomes_the_created_kind() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    rvd_label_entry(dialog).set_text("A book");
    rv_dropdown(rvd_content(dialog)).set_selected(5);

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.api.create_resource_calls == 1));
    assert(h.api.last_resource_kind == "book");
}

private void test_custom_kind_entry_appears_for_the_last_option_and_is_used() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    var content = rvd_content(dialog);
    var dropdown = rv_dropdown(content);
    var custom = rv_entry(content, "custom kind");
    rvd_label_entry(dialog).set_text("Widget");

    dropdown.set_selected(7);
    assert(custom.get_visible());
    custom.set_text("  gadget ");
    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.api.create_resource_calls == 1));
    assert(h.api.last_resource_kind == "gadget");
}

private void test_blank_custom_kind_falls_back_to_the_default_kind() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    rvd_label_entry(dialog).set_text("Anything");
    rv_dropdown(rvd_content(dialog)).set_selected(7);

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.api.create_resource_calls == 1));
    assert(h.api.last_resource_kind == "thing");
}

private void test_leaving_the_custom_option_hides_and_clears_the_custom_entry() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    var content = rvd_content(dialog);
    var dropdown = rv_dropdown(content);
    var custom = rv_entry(content, "custom kind");

    dropdown.set_selected(7);
    custom.set_text("temporary");
    dropdown.set_selected(2);

    assert(!custom.get_visible());
    assert(custom.get_text() == "");
}

private void test_additional_details_are_validated_and_sent_as_metadata() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    var content = rvd_content(dialog);
    var details = rv_text_view(content);
    rvd_label_entry(dialog).set_text("With details");
    var error = rvd_error_label(dialog);
    assert(error != null);
    assert(!((!) error).get_visible());

    details.get_buffer().set_text("not a property line");
    assert(!dialog.get_response_enabled("save"));
    assert(((!) error).get_visible());
    assert(((!) error).get_text() == "Additional Details must use one ‘property: value’ entry per line.");

    details.get_buffer().set_text("creator: Ada\ncreator: Bob\nlanguage: en");
    assert(dialog.get_response_enabled("save"));
    assert(!((!) error).get_visible());

    rvd_press(dialog, "Save");
    assert(wait_for_condition(() => h.api.create_resource_calls == 1));
    var metadata = h.api.last_resource_extra_metadata;
    assert(metadata != null);
    assert(((!) metadata).get("creator").size == 2);
    assert(((!) metadata).get("creator")[1] == "Bob");
    assert(((!) metadata).get("language")[0] == "en");
}

private void test_saving_without_a_label_reports_it_and_creates_nothing() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);

    dialog.response("save");

    assert(h.toasts.size == 1);
    assert(h.toasts[0] == "A label is required.");
    assert(h.api.create_resource_calls == 0);
}

private void test_saving_with_invalid_details_reports_the_parse_error() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    rvd_label_entry(dialog).set_text("Broken");
    rv_text_view(rvd_content(dialog)).get_buffer().set_text("identifier: sneaky");

    dialog.response("save");

    assert(h.toasts.size == 1);
    assert(h.toasts[0] == "Additional Details need a custom property name and a non-empty value.");
    assert(h.api.create_resource_calls == 0);
}

private void test_cancelling_the_add_dialog_makes_no_api_call() {
    var h = new ResourcesViewHarness();
    var dialog = rvd_open_add_dialog(h);
    rvd_label_entry(dialog).set_text("Never saved");

    rvd_press(dialog, "Cancel");

    h.settle();
    assert(h.api.create_resource_calls == 0);
    assert(h.toasts.size == 0);
}

private void test_create_failure_from_the_dialog_is_reported() {
    var h = new ResourcesViewHarness();
    h.api.fail_create_resource = true;
    var dialog = rvd_open_add_dialog(h);
    rvd_label_entry(dialog).set_text("Doomed");

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to create resource|create resource failed");
    assert(h.toasts.size == 0);
}

private HolderLinux.ProjectResource rvd_editable_resource(string kind = "document") {
    var metadata = new Gee.HashMap<string, Gee.ArrayList<string>>();
    rvd_add_value(metadata, "identifier", "https://a.test/doc");
    rvd_add_value(metadata, "description", "Old docs");
    rvd_add_value(metadata, "creator", "Ada");
    return rv_resource("r1", kind, "", "Original", null, metadata);
}

private void test_edit_dialog_is_prefilled_from_the_selected_resource() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] { rvd_editable_resource() });
    var dialog = rvd_open_edit_dialog(h);
    var content = rvd_content(dialog);

    assert(dialog.get_heading() == "Edit Resource");
    assert(rv_entry_after_label(content, "Identifier (optional)").get_text() == "https://a.test/doc");
    assert(rvd_label_entry(dialog).get_text() == "Original");
    assert(rv_entry_after_label(content, "Description (optional)").get_text() == "Old docs");
    assert(rv_text_of(rv_text_view(content)) == "creator: Ada");
    assert(rv_dropdown(content).get_selected() == 1);
    assert(!rv_entry(content, "custom kind").get_visible());
    assert(dialog.get_response_enabled("save"));
}

private void test_edit_dialog_shows_an_unknown_kind_in_the_custom_entry() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] { rvd_editable_resource("gizmo") });
    var dialog = rvd_open_edit_dialog(h);
    var content = rvd_content(dialog);

    assert(rv_dropdown(content).get_selected() == 7);
    assert(rv_entry(content, "custom kind").get_visible());
    assert(rv_entry(content, "custom kind").get_text() == "gizmo");
}

private void test_saving_the_edit_dialog_updates_the_resource_and_keeps_omitted_metadata_keys() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] { rvd_editable_resource() });
    var dialog = rvd_open_edit_dialog(h);
    var content = rvd_content(dialog);
    rvd_label_entry(dialog).set_text("Renamed");
    rv_text_view(content).get_buffer().set_text("");
    var before = h.api.list_resources_calls;

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.api.update_resource_calls == 1));
    assert(h.api.last_resource_id == "r1");
    assert(h.api.last_resource_kind == "document");
    assert(h.api.last_resource_label == "Renamed");
    assert(h.api.last_resource_uri == "https://a.test/doc");
    assert(h.api.last_resource_desc == "Old docs");
    // A key the user removed from the details box is still sent (empty) so the backend clears it.
    var metadata = h.api.last_resource_extra_metadata;
    assert(metadata != null);
    assert(((!) metadata).has_key("creator"));
    assert(((!) metadata).get("creator").size == 0);
    assert(h.wait_for_toast("Resource updated."));
    assert(wait_for_condition(() => h.api.list_resources_calls > before));
}

private void test_update_failure_from_the_edit_dialog_is_reported() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] { rvd_editable_resource() });
    h.api.fail_update_resource = true;
    var dialog = rvd_open_edit_dialog(h);

    rvd_press(dialog, "Save");

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to update resource|update resource failed");
}

private void test_delete_asks_for_confirmation_before_deleting() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", "Example")
    });

    rv_button(h.actions(), "Delete").clicked();
    assert(h.wait_for_dialog());
    var dialog = (!) h.dialog();
    assert(dialog.get_heading() == "Delete Resource");
    assert(dialog.get_body() == "Delete \"Example\"?");

    rvd_press(dialog, "Cancel");
    h.settle();
    assert(h.api.delete_resource_calls == 0);

    var before = h.api.list_resources_calls;
    rv_button(h.actions(), "Delete").clicked();
    assert(h.wait_for_dialog());
    rvd_press((!) h.dialog(), "Delete");

    assert(wait_for_condition(() => h.api.delete_resource_calls == 1));
    assert(h.api.last_resource_id == "r1");
    assert(h.wait_for_toast("Resource deleted."));
    assert(wait_for_condition(() => h.api.list_resources_calls > before));
}

private void test_delete_failure_is_reported() {
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", "Example")
    });
    h.api.fail_delete_resource = true;

    rv_button(h.actions(), "Delete").clicked();
    assert(h.wait_for_dialog());
    rvd_press((!) h.dialog(), "Delete");

    assert(wait_for_condition(() => h.errors.size == 1));
    assert(h.errors[0] == "Failed to delete resource|delete resource failed");
}


// ---- guards ----------------------------------------------------------------------------------

private void rvd_run_all_mutations(ResourcesViewHarness h) {
    int finished = 0;
    h.view.create_resource.begin("p1", "url", "https://x.test", "X", null, null, (obj, res) => {
        h.view.create_resource.end(res);
        finished++;
    });
    h.view.update_resource.begin("r1", "url", "https://x.test", "X", null, null, (obj, res) => {
        h.view.update_resource.end(res);
        finished++;
    });
    h.view.delete_resource.begin("r1", (obj, res) => {
        h.view.delete_resource.end(res);
        finished++;
    });
    assert(wait_for_condition(() => finished == 3));
}

private void test_mutations_without_an_api_are_ignored_quietly() {
    var h = new ResourcesViewHarness();
    h.view.set_api_client(null);

    rvd_run_all_mutations(h);

    assert(h.toasts.size == 0);
    assert(h.errors.size == 0);
    assert(h.api.create_resource_calls == 0);
    assert(h.api.update_resource_calls == 0);
    assert(h.api.delete_resource_calls == 0);
}

private void test_update_and_delete_still_run_when_no_project_is_selected() {
    var h = new ResourcesViewHarness(false);

    int finished = 0;
    h.view.update_resource.begin("r1", "url", "https://x.test", "X", null, null, (obj, res) => {
        h.view.update_resource.end(res);
        finished++;
    });
    h.view.delete_resource.begin("r1", (obj, res) => {
        h.view.delete_resource.end(res);
        finished++;
    });
    assert(wait_for_condition(() => finished == 2));

    assert(h.api.update_resource_calls == 1);
    assert(h.api.delete_resource_calls == 1);
    assert(h.toasts.contains("Resource updated."));
    assert(h.toasts.contains("Resource deleted."));
}

private void test_edit_and_delete_outside_a_window_do_not_open_dialogs() {
    var h = new ResourcesViewHarness(true, false);
    h.api.resources.add(rv_resource("r1", "url", "https://example.test", "Example"));
    h.view.request_refresh();
    assert(h.wait_for_resources(1));

    rv_button(h.actions(), "Edit").clicked();
    rv_button(h.actions(), "Delete").clicked();

    assert(h.dialog() == null);
    assert(h.toasts.size == 0);
    assert(h.api.delete_resource_calls == 0);
}

private void test_usage_cells_are_rebuilt_when_a_row_is_bound_to_another_resource() {
    var first = new Gee.ArrayList<HolderLinux.ResourceCardReference>();
    first.add(rvd_reference("c1", "Alpha notes", {}));
    var second = new Gee.ArrayList<HolderLinux.ResourceCardReference>();
    second.add(rvd_reference("c9", "Zeta plan", {}));
    var h = rvd_harness_with(new HolderLinux.ProjectResource[] {
        rv_resource("r1", "url", "https://example.test", "First", null, null, null, first)
    });
    assert(rvd_wait_for_button(h, "Alpha notes"));

    h.api.resources.clear();
    h.api.resources.add(rv_resource("r2", "url", "https://example.test", "Second", null, null, null, second));
    h.view.request_refresh();

    assert(rvd_wait_for_button(h, "Zeta plan"));
    assert(rv_button_labeled(h.view.widget, "Alpha notes") == null);
}

public void register_resources_view_dialog_tests() {
    var prefix = "/holder/resources-view/";
    Test.add_func(prefix + "list/cells", test_list_cells_render_presenter_text_and_tooltips);
    Test.add_func(prefix + "list/ellipsis", test_list_cell_ellipsizes_long_labels_but_keeps_the_full_tooltip);
    Test.add_func(prefix + "list/usage-buttons", test_usage_column_shows_card_reference_buttons_that_open_the_card);
    Test.add_func(prefix + "list/usage-more", test_usage_column_collapses_many_references_into_a_more_button);
    Test.add_func(prefix + "selection/actions-disabled-when-empty", test_actions_are_disabled_when_the_filter_removes_every_row);
    Test.add_func(prefix + "open/asset", test_open_button_previews_the_first_asset);
    Test.add_func(prefix + "open/nothing", test_open_button_explains_a_resource_with_nothing_to_open);
    Test.add_func(prefix + "open/no-selection", test_open_button_without_a_selection_does_nothing);
    Test.add_func(prefix + "open/unlaunchable-uri", test_open_button_reports_a_uri_that_cannot_be_launched);
    Test.add_func(prefix + "open/row-activation", test_activating_a_row_selects_and_opens_it);
    Test.add_func(prefix + "view/project-change", test_project_selection_change_reloads_resources_for_the_new_project);
    Test.add_func(prefix + "view/navigation", test_navigation_and_shell_accessors_refresh_the_list);
    Test.add_func(prefix + "view/missing-api", test_missing_api_reports_it_in_the_empty_state);
    Test.add_func(prefix + "add/no-project", test_add_button_without_a_project_asks_for_one);
    Test.add_func(prefix + "add/no-window", test_add_button_outside_a_window_does_nothing);
    Test.add_func(prefix + "add/defaults", test_add_dialog_starts_empty_and_enables_save_only_with_a_label);
    Test.add_func(prefix + "add/save", test_saving_the_add_dialog_creates_the_resource_with_trimmed_values);
    Test.add_func(prefix + "add/description", test_description_is_sent_when_it_is_not_blank);
    Test.add_func(prefix + "add/kind", test_kind_dropdown_selection_becomes_the_created_kind);
    Test.add_func(prefix + "add/custom-kind", test_custom_kind_entry_appears_for_the_last_option_and_is_used);
    Test.add_func(prefix + "add/blank-custom-kind", test_blank_custom_kind_falls_back_to_the_default_kind);
    Test.add_func(prefix + "add/custom-kind-hidden", test_leaving_the_custom_option_hides_and_clears_the_custom_entry);
    Test.add_func(prefix + "add/details", test_additional_details_are_validated_and_sent_as_metadata);
    Test.add_func(prefix + "add/no-label", test_saving_without_a_label_reports_it_and_creates_nothing);
    Test.add_func(prefix + "add/invalid-details", test_saving_with_invalid_details_reports_the_parse_error);
    Test.add_func(prefix + "add/cancel", test_cancelling_the_add_dialog_makes_no_api_call);
    Test.add_func(prefix + "add/failure", test_create_failure_from_the_dialog_is_reported);
    Test.add_func(prefix + "edit/prefilled", test_edit_dialog_is_prefilled_from_the_selected_resource);
    Test.add_func(prefix + "edit/unknown-kind", test_edit_dialog_shows_an_unknown_kind_in_the_custom_entry);
    Test.add_func(prefix + "edit/save", test_saving_the_edit_dialog_updates_the_resource_and_keeps_omitted_metadata_keys);
    Test.add_func(prefix + "edit/failure", test_update_failure_from_the_edit_dialog_is_reported);
    Test.add_func(prefix + "delete/confirm", test_delete_asks_for_confirmation_before_deleting);
    Test.add_func(prefix + "delete/failure", test_delete_failure_is_reported);
    Test.add_func(prefix + "guards/no-api", test_mutations_without_an_api_are_ignored_quietly);
    Test.add_func(prefix + "guards/no-project", test_update_and_delete_still_run_when_no_project_is_selected);
    Test.add_func(prefix + "guards/no-window", test_edit_and_delete_outside_a_window_do_not_open_dialogs);
    Test.add_func(prefix + "guards/usage-rebind", test_usage_cells_are_rebuilt_when_a_row_is_bound_to_another_resource);
}

}
