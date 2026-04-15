namespace HolderLinux.Tests {

private bool wait_until_true(owned SourceFunc predicate, int timeout_ms = 2000) {
    var loop = new MainLoop(null, false);
    var deadline = GLib.get_monotonic_time() + (int64) timeout_ms * 1000;
    Timeout.add(5, () => {
        if (predicate()) {
            loop.quit();
            return Source.REMOVE;
        }
        if (GLib.get_monotonic_time() >= deadline) {
            loop.quit();
            return Source.REMOVE;
        }
        return Source.CONTINUE;
    });
    loop.run();
    return predicate();
}

private CardSummary card(string id,
                         string project_id,
                         string title,
                         double sort_key,
                         string? parent = null,
                         int64 updated_at = 100) {
    return new CardSummary(id, project_id, title, "cards/%s.md".printf(id), sort_key, parent, 1, updated_at);
}

private void test_ellipsize_title() {
    var controller = new ConnectionsController();
    var short_title = "short";
    assert(controller.ellipsize_title(short_title) == short_title);

    var long_title = "123456789012345678901234567890123456789012345678901234567890";
    var result = controller.ellipsize_title(long_title);
    assert(result.char_count() == 47);
    assert(result.has_suffix("..."));
}

private void test_ellipsize_title_exact_47_is_ellipsized() {
    var controller = new ConnectionsController();
    var exact_47 = "12345678901234567890123456789012345678901234567";
    assert(exact_47.char_count() == 47);
    var result = controller.ellipsize_title(exact_47);
    assert(result.char_count() == 47);
    assert(result.has_suffix("..."));
}

private void test_ellipsize_title_null_returns_empty() {
    var controller = new ConnectionsController();
    string? nullable_title = null;
    assert(controller.ellipsize_title((string) nullable_title) == "");
}

private void test_ellipsize_title_cutoff_negative_returns_original_title() {
    var controller = new ConnectionsController();
    ConnectionsController.ellipsize_cutoff_override_for_tests = -1;
    var title = "123456789012345678901234567890123456789012345678901234567890";
    var result = controller.ellipsize_title(title);
    ConnectionsController.ellipsize_cutoff_override_for_tests = int.MIN;
    assert(result == title);
}

private void test_resolve_internal_link() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("a", "p1", "Alpha", 10));
    cards.add(card("b", "p1", "Beta", 20));
    cards.add(card("c", "p2", "Alpha", 30));

    assert(controller.resolve_internal_link_target_card_id("b", "p1", cards) == "b");
    assert(controller.resolve_internal_link_target_card_id("Beta", "p1", cards) == "b");
    assert(controller.resolve_internal_link_target_card_id("alpha", "p1", cards) == "a");
    assert(controller.resolve_internal_link_target_card_id("Alpha", "p2", cards) == "c");
    assert(controller.resolve_internal_link_target_card_id("missing", "p1", cards) == null);
}

private void test_resolve_internal_link_prefers_exact_title_before_casefold() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("lower", "p1", "alpha", 10));
    cards.add(card("upper", "p1", "Alpha", 20));

    assert(controller.resolve_internal_link_target_card_id("Alpha", "p1", cards) == "upper");
    assert(controller.resolve_internal_link_target_card_id("alpha", "p1", cards) == "lower");
}

private void test_resolve_internal_link_empty_inputs() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("a", "p1", "Alpha", 10));
    assert(controller.resolve_internal_link_target_card_id("", "p1", cards) == null);
    assert(controller.resolve_internal_link_target_card_id("Alpha", null, cards) == null);
}

private void test_compact_structure_markup() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("parent", "p1", "Parent", 10, null, 10));
    cards.add(card("sel", "p1", "Selected", 20, null, 20));
    cards.add(card("next", "p1", "Next Card", 30, null, 30));
    cards.add(card("child", "p1", "Child Card", 10, "sel", 40));

    var selected = cards[1];
    var markup = controller.compact_structure_markup(project, selected, cards);
    assert(markup.contains("Project:"));
    assert(markup.contains("Previous:"));
    assert(markup.contains("Next:"));
    assert(markup.contains("Children:"));
}

private void test_compact_structure_markup_sibling_order_uses_updated_then_title() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("prev", "p1", "A", 10, null, 30));
    cards.add(card("sel", "p1", "Selected", 10, null, 20));
    cards.add(card("next", "p1", "Z", 10, null, 10));

    var markup = controller.compact_structure_markup(project, cards[1], cards);
    assert(markup.contains("Previous: <a href=\"card:prev\">A</a>"));
    assert(markup.contains("Next: <a href=\"card:next\">Z</a>"));
}

