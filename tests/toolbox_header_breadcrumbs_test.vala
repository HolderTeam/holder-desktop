using GLib;

namespace HolderLinuxTests {

// ToolboxPane.refresh_header_breadcrumbs' selection fallback, exactly as it was written inline
// before it moved into ToolboxHeaderBreadcrumbs.
private Gee.ArrayList<HolderLinux.NavigationBreadcrumbSegment> reference_from_selection(
    HolderLinux.Project? selected_project,
    HolderLinux.CardSummary? selected_card,
    string? page_title
) {
    string tool_name = "Tool";
    if (page_title != null && page_title.strip().length > 0) {
        tool_name = page_title;
    }
    string project_name = selected_project != null && selected_project.name.strip().length > 0
        ? selected_project.name
        : "(none)";
    string card_name = selected_card != null &&
        (selected_project == null || selected_card.project_id == selected_project.project_id) &&
        selected_card.title.strip().length > 0
        ? selected_card.title
        : "Overview";

    var segments = new Gee.ArrayList<HolderLinux.NavigationBreadcrumbSegment>();
    segments.add(new HolderLinux.NavigationBreadcrumbSegment(tool_name, true, true, 0));
    segments.add(new HolderLinux.NavigationBreadcrumbSegment(project_name, false, selected_project != null, 1));
    segments.add(new HolderLinux.NavigationBreadcrumbSegment(card_name, false, selected_card != null, 2));
    return segments;
}

private HolderLinux.Project make_project(string id, string name) {
    return new HolderLinux.Project(id, name, "encrypted_git", "/tmp/" + id, 10, 10);
}

private HolderLinux.CardSummary make_card(string id, string project_id, string title) {
    return new HolderLinux.CardSummary(id, project_id, title, id + ".md", 1024.0, null, 1, 1);
}

private void assert_same_segments(Gee.ArrayList<HolderLinux.NavigationBreadcrumbSegment> actual,
                                  Gee.ArrayList<HolderLinux.NavigationBreadcrumbSegment> expected) {
    assert(actual.size == 3);
    assert(actual.size == expected.size);
    for (int i = 0; i < actual.size; i++) {
        assert(actual[i].label == expected[i].label);
        assert(actual[i].emphasized == expected[i].emphasized);
        assert(actual[i].clickable == expected[i].clickable);
        assert(actual[i].index == expected[i].index);
        assert(actual[i].index == i);
    }
}

private void test_from_selection_matches_the_original_inline_logic() {
    string?[] titles = { null, "", "   ", "Tags", "  Milestones  " };
    HolderLinux.Project?[] projects = {
        null, make_project("p1", "Alpha"), make_project("p1", ""), make_project("p1", "   ")
    };
    HolderLinux.CardSummary?[] cards = {
        null,
        make_card("c1", "p1", "First"),
        make_card("c2", "p2", "Elsewhere"),
        make_card("c3", "p1", ""),
        make_card("c4", "p1", "  ")
    };

    int combinations = 0;
    foreach (var title in titles) {
        foreach (var project in projects) {
            foreach (var card in cards) {
                assert_same_segments(
                    HolderLinux.ToolboxHeaderBreadcrumbs.from_selection(title, project, card),
                    reference_from_selection(project, card, title)
                );
                combinations++;
            }
        }
    }
    assert(combinations == 5 * 4 * 5);
}

private void test_from_selection_spot_checks() {
    var none = HolderLinux.ToolboxHeaderBreadcrumbs.from_selection(null, null, null);
    assert(none[0].label == "Tool" && none[0].emphasized && none[0].clickable);
    assert(none[1].label == "(none)" && !none[1].clickable);
    assert(none[2].label == "Overview" && !none[2].clickable);

    var project = make_project("p1", "Alpha");
    var mismatched = HolderLinux.ToolboxHeaderBreadcrumbs.from_selection(
        "History", project, make_card("c1", "other", "Stale")
    );
    assert(mismatched[0].label == "History");
    assert(mismatched[1].label == "Alpha" && mismatched[1].clickable);
    // A card from another project is not shown, but the segment is still clickable.
    assert(mismatched[2].label == "Overview" && mismatched[2].clickable);

    var orphan_card = HolderLinux.ToolboxHeaderBreadcrumbs.from_selection(
        null, null, make_card("c1", "p9", "Loose")
    );
    assert(orphan_card[1].label == "(none)" && !orphan_card[1].clickable);
    assert(orphan_card[2].label == "Loose" && orphan_card[2].clickable);
}

private void test_from_snapshot_uses_labels_and_ids() {
    var scoped = new HolderLinux.ToolScopeSnapshot("history", "History", "p1", "Alpha", "c1", "First");
    var segments = HolderLinux.ToolboxHeaderBreadcrumbs.from_snapshot(scoped);
    assert(segments.size == 3);
    assert(segments[0].label == "History" && segments[0].emphasized && segments[0].clickable);
    assert(segments[0].index == 0);
    assert(segments[1].label == "Alpha" && !segments[1].emphasized && segments[1].clickable);
    assert(segments[1].index == 1);
    assert(segments[2].label == "First" && !segments[2].emphasized && segments[2].clickable);
    assert(segments[2].index == 2);

    var unscoped = new HolderLinux.ToolScopeSnapshot("history", "History", null, "Projects", null, "Overview");
    var loose = HolderLinux.ToolboxHeaderBreadcrumbs.from_snapshot(unscoped);
    assert(loose[1].label == "Projects" && !loose[1].clickable);
    assert(loose[2].label == "Overview" && !loose[2].clickable);
    assert(loose[0].clickable);
}

private void test_selection_matches_requires_both_ids() {
    var project = make_project("p1", "Alpha");
    var card = make_card("c1", "p1", "First");
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.selection_matches(project, card, "p1", "c1"));
    assert(!HolderLinux.ToolboxHeaderBreadcrumbs.selection_matches(null, card, "p1", "c1"));
    assert(!HolderLinux.ToolboxHeaderBreadcrumbs.selection_matches(project, null, "p1", "c1"));
    assert(!HolderLinux.ToolboxHeaderBreadcrumbs.selection_matches(project, card, "p2", "c1"));
    assert(!HolderLinux.ToolboxHeaderBreadcrumbs.selection_matches(project, card, "p1", "c2"));
}

private void test_tool_id_for_page_falls_back_when_missing_or_blank() {
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.tool_id_for_page(null) == "tool");
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.tool_id_for_page("") == "tool");
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.tool_id_for_page("   ") == "tool");
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.tool_id_for_page("history") == "history");
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.DEFAULT_TOOL_ID == "tool");
    assert(HolderLinux.ToolboxHeaderBreadcrumbs.DEFAULT_TOOL_LABEL == "Tool");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/toolbox-header-breadcrumbs/from-selection-matches-original",
                  test_from_selection_matches_the_original_inline_logic);
    Test.add_func("/holder/toolbox-header-breadcrumbs/from-selection-spot-checks",
                  test_from_selection_spot_checks);
    Test.add_func("/holder/toolbox-header-breadcrumbs/from-snapshot",
                  test_from_snapshot_uses_labels_and_ids);
    Test.add_func("/holder/toolbox-header-breadcrumbs/selection-matches",
                  test_selection_matches_requires_both_ids);
    Test.add_func("/holder/toolbox-header-breadcrumbs/tool-id-for-page",
                  test_tool_id_for_page_falls_back_when_missing_or_blank);
    return Test.run();
}

}
