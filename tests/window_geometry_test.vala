private void test_startup_geometry_defaults_without_saved_geometry() {
    var geometry = HolderLinux.WindowGeometry.resolve_startup_geometry(0, 0, false);

    assert(geometry.width == HolderLinux.WindowGeometry.DEFAULT_WINDOW_WIDTH);
    assert(geometry.height == HolderLinux.WindowGeometry.DEFAULT_WINDOW_HEIGHT);
    assert(!geometry.start_maximized);
}

private void test_startup_geometry_cli_size_overrides_saved_geometry() {
    var geometry = HolderLinux.WindowGeometry.resolve_startup_geometry(
        640,
        0,
        true,
        1400,
        900,
        true,
        0
    );

    assert(geometry.width == 640);
    assert(geometry.height == HolderLinux.WindowGeometry.DEFAULT_WINDOW_HEIGHT);
    assert(!geometry.start_maximized);
}

private void test_startup_geometry_uses_saved_geometry() {
    var geometry = HolderLinux.WindowGeometry.resolve_startup_geometry(
        0,
        0,
        true,
        1400,
        900,
        true,
        0
    );

    assert(geometry.width == 1400);
    assert(geometry.height == 900);
    assert(geometry.start_maximized);
}

private void test_startup_geometry_ignores_tiny_saved_size_until_strike_limit() {
    var ignored = HolderLinux.WindowGeometry.resolve_startup_geometry(
        0,
        0,
        true,
        320,
        240,
        false,
        HolderLinux.WindowGeometry.TINY_CLOSE_STRIKE_LIMIT - 1
    );
    var accepted = HolderLinux.WindowGeometry.resolve_startup_geometry(
        0,
        0,
        true,
        320,
        240,
        false,
        HolderLinux.WindowGeometry.TINY_CLOSE_STRIKE_LIMIT
    );

    assert(ignored.width == HolderLinux.WindowGeometry.DEFAULT_WINDOW_WIDTH);
    assert(ignored.height == HolderLinux.WindowGeometry.DEFAULT_WINDOW_HEIGHT);
    assert(accepted.width == 320);
    assert(accepted.height == 240);
}

private void test_sidebar_width_clamps_to_bounds() {
    assert(HolderLinux.WindowGeometry.clamp_sidebar_width(1) ==
           HolderLinux.WindowGeometry.MIN_SIDEBAR_WIDTH);
    assert(HolderLinux.WindowGeometry.clamp_sidebar_width(400) == 400);
    assert(HolderLinux.WindowGeometry.clamp_sidebar_width(2000) ==
           HolderLinux.WindowGeometry.MAX_SIDEBAR_WIDTH);
}

private void test_tiny_size_and_streak_rules() {
    assert(HolderLinux.WindowGeometry.is_tiny_size(
        HolderLinux.WindowGeometry.MIN_RESTORE_WIDTH - 1,
        HolderLinux.WindowGeometry.MIN_RESTORE_HEIGHT
    ));
    assert(HolderLinux.WindowGeometry.is_tiny_size(
        HolderLinux.WindowGeometry.MIN_RESTORE_WIDTH,
        HolderLinux.WindowGeometry.MIN_RESTORE_HEIGHT - 1
    ));
    assert(!HolderLinux.WindowGeometry.is_tiny_size(
        HolderLinux.WindowGeometry.MIN_RESTORE_WIDTH,
        HolderLinux.WindowGeometry.MIN_RESTORE_HEIGHT
    ));

    assert(HolderLinux.WindowGeometry.next_tiny_close_streak(false, 300, 300, 2) == 3);
    assert(HolderLinux.WindowGeometry.next_tiny_close_streak(false, 900, 700, 2) == 0);
    assert(HolderLinux.WindowGeometry.next_tiny_close_streak(true, 300, 300, 2) == 0);
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func(
        "/holder/window-geometry/startup-defaults",
        test_startup_geometry_defaults_without_saved_geometry
    );
    Test.add_func(
        "/holder/window-geometry/startup-cli-overrides-saved",
        test_startup_geometry_cli_size_overrides_saved_geometry
    );
    Test.add_func(
        "/holder/window-geometry/startup-uses-saved",
        test_startup_geometry_uses_saved_geometry
    );
    Test.add_func(
        "/holder/window-geometry/startup-tiny-strike-limit",
        test_startup_geometry_ignores_tiny_saved_size_until_strike_limit
    );
    Test.add_func(
        "/holder/window-geometry/sidebar-clamps",
        test_sidebar_width_clamps_to_bounds
    );
    Test.add_func(
        "/holder/window-geometry/tiny-size-and-streak-rules",
        test_tiny_size_and_streak_rules
    );

    return Test.run();
}