private void test_compact_structure_markup_sibling_order_updated_at_desc_returns_minus_one_path() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    // Same sort_key so comparator must use updated_at ordering.
    cards.add(card("older", "p1", "Older", 10, null, 100));
    cards.add(card("newer", "p1", "Newer", 10, null, 200));
    cards.add(card("sel", "p1", "Selected", 10, null, 150));

    var markup = controller.compact_structure_markup(project, cards[2], cards);
    // Selected should sit between newer and older after updated_at-desc sort.
    assert(markup.contains("Previous: <a href=\"card:newer\">Newer</a>"));
    assert(markup.contains("Next: <a href=\"card:older\">Older</a>"));
}

private void test_compact_structure_markup_sibling_order_uses_sort_key_first() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("sel", "p1", "Selected", 20, null, 50));
    cards.add(card("prev", "p1", "A", 10, null, 10));
    cards.add(card("next", "p1", "Z", 30, null, 999));

    var markup = controller.compact_structure_markup(project, cards[0], cards);
    assert(markup.contains("Previous: <a href=\"card:prev\">A</a>"));
    assert(markup.contains("Next: <a href=\"card:next\">Z</a>"));
}

private void test_compact_structure_markup_sibling_order_tiebreaks_by_title() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("z", "p1", "zulu", 10, null, 100));
    cards.add(card("m", "p1", "mike", 10, null, 100));
    cards.add(card("a", "p1", "alpha", 10, null, 100));

    var markup = controller.compact_structure_markup(project, cards[1], cards);
    assert(markup.contains("Previous: <a href=\"card:a\">alpha</a>"));
    assert(markup.contains("Next: <a href=\"card:z\">zulu</a>"));
}

private void test_compact_structure_markup_cross_project_parent_is_shown_but_children_filtered() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("sel", "p1", "Selected", 20, "parent-p2", 20));
    cards.add(card("parent-p2", "p2", "Parent 2", 10, null, 10));
    cards.add(card("child-p2", "p2", "Child 2", 10, "sel", 10));

    var markup = controller.compact_structure_markup(project, cards[0], cards);
    assert(markup.contains("Parent:"));
    assert(!markup.contains("Children:"));
}

private void test_compact_structure_markup_project_none() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    var markup = controller.compact_structure_markup(null, null, cards);
    assert(markup == "Project: None");
}

private void test_compact_structure_markup_includes_parent_line() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("parent", "p1", "Parent", 10, null, 10));
    cards.add(card("sel", "p1", "Selected", 20, "parent", 20));

    var markup = controller.compact_structure_markup(project, cards[1], cards);
    assert(markup.contains("Parent:"));
}

private void test_compact_structure_markup_escapes_and_ellipsizes_links() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "Project <Unsafe>", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("sel", "p1", "Selected", 10, null, 10));
    cards.add(card("child", "p1", "12345678901234567890123456789012345678901234567890", 20, "sel", 20));

    var markup = controller.compact_structure_markup(project, cards[0], cards);
    assert(markup.contains("&lt;Unsafe&gt;"));
    assert(markup.contains("..."));
    assert(markup.contains("href=\"card:child\""));
}

private void test_compact_structure_markup_children_are_space_separated() {
    var controller = new ConnectionsController();
    var project = new Project("p1", "My Project", "plain", "/tmp/p1", 1, 1);
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("sel", "p1", "Selected", 10, null, 10));
    cards.add(card("child-a", "p1", "Child A", 10, "sel", 20));
    cards.add(card("child-b", "p1", "Child B", 20, "sel", 30));

    var markup = controller.compact_structure_markup(project, cards[0], cards);
    assert(markup.contains(
        "Children: <a href=\"card:child-a\">Child A</a> <a href=\"card:child-b\">Child B</a>"
    ));
}

private void test_list_available_link_kinds_null_settings_defaults() {
    var controller = new ConnectionsController();
    var kinds = controller.list_available_link_kinds(null);
    assert(kinds.size == 5);
    assert(kinds[0] == "ref");
    assert(kinds[1] == "depends_on");
}

private void test_list_available_link_kinds_merges_custom_kinds_from_settings() {
    var controller = new ConnectionsController();
    var settings = AppSettings.open_or_null();
    if (settings == null) {
        assert(true);
        return;
    }

    string[] original = settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    try {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, {"  ", "custom", "ref", "my_kind", "my_kind"});
        var kinds = controller.list_available_link_kinds(settings);
        assert(kinds.contains("ref"));
        assert(kinds.contains("depends_on"));
        assert(kinds.contains("my_kind"));
        int count = 0;
        foreach (var item in kinds) {
            if (item == "my_kind") {
                count++;
            }
        }
        assert(count == 1);
    } finally {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, original);
    }
}

