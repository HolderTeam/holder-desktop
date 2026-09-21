using GLib;

namespace HolderLinuxTests {

// The panel-width bookkeeping exactly as WorkspacePane wrote it inline before it moved into
// PanelWidthTracker (once per panel, differing only in which clamp/initial-position it used).
private class ReferencePanelState : Object {
    public bool ai_panel { get; construct; }
    public int last_width { get; set; default = -1; }
    public bool user_set { get; set; default = false; }
    public bool suppress { get; set; default = false; }

    public ReferencePanelState(bool ai_panel) {
        Object(ai_panel: ai_panel);
    }

    private int clamp(int width) {
        return ai_panel
            ? HolderLinux.WorkspaceLayout.clamp_ai_panel_width(width)
            : HolderLinux.WorkspaceLayout.clamp_asset_preview_width(width);
    }

    public void set_width(int width) {
        if (width > 0) {
            last_width = clamp(width);
            user_set = true;
        } else {
            last_width = -1;
            user_set = false;
        }
    }

    public int width_for_persist() {
        if (!user_set || last_width <= 0) {
            return 0;
        }
        return clamp(last_width);
    }

    public void on_position_changed(bool visible, int split_width, int position) {
        if (suppress || !visible) {
            return;
        }
        if (split_width <= 0) {
            return;
        }
        var panel_width = split_width - position;
        if (panel_width <= 0) {
            return;
        }
        last_width = clamp(panel_width);
        user_set = true;
    }

    public int initial_position(int split_width, int min_start, int max_start) {
        if (ai_panel) {
            return HolderLinux.WorkspaceLayout.initial_ai_panel_position(
                split_width, last_width, user_set, min_start, max_start
            );
        }
        return HolderLinux.WorkspaceLayout.initial_asset_preview_position(
            split_width, last_width, user_set, min_start, max_start
        );
    }
}

private void assert_same_state(ReferencePanelState reference, HolderLinux.PanelWidthTracker tracker) {
    assert(tracker.last_width == reference.last_width);
    assert(tracker.user_set == reference.user_set);
    assert(tracker.suppress_persist == reference.suppress);
    assert(tracker.width_for_persist() == reference.width_for_persist());
}

private uint32 next_random(ref uint32 state) {
    state = state * 1664525 + 1013904223;
    return state >> 8;
}

private void run_random_operations(HolderLinux.WorkspacePanel panel) {
    var is_ai = panel == HolderLinux.WorkspacePanel.AI_PANEL;
    var reference = new ReferencePanelState(is_ai);
    var tracker = new HolderLinux.PanelWidthTracker(panel);
    uint32 seed = is_ai ? 12345 : 67890;
    int[] interesting_widths = { -50, -1, 0, 1, 299, 300, 301, 359, 360, 361, 500, 719, 720, 721, 899, 900, 901, 5000 };

    for (int step = 0; step < 4000; step++) {
        var op = (int) (next_random(ref seed) % 5);
        var pick = interesting_widths[(int) (next_random(ref seed) % interesting_widths.length)];
        var noisy = (int) (next_random(ref seed) % 1600) - 100;
        var width = (next_random(ref seed) % 2 == 0) ? pick : noisy;
        switch (op) {
            case 0:
                reference.set_width(width);
                tracker.set_width(width);
                break;
            case 1:
                var visible = next_random(ref seed) % 4 != 0;
                var split = (next_random(ref seed) % 6 == 0) ? width : (int) (next_random(ref seed) % 2200);
                var position = (int) (next_random(ref seed) % 2400) - 100;
                reference.on_position_changed(visible, split, position);
                tracker.on_position_changed(visible, split, position);
                break;
            case 2:
                var flag = next_random(ref seed) % 2 == 0;
                reference.suppress = flag;
                tracker.suppress_persist = flag;
                break;
            case 3:
                var split_width = (int) (next_random(ref seed) % 2600) - 100;
                var min_start = (int) (next_random(ref seed) % 400);
                var max_start = min_start + (int) (next_random(ref seed) % 1800) - 200;
                assert(tracker.initial_position(split_width, min_start, max_start)
                       == reference.initial_position(split_width, min_start, max_start));
                break;
            default:
                assert(tracker.width_for_persist() == reference.width_for_persist());
                break;
        }
        assert_same_state(reference, tracker);
    }
}

private void test_ai_panel_matches_the_original_inline_logic() {
    run_random_operations(HolderLinux.WorkspacePanel.AI_PANEL);
}

private void test_asset_preview_matches_the_original_inline_logic() {
    run_random_operations(HolderLinux.WorkspacePanel.ASSET_PREVIEW);
}

private void test_starts_unset_and_persists_zero() {
    foreach (var panel in new HolderLinux.WorkspacePanel[] {
        HolderLinux.WorkspacePanel.AI_PANEL, HolderLinux.WorkspacePanel.ASSET_PREVIEW
    }) {
        var tracker = new HolderLinux.PanelWidthTracker(panel);
        assert(tracker.last_width == -1);
        assert(!tracker.user_set);
        assert(!tracker.suppress_persist);
        assert(tracker.width_for_persist() == 0);
    }
}

private void test_set_width_clamps_per_panel_and_zero_resets() {
    var ai = new HolderLinux.PanelWidthTracker(HolderLinux.WorkspacePanel.AI_PANEL);
    ai.set_width(10);
    assert(ai.last_width == HolderLinux.WorkspaceLayout.clamp_ai_panel_width(10));
    assert(ai.user_set);
    ai.set_width(100000);
    assert(ai.last_width == HolderLinux.WorkspaceLayout.clamp_ai_panel_width(100000));
    assert(ai.width_for_persist() == ai.last_width);
    ai.set_width(0);
    assert(ai.last_width == -1);
    assert(!ai.user_set);
    assert(ai.width_for_persist() == 0);
    ai.set_width(-7);
    assert(!ai.user_set);

    var preview = new HolderLinux.PanelWidthTracker(HolderLinux.WorkspacePanel.ASSET_PREVIEW);
    preview.set_width(10);
    assert(preview.last_width == HolderLinux.WorkspaceLayout.clamp_asset_preview_width(10));
    // The two panels have different minimums, so each tracker must use its own clamp.
    assert(HolderLinux.WorkspaceLayout.clamp_asset_preview_width(10)
           != HolderLinux.WorkspaceLayout.clamp_ai_panel_width(10));
}

private void test_position_changes_are_ignored_when_they_should_be() {
    var tracker = new HolderLinux.PanelWidthTracker(HolderLinux.WorkspacePanel.AI_PANEL);

    tracker.on_position_changed(false, 1200, 700);
    assert(!tracker.user_set);

    tracker.on_position_changed(true, 0, 0);
    tracker.on_position_changed(true, -10, 0);
    assert(!tracker.user_set);

    tracker.on_position_changed(true, 1000, 1000);
    tracker.on_position_changed(true, 1000, 1400);
    assert(!tracker.user_set);

    tracker.suppress_persist = true;
    tracker.on_position_changed(true, 1200, 700);
    assert(!tracker.user_set);
    assert(tracker.last_width == -1);

    tracker.suppress_persist = false;
    tracker.on_position_changed(true, 1200, 700);
    assert(tracker.user_set);
    assert(tracker.last_width == HolderLinux.WorkspaceLayout.clamp_ai_panel_width(500));
}

private void test_initial_position_uses_the_saved_width_only_when_user_set() {
    var ai = new HolderLinux.PanelWidthTracker(HolderLinux.WorkspacePanel.AI_PANEL);
    assert(ai.initial_position(1400, 100, 1300)
           == HolderLinux.WorkspaceLayout.initial_ai_panel_position(1400, -1, false, 100, 1300));
    ai.set_width(600);
    assert(ai.initial_position(1400, 100, 1300) == 800);

    var preview = new HolderLinux.PanelWidthTracker(HolderLinux.WorkspacePanel.ASSET_PREVIEW);
    assert(preview.initial_position(1400, 100, 1300)
           == HolderLinux.WorkspaceLayout.initial_asset_preview_position(1400, -1, false, 100, 1300));
    preview.set_width(500);
    assert(preview.initial_position(1400, 100, 1300) == 900);
}

private void test_toolbox_position_stays_within_bounds() {
    // The panel trackers share WorkspaceLayout with the toolbox split.
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(1000, 100, 900) == 500);
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(1000, 600, 900) == 600);
    assert(HolderLinux.WorkspaceLayout.initial_toolbox_position(1000, 100, 300) == 300);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/panel-width-tracker/ai-matches-original",
                  test_ai_panel_matches_the_original_inline_logic);
    Test.add_func("/holder/panel-width-tracker/asset-preview-matches-original",
                  test_asset_preview_matches_the_original_inline_logic);
    Test.add_func("/holder/panel-width-tracker/starts-unset", test_starts_unset_and_persists_zero);
    Test.add_func("/holder/panel-width-tracker/set-width-clamps-and-resets",
                  test_set_width_clamps_per_panel_and_zero_resets);
    Test.add_func("/holder/panel-width-tracker/position-changes-ignored",
                  test_position_changes_are_ignored_when_they_should_be);
    Test.add_func("/holder/panel-width-tracker/initial-position",
                  test_initial_position_uses_the_saved_width_only_when_user_set);
    Test.add_func("/holder/panel-width-tracker/toolbox-position",
                  test_toolbox_position_stays_within_bounds);
    return Test.run();
}

}