private void test_remember_custom_link_kind_with_settings() {
    var controller = new ConnectionsController();
    var settings = AppSettings.open_or_null();
    if (settings == null) {
        assert(true);
        return;
    }

    string[] original = settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    try {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, {"foo"});
        controller.remember_custom_link_kind(settings, "bar");
        var stored = new Gee.ArrayList<string>();
        foreach (var value in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            stored.add(value);
        }
        assert(stored.contains("foo"));
        assert(stored.contains("bar"));

        controller.remember_custom_link_kind(settings, "ref");
        controller.remember_custom_link_kind(settings, "custom");
        controller.remember_custom_link_kind(settings, "   ");
        var stored_after = new Gee.ArrayList<string>();
        foreach (var value in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            stored_after.add(value);
        }
        assert(!stored_after.contains("ref"));
        assert(!stored_after.contains("custom"));
    } finally {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, original);
    }
}

private void test_remember_custom_link_kind_filters_existing_entries_via_continue_path() {
    var controller = new ConnectionsController();
    var settings = AppSettings.open_or_null();
    if (settings == null) {
        assert(true);
        return;
    }

    string[] original = settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    try {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, {"ref", "blocks", "custom", "  ", "dup", "dup", "ok"});
        controller.remember_custom_link_kind(settings, "new_kind");

        var stored = new Gee.ArrayList<string>();
        foreach (var value in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            stored.add(value);
        }

        assert(!stored.contains("ref"));
        assert(!stored.contains("blocks"));
        assert(!stored.contains("custom"));
        assert(stored.contains("dup"));
        assert(stored.contains("ok"));
        assert(stored.contains("new_kind"));
        int dup_count = 0;
        foreach (var item in stored) {
            if (item == "dup") {
                dup_count++;
            }
        }
        assert(dup_count == 1);
    } finally {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, original);
    }
}

private void test_remember_custom_link_kind_duplicate_cleaned_returns_early() {
    var controller = new ConnectionsController();
    var settings = AppSettings.open_or_null();
    if (settings == null) {
        assert(true);
        return;
    }

    string[] original = settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    try {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, {"alpha", "beta"});
        controller.remember_custom_link_kind(settings, "  alpha  ");

        var stored = new Gee.ArrayList<string>();
        foreach (var value in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            stored.add(value);
        }
        assert(stored.size == 2);
        assert(stored[0] == "alpha");
        assert(stored[1] == "beta");
    } finally {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, original);
    }
}

private void test_remember_custom_link_kind_limits_to_20_entries() {
    var controller = new ConnectionsController();
    var settings = AppSettings.open_or_null();
    if (settings == null) {
        assert(true);
        return;
    }

    string[] original = settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    try {
        string[] seeded = new string[20];
        for (int i = 0; i < 20; i++) {
            seeded[i] = "k%d".printf(i);
        }
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, seeded);
        controller.remember_custom_link_kind(settings, "k20");

        var stored = new Gee.ArrayList<string>();
        foreach (var value in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            stored.add(value);
        }
        assert(stored.size == 20);
        assert(!stored.contains("k0"));
        assert(stored.contains("k20"));
    } finally {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, original);
    }
}

private void test_remember_custom_link_kind_null_settings_noop() {
    var controller = new ConnectionsController();
    controller.remember_custom_link_kind(null, "anything");
    assert(true);
}

private void test_load_graph_links_api_unavailable() {
    var controller = new ConnectionsController();
    bool done = false;
    ConnectionsGraphLoadResult? out_result = null;
    controller.load_graph_links.begin(null, null, (obj, res) => {
        out_result = controller.load_graph_links.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(!out_result.success);
    assert(out_result.outgoing_empty_text == "API unavailable.");
    assert(out_result.backlinks_empty_text == "API unavailable.");
}

private void test_load_graph_links_no_selected_card() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    bool done = false;
    ConnectionsGraphLoadResult? out_result = null;
    controller.load_graph_links.begin(api, null, (obj, res) => {
        out_result = controller.load_graph_links.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(!out_result.success);
    assert(out_result.outgoing_empty_text == "Select a card to view graph links.");
    assert(out_result.backlinks_empty_text == "Select a card to view graph links.");
}

private void test_load_graph_links_success() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.card_links.add(new CardLink("a", "b", "card", "ref", null, 1));
    api.card_backlinks.add(new CardLink("c", "a", "card", "depends_on", null, 1));
    var selected = card("a", "p1", "A", 1);

    bool done = false;
    ConnectionsGraphLoadResult? out_result = null;
    controller.load_graph_links.begin(api, selected, (obj, res) => {
        out_result = controller.load_graph_links.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(out_result.success);
    assert(out_result.outgoing != null && out_result.outgoing.size == 1);
    assert(out_result.backlinks != null && out_result.backlinks.size == 1);
    assert(api.list_card_links_calls == 1);
    assert(api.list_card_backlinks_calls == 1);
}

private void test_load_graph_links_failure() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_list_card_links = true;
    var selected = card("a", "p1", "A", 1);

    bool done = false;
    ConnectionsGraphLoadResult? out_result = null;
    controller.load_graph_links.begin(api, selected, (obj, res) => {
        out_result = controller.load_graph_links.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(!out_result.success);
    assert(out_result.outgoing_empty_text == "Failed to load outgoing links.");
    assert(out_result.backlinks_empty_text == "Failed to load backlinks.");
    assert(out_result.debug_message.contains("Graph links refresh failed"));
}

private void test_update_graph_link_flow_kind_changed() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var old_link = new CardLink("a", "b", "card", "ref", null, 1);

    bool done = false;
    ConnectionsMutationResult? out_result = null;
    controller.update_graph_link_flow.begin(api, old_link, "depends_on", "why", false, null, (obj, res) => {
        out_result = controller.update_graph_link_flow.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(out_result.success);
    assert(out_result.toast_message == "Graph link updated.");
    assert(out_result.should_refresh);
    assert(api.create_card_link_calls == 1);
    assert(api.delete_card_link_calls == 1);
}

private void test_update_graph_link_flow_same_kind_create_only() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var old_link = new CardLink("a", "b", "card", "ref", null, 1);

    bool done = false;
    ConnectionsMutationResult? out_result = null;
    controller.update_graph_link_flow.begin(api, old_link, "ref", null, false, null, (obj, res) => {
        out_result = controller.update_graph_link_flow.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(out_result.success);
    assert(api.create_card_link_calls == 1);
    assert(api.delete_card_link_calls == 0);
}

private void test_update_graph_link_flow_create_error() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_create_card_link = true;
    var old_link = new CardLink("a", "b", "card", "ref", null, 1);

    bool done = false;
    ConnectionsMutationResult? out_result = null;
    controller.update_graph_link_flow.begin(api, old_link, "ref", null, false, null, (obj, res) => {
        out_result = controller.update_graph_link_flow.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(!out_result.success);
    assert(out_result.error_title == "Failed to edit graph link");
    assert(out_result.error_details.contains("create card link failed"));
}

private void test_delete_graph_link_flow_success() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    var link = new CardLink("a", "b", "card", "ref", null, 1);

    bool done = false;
    ConnectionsMutationResult? out_result = null;
    controller.delete_graph_link_flow.begin(api, link, (obj, res) => {
        out_result = controller.delete_graph_link_flow.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(out_result.success);
    assert(out_result.toast_message == "Graph link deleted.");
    assert(api.delete_card_link_calls == 1);
}

private void test_delete_graph_link_flow_error() {
    var controller = new ConnectionsController();
    var api = new HolderLinuxTests.MainControllerFakeApi();
    api.fail_delete_card_link = true;
    var link = new CardLink("a", "b", "card", "ref", null, 1);

    bool done = false;
    ConnectionsMutationResult? out_result = null;
    controller.delete_graph_link_flow.begin(api, link, (obj, res) => {
        out_result = controller.delete_graph_link_flow.end(res);
        done = true;
    });
    assert(wait_until_true(() => done));
    assert(out_result != null);
    assert(!out_result.success);
    assert(out_result.error_title == "Failed to delete graph link");
    assert(out_result.error_details.contains("delete card link failed"));
}

private void test_has_graph_link_targets() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    var selected = card("a", "p1", "A", 1);
    cards.add(selected);
    assert(!controller.has_graph_link_targets(selected, cards));

    cards.add(card("b", "p2", "B", 1));
    assert(!controller.has_graph_link_targets(selected, cards));

    cards.add(card("c", "p1", "C", 1));
    assert(controller.has_graph_link_targets(selected, cards));
    assert(!controller.has_graph_link_targets(null, cards));
}

private void test_build_graph_link_target_options() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    var selected = card("a", "p1", "A", 1);
    cards.add(selected);
    cards.add(card("b", "p1", "B", 1));
    cards.add(card("c", "p2", "C", 1));

    var options = controller.build_graph_link_target_options(selected, cards);
    assert(options.size == 1);
    assert(options[0].card_id == "b");
    assert(options[0].display_text == "B (b)");

    var none = controller.build_graph_link_target_options(null, cards);
    assert(none.size == 0);
}

private void test_title_for_card_id() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("a", "p1", "Alpha", 1));

    assert(controller.title_for_card_id("a", cards) == "Alpha");
    assert(controller.title_for_card_id("missing", cards) == "missing");
}

private void test_group_links_by_kind_preserves_first_seen_order() {
    var controller = new ConnectionsController();
    var links = new Gee.ArrayList<CardLink>();
    links.add(new CardLink("a", "b", "card", "depends_on", null, 1));
    links.add(new CardLink("a", "c", "card", "", null, 2));
    links.add(new CardLink("a", "d", "card", "depends_on", null, 3));
    links.add(new CardLink("a", "e", "card", "ref", null, 4));

    var groups = controller.group_links_by_kind(links);
    assert(groups.size == 2);
    assert(groups[0].kind == "depends_on");
    assert(groups[0].links.size == 2);
    assert(groups[1].kind == "ref");
    assert(groups[1].links.size == 2);
}

private void test_resolve_link_action_card_project_ilink_and_unknown() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("a", "p1", "Alpha", 1));
    cards.add(card("b", "p1", "Beta", 1));

    var card_action = controller.resolve_link_action("card:a", "p1", cards);
    assert(card_action.handled);
    assert(card_action.select_card);
    assert(card_action.target_id == "a");

    var project_action = controller.resolve_link_action("project:p2", "p1", cards);
    assert(project_action.handled);
    assert(project_action.select_project);
    assert(project_action.target_id == "p2");

    var ilink_action = controller.resolve_link_action("ilink:Beta", "p1", cards);
    assert(ilink_action.handled);
    assert(ilink_action.select_card);
    assert(ilink_action.target_id == "b");

    var ilink_missing = controller.resolve_link_action("ilink:Missing", "p1", cards);
    assert(ilink_missing.handled);
    assert(!ilink_missing.select_card);
    assert(!ilink_missing.select_project);

    var unknown = controller.resolve_link_action("mailto:test@example.com", "p1", cards);
    assert(!unknown.handled);
}

private void test_internal_links_refresh_target_and_normalized_kind_helpers() {
    var controller = new ConnectionsController();

    var empty = new Gee.ArrayList<string>();
    assert(controller.internal_links_equal(empty, null));

    var current = new Gee.ArrayList<string>();
    current.add("a");
    assert(!controller.internal_links_equal(current, null));

    var mismatch = new Gee.ArrayList<string>();
    mismatch.add("b");
    assert(!controller.internal_links_equal(current, mismatch));

    var project = new Project("p1", "Project", "plain", "/tmp/p1", 1, 1);
    var foreign_card = card("c2", "p2", "Foreign", 1);
    var target = controller.build_graph_refresh_target(false, project, foreign_card, 9);
    assert(target.mode == "project_root");
    assert(target.project_id == "p1");
    assert(target.card_id == "");

    var root_target = controller.build_graph_refresh_target(true, project, null, 3);
    assert(root_target.mode == "projects_root");
    assert(root_target.project_id == "");
    assert(controller.describe_graph_refresh_target(root_target) == "projects_root");

    var none_target = new ConnectionsGraphRefreshTarget("project_root", "", "", 0);
    assert(controller.describe_graph_refresh_target(none_target) == "project:none");
    assert(controller.format_graph_refresh_debug_event("queued", root_target)
        == "Connections refresh queued: projects_root");

    assert(controller.normalized_link_kind(null) == "ref");
    assert(controller.normalized_link_kind("   ") == "ref");
    assert(controller.normalized_link_kind(" depends_on ") == "depends_on");
}

private void test_graph_structure_helpers_cover_counts_lookup_and_dedup() {
    var controller = new ConnectionsController();
    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("parent", "p1", "Parent", 1));
    cards.add(card("child-a", "p1", "Child A", 1, "parent"));
    cards.add(card("child-b", "p1", "Child B", 2, "parent"));

    assert(controller.child_count_for("parent", cards) == 2);
    assert(controller.find_card_by_id("missing", cards) == null);

    var nodes = new Gee.HashMap<string, ConnectionsBoardNode>();
    var edge_keys = new Gee.HashSet<string>();
    var edges = new Gee.ArrayList<ConnectionsBoardEdge>();

    assert(!controller.add_edge_to_list(edge_keys, edges, "a", "a", "ref", false));
    assert(controller.add_edge_to_list(edge_keys, edges, "a", "b", "ref", false));
    assert(!controller.add_edge_to_list(edge_keys, edges, "a", "b", "ref", false));

    controller.add_board_edge(nodes, edge_keys, edges, "a", "b", "ref", false, cards);
    assert(nodes.size == 0);

    controller.add_board_edge(nodes, edge_keys, edges, "parent", "child-a", "child", true, cards);
    assert(nodes.has_key("parent"));
    assert(nodes.has_key("child-a"));
    assert(nodes.get("parent").child_count == 2);
}

private void test_build_structural_edges_for_selected_and_project() {
    var controller = new ConnectionsController();
    var project_cards = new Gee.ArrayList<CardSummary>();
    project_cards.add(card("parent", "p1", "Parent", 1));
    project_cards.add(card("prev", "p1", "Prev", 1, "parent", 10));
    project_cards.add(card("sel", "p1", "Selected", 2, "parent", 20));
    project_cards.add(card("next", "p1", "Next", 3, "parent", 30));
    project_cards.add(card("child", "p1", "Child", 1, "sel", 40));

    var selected_edges = controller.build_structural_edges_for_selected(project_cards[2], project_cards);
    assert(selected_edges.size == 4);
    assert(selected_edges[0].kind == "next");
    assert(selected_edges[0].from_card_id == "prev");
    assert(selected_edges[1].to_card_id == "next");
    assert(selected_edges[2].kind == "child");
    assert(selected_edges[2].from_card_id == "parent");
    assert(selected_edges[3].from_card_id == "sel");
    assert(selected_edges[3].to_card_id == "child");

    var project_edges = controller.build_structural_edges_for_project(project_cards);
    bool found_parent_child = false;
    bool found_sibling_next = false;
    foreach (var edge in project_edges) {
        if (edge.from_card_id == "parent" && edge.to_card_id == "sel" && edge.kind == "child") {
            found_parent_child = true;
        }
        if (edge.from_card_id == "prev" && edge.to_card_id == "sel" && edge.kind == "next") {
            found_sibling_next = true;
        }
    }
    assert(found_parent_child);
    assert(found_sibling_next);
}

private void test_layout_helpers_and_target_board_height_thresholds() {
    var controller = new ConnectionsController();

    var card_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    card_nodes.add(new ConnectionsBoardNode("center", "Center"));
    card_nodes.add(new ConnectionsBoardNode("n1", "N1"));
    card_nodes.add(new ConnectionsBoardNode("n2", "N2"));
    card_nodes.add(new ConnectionsBoardNode("n3", "N3"));
    card_nodes.add(new ConnectionsBoardNode("n4", "N4"));
    card_nodes.add(new ConnectionsBoardNode("n5", "N5"));
    controller.layout_card_mode_nodes("center", card_nodes, 800, 180, 90, 40, 600);
    assert(card_nodes[0].x > 0);
    assert(card_nodes[1].x != card_nodes[0].x || card_nodes[1].y != card_nodes[0].y);

    var empty_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    controller.layout_project_mode_nodes(empty_nodes, 24, 180, 90);
    assert(empty_nodes.size == 0);

    var grid_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    for (int i = 0; i < 5; i++) {
        grid_nodes.add(new ConnectionsBoardNode("g%d".printf(i), "G%d".printf(i)));
    }
    controller.layout_project_mode_nodes(grid_nodes, 24, 180, 90);
    assert(grid_nodes[4].y > grid_nodes[0].y);

    var spread_nodes = new Gee.ArrayList<ConnectionsBoardNode>();
    spread_nodes.add(new ConnectionsBoardNode("a", "A", 0, 0, 0, 790));
    spread_nodes.add(new ConnectionsBoardNode("b", "B", 0, 0, 0, 790));
    controller.spread_nodes_to_avoid_overlap(spread_nodes, 180, 90);
    assert(spread_nodes[1].x > 0 || spread_nodes[1].y != 790);

    assert(controller.target_board_height_for_count(8) == 430);
    assert(controller.target_board_height_for_count(14) == 560);
    assert(controller.target_board_height_for_count(15) == 680);
}

private void test_count_summary_and_increment_helpers() {
    var controller = new ConnectionsController();
    var counts = new Gee.HashMap<string, int>();

    controller.increment_count(counts, "ref");
    controller.increment_count(counts, "ref");
    controller.increment_count(counts, "child");

    var summary = controller.format_counts_summary(counts);
    assert(summary.contains("• ref: 2"));
    assert(summary.contains("• child: 1"));
    assert(summary.index_of("• ref: 2") < summary.index_of("• child: 1"));

    var tied = new Gee.HashMap<string, int>();
    tied.set("beta", 1);
    tied.set("alpha", 1);
    var tied_summary = controller.format_counts_summary(tied);
    assert(tied_summary.index_of("• alpha: 1") < tied_summary.index_of("• beta: 1"));
}

private void test_update_delete_and_resolve_link_action_ignored_paths() {
    var controller = new ConnectionsController();

    bool done_update = false;
    ConnectionsMutationResult? update_result = null;
    controller.update_graph_link_flow.begin(null,
                                            new CardLink("a", "b", "card", "ref", null, 1),
                                            "custom_kind",
                                            null,
                                            true,
                                            null,
                                            (obj, res) => {
        update_result = controller.update_graph_link_flow.end(res);
        done_update = true;
    });
    assert(wait_until_true(() => done_update));
    assert(update_result != null);
    assert(!update_result.success);
    assert(update_result.ignored);

    bool done_delete = false;
    ConnectionsMutationResult? delete_result = null;
    controller.delete_graph_link_flow.begin(null, new CardLink("a", "b", "card", "ref", null, 1), (obj, res) => {
        delete_result = controller.delete_graph_link_flow.end(res);
        done_delete = true;
    });
    assert(wait_until_true(() => done_delete));
    assert(delete_result != null);
    assert(!delete_result.success);
    assert(delete_result.ignored);

    var cards = new Gee.ArrayList<CardSummary>();
    cards.add(card("a", "p1", "Alpha", 1));
    assert(!controller.resolve_link_action("", "p1", cards).handled);
    assert(!controller.resolve_link_action("card:%", "p1", cards).handled);
    assert(!controller.resolve_link_action("project:%", "p1", cards).handled);
    assert(!controller.resolve_link_action("ilink:%", "p1", cards).handled);
}

private void test_update_graph_link_flow_remember_kind_persists_custom_kind() {
    var controller = new ConnectionsController();
    var settings = AppSettings.open_or_null();
    if (settings == null) {
        assert(true);
        return;
    }

    string[] original = settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS);
    try {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, {});
        var api = new HolderLinuxTests.MainControllerFakeApi();
        var old_link = new CardLink("a", "b", "card", "ref", null, 1);

        bool done = false;
        ConnectionsMutationResult? out_result = null;
        controller.update_graph_link_flow.begin(api, old_link, "custom_kind", null, true, settings, (obj, res) => {
            out_result = controller.update_graph_link_flow.end(res);
            done = true;
        });
        assert(wait_until_true(() => done));
        assert(out_result != null);
        assert(out_result.success);

        var stored = new Gee.ArrayList<string>();
        foreach (var value in settings.get_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS)) {
            stored.add(value);
        }
        assert(stored.contains("custom_kind"));
    } finally {
        settings.set_strv(AppSettings.KEY_CUSTOM_CARD_LINK_KINDS, original);
    }
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/connections/ellipsize_title", test_ellipsize_title);
    Test.add_func("/holder/connections/ellipsize_title_exact_47_is_ellipsized",
                  test_ellipsize_title_exact_47_is_ellipsized);
    Test.add_func("/holder/connections/ellipsize_title_null_returns_empty",
                  test_ellipsize_title_null_returns_empty);
    Test.add_func("/holder/connections/ellipsize_title_cutoff_negative_returns_original_title",
                  test_ellipsize_title_cutoff_negative_returns_original_title);
    Test.add_func("/holder/connections/resolve_internal_link", test_resolve_internal_link);
    Test.add_func("/holder/connections/resolve_internal_link_prefers_exact_title_before_casefold",
                  test_resolve_internal_link_prefers_exact_title_before_casefold);
    Test.add_func("/holder/connections/resolve_internal_link_empty_inputs",
                  test_resolve_internal_link_empty_inputs);
    Test.add_func("/holder/connections/compact_structure_markup", test_compact_structure_markup);
    Test.add_func("/holder/connections/compact_structure_markup_sibling_order_uses_updated_then_title",
                  test_compact_structure_markup_sibling_order_uses_updated_then_title);
    Test.add_func("/holder/connections/compact_structure_markup_sibling_order_updated_at_desc_returns_minus_one_path",
                  test_compact_structure_markup_sibling_order_updated_at_desc_returns_minus_one_path);
    Test.add_func("/holder/connections/compact_structure_markup_sibling_order_uses_sort_key_first",
                  test_compact_structure_markup_sibling_order_uses_sort_key_first);
    Test.add_func("/holder/connections/compact_structure_markup_sibling_order_tiebreaks_by_title",
                  test_compact_structure_markup_sibling_order_tiebreaks_by_title);
    Test.add_func("/holder/connections/compact_structure_markup_cross_project_parent_is_shown_but_children_filtered",
                  test_compact_structure_markup_cross_project_parent_is_shown_but_children_filtered);
    Test.add_func("/holder/connections/compact_structure_markup_project_none",
                  test_compact_structure_markup_project_none);
    Test.add_func("/holder/connections/compact_structure_markup_includes_parent_line",
                  test_compact_structure_markup_includes_parent_line);
    Test.add_func("/holder/connections/compact_structure_markup_escapes_and_ellipsizes_links",
                  test_compact_structure_markup_escapes_and_ellipsizes_links);
    Test.add_func("/holder/connections/compact_structure_markup_children_are_space_separated",
                  test_compact_structure_markup_children_are_space_separated);
    Test.add_func("/holder/connections/list_available_link_kinds_null_settings_defaults",
                  test_list_available_link_kinds_null_settings_defaults);
    Test.add_func("/holder/connections/list_available_link_kinds_merges_custom_kinds_from_settings",
                  test_list_available_link_kinds_merges_custom_kinds_from_settings);
    Test.add_func("/holder/connections/remember_custom_link_kind_with_settings",
                  test_remember_custom_link_kind_with_settings);
    Test.add_func("/holder/connections/remember_custom_link_kind_filters_existing_entries_via_continue_path",
                  test_remember_custom_link_kind_filters_existing_entries_via_continue_path);
    Test.add_func("/holder/connections/remember_custom_link_kind_duplicate_cleaned_returns_early",
                  test_remember_custom_link_kind_duplicate_cleaned_returns_early);
    Test.add_func("/holder/connections/remember_custom_link_kind_limits_to_20_entries",
                  test_remember_custom_link_kind_limits_to_20_entries);
    Test.add_func("/holder/connections/remember_custom_link_kind_null_settings_noop",
                  test_remember_custom_link_kind_null_settings_noop);
    Test.add_func("/holder/connections/load_graph_links_api_unavailable",
                  test_load_graph_links_api_unavailable);
    Test.add_func("/holder/connections/load_graph_links_no_selected_card",
                  test_load_graph_links_no_selected_card);
    Test.add_func("/holder/connections/load_graph_links_success",
                  test_load_graph_links_success);
    Test.add_func("/holder/connections/load_graph_links_failure",
                  test_load_graph_links_failure);
    Test.add_func("/holder/connections/update_graph_link_flow_kind_changed",
                  test_update_graph_link_flow_kind_changed);
    Test.add_func("/holder/connections/update_graph_link_flow_same_kind_create_only",
                  test_update_graph_link_flow_same_kind_create_only);
    Test.add_func("/holder/connections/update_graph_link_flow_create_error",
                  test_update_graph_link_flow_create_error);
    Test.add_func("/holder/connections/delete_graph_link_flow_success",
                  test_delete_graph_link_flow_success);
    Test.add_func("/holder/connections/delete_graph_link_flow_error",
                  test_delete_graph_link_flow_error);
    Test.add_func("/holder/connections/has_graph_link_targets",
                  test_has_graph_link_targets);
    Test.add_func("/holder/connections/build_graph_link_target_options",
                  test_build_graph_link_target_options);
    Test.add_func("/holder/connections/title_for_card_id",
                  test_title_for_card_id);
    Test.add_func("/holder/connections/group_links_by_kind_preserves_first_seen_order",
                  test_group_links_by_kind_preserves_first_seen_order);
    Test.add_func("/holder/connections/resolve_link_action_card_project_ilink_and_unknown",
                  test_resolve_link_action_card_project_ilink_and_unknown);
    Test.add_func("/holder/connections/internal_links_refresh_target_and_normalized_kind_helpers",
                  test_internal_links_refresh_target_and_normalized_kind_helpers);
    Test.add_func("/holder/connections/graph_structure_helpers_cover_counts_lookup_and_dedup",
                  test_graph_structure_helpers_cover_counts_lookup_and_dedup);
    Test.add_func("/holder/connections/build_structural_edges_for_selected_and_project",
                  test_build_structural_edges_for_selected_and_project);
    Test.add_func("/holder/connections/layout_helpers_and_target_board_height_thresholds",
                  test_layout_helpers_and_target_board_height_thresholds);
    Test.add_func("/holder/connections/count_summary_and_increment_helpers",
                  test_count_summary_and_increment_helpers);
    Test.add_func("/holder/connections/update_delete_and_resolve_link_action_ignored_paths",
                  test_update_delete_and_resolve_link_action_ignored_paths);
    Test.add_func("/holder/connections/update_graph_link_flow_remember_kind_persists_custom_kind",
                  test_update_graph_link_flow_remember_kind_persists_custom_kind);
    return Test.run();
}

}
