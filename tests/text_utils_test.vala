using GLib;

private void test_text_utils_class_can_be_instantiated() {
    var utils = new HolderLinux.TextUtils();
    assert(utils != null);
}

private void test_title_from_markdown_heading() {
    var title = HolderLinux.TextUtils.title_from_content("# Project Plan\n\nBody");
    assert(title == "Project Plan");
}

private void test_title_from_first_non_empty_line() {
    var title = HolderLinux.TextUtils.title_from_content("\n\nFirst line\nSecond line");
    assert(title == "First line");
}

private void test_title_fallback_for_empty_content() {
    var title = HolderLinux.TextUtils.title_from_content("   \n\t\n");
    assert(title == "Untitled");
}

private void test_ellipsize_short_text_unchanged() {
    var out_text = HolderLinux.TextUtils.ellipsize("short", 10);
    assert(out_text == "short");
}

private void test_ellipsize_long_text_truncated() {
    var out_text = HolderLinux.TextUtils.ellipsize("abcdefghijklmnopqrstuvwxyz", 10);
    assert(out_text == "abcdefg...");
}

private void test_ellipsize_max_len_three_no_ellipsis() {
    var out_text = HolderLinux.TextUtils.ellipsize("abcdef", 3);
    assert(out_text == "abc");
}

private void test_ellipsize_max_len_zero_returns_empty() {
    var out_text = HolderLinux.TextUtils.ellipsize("abcdef", 0);
    assert(out_text == "");
}

private void test_ellipsize_null_returns_empty() {
    var out_text = HolderLinux.TextUtils.ellipsize((string?) null, 10);
    assert(out_text == "");
}

private void test_title_long_line_is_ellipsized_to_80() {
    var text = "# " +
               "12345678901234567890123456789012345678901234567890123456789012345678901234567890" +
               "tail";
    var title = HolderLinux.TextUtils.title_from_content(text);
    assert(title.length == 80);
}

private void test_title_from_heading_marker_only_line() {
    var title = HolderLinux.TextUtils.title_from_content("  #   \nSecond");
    assert(title == "");
}

private void test_title_from_null_content_is_untitled() {
    var title = HolderLinux.TextUtils.title_from_content((string?) null);
    assert(title == "Untitled");
}

private void test_relative_time_seconds() {
    var out_text = HolderLinux.TextUtils.format_relative_time(100, 95);
    assert(out_text == "5s ago");
}

private void test_relative_time_minutes() {
    var out_text = HolderLinux.TextUtils.format_relative_time(2000, 1940);
    assert(out_text == "1m ago");
}

private void test_relative_time_exact_60_seconds_formats_minutes() {
    var out_text = HolderLinux.TextUtils.format_relative_time(100, 40);
    assert(out_text == "1m ago");
}

private void test_relative_time_unknown() {
    var out_text = HolderLinux.TextUtils.format_relative_time(100, 0);
    assert(out_text == "unknown");
}

private void test_relative_time_future_is_just_now() {
    var out_text = HolderLinux.TextUtils.format_relative_time(100, 110);
    assert(out_text == "just now");
}

private void test_relative_time_hours() {
    var out_text = HolderLinux.TextUtils.format_relative_time(8000, 4400);
    assert(out_text == "1h ago");
}

private void test_relative_time_exact_3600_seconds_formats_hours() {
    var out_text = HolderLinux.TextUtils.format_relative_time(5000, 1400);
    assert(out_text == "1h ago");
}

private void test_relative_time_days() {
    var out_text = HolderLinux.TextUtils.format_relative_time(200000, 200000 - 172800);
    assert(out_text == "2d ago");
}

private void test_relative_time_exact_86400_seconds_formats_days() {
    var out_text = HolderLinux.TextUtils.format_relative_time(100000, 13600);
    assert(out_text == "1d ago");
}

private string trim(string text,
                    bool preserve = false,
                    bool trim_two_space_hard_breaks = false,
                    bool trim_whitespace_in_code_blocks = false) {
    return HolderLinux.TextUtils.trim_trailing_whitespace_for_save(
        text, preserve, trim_two_space_hard_breaks, trim_whitespace_in_code_blocks
    );
}

private void test_trim_default_mode_leaves_a_line_with_no_trailing_whitespace_unchanged() {
    assert(trim("foo") == "foo");
}

private void test_trim_default_mode_removes_a_single_trailing_space() {
    assert(trim("foo ") == "foo");
}

private void test_trim_default_mode_preserves_exactly_two_trailing_spaces() {
    assert(trim("foo  ") == "foo  ");
}

private void test_trim_default_mode_reduces_three_or_more_trailing_spaces_to_two() {
    assert(trim("foo    ") == "foo  ");
}

private void test_trim_default_mode_removes_trailing_tabs() {
    assert(trim("foo\t") == "foo");
}

private void test_trim_default_mode_does_not_credit_spaces_before_a_trailing_tab_as_a_hard_break() {
    assert(trim("foo  \t") == "foo");
}

private void test_trim_default_mode_cleans_a_whitespace_only_line_to_empty() {
    assert(trim("   \t ") == "");
}

private void test_trim_default_mode_processes_every_line_independently() {
    assert(trim("a \nb    \nc\t") == "a\nb  \nc");
}

private void test_trim_preserve_on_leaves_everything_exactly_as_typed() {
    var raw = "a \nb    \nc\t\n   ";
    assert(trim(raw, true) == raw);
}

private void test_trim_preserve_on_overrides_the_other_two_settings() {
    var raw = "foo  ";
    assert(trim(raw, true, true, true) == raw);
}

private void test_trim_two_space_line_endings_strips_a_genuine_hard_break_run_to_zero() {
    assert(trim("foo  ", false, true) == "foo");
    assert(trim("foo     ", false, true) == "foo");
}

private void test_trim_two_space_line_endings_does_not_change_ordinary_trailing_whitespace_handling() {
    assert(trim("foo ", false, true) == "foo");
    assert(trim("foo\t", false, true) == "foo");
}

private void test_trim_code_block_lines_are_untouched_by_default_even_with_trailing_whitespace() {
    var raw = "before\n```\ncode  \nmore\t\n```\nafter ";
    var expected = "before\n```\ncode  \nmore\t\n```\nafter";
    assert(trim(raw) == expected);
}

private void test_trim_whitespace_in_code_blocks_strips_everything_there_unconditionally() {
    var raw = "```\ncode  \nmore\t\n```";
    var expected = "```\ncode\nmore\n```";
    assert(trim(raw, false, false, true) == expected);
}

private void test_trim_whitespace_in_code_blocks_does_not_canonicalize_it_always_strips_fully() {
    // Unlike ordinary lines, a two-space run inside code has no hard-break meaning, so it goes
    // to zero here even though trim_two_space_hard_breaks is off.
    assert(trim("```\ncode  \n```", false, false, true) == "```\ncode\n```");
}

private void test_trim_code_block_fence_lines_themselves_are_excluded_from_ordinary_trimming_too() {
    // The opening fence line has no trailing whitespace here, but content immediately outside
    // the fence should still be cleaned normally.
    var raw = "```\ncode\n```\nafter ";
    assert(trim(raw) == "```\ncode\n```\nafter");
}

private void test_trim_two_independent_code_blocks_are_both_exempt_by_default() {
    var raw = "```\na  \n```\ntext\n```\nb  \n```";
    assert(trim(raw) == raw);
}

private void test_trim_an_unfenced_trailing_whitespace_line_between_two_code_blocks_is_still_cleaned() {
    var raw = "```\na\n```\nmid \n```\nb\n```";
    var expected = "```\na\n```\nmid\n```\nb\n```";
    assert(trim(raw) == expected);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/text/class_can_be_instantiated", test_text_utils_class_can_be_instantiated);
    Test.add_func("/text/title_from_markdown_heading", test_title_from_markdown_heading);
    Test.add_func("/text/title_from_first_non_empty_line", test_title_from_first_non_empty_line);
    Test.add_func("/text/title_fallback_for_empty_content", test_title_fallback_for_empty_content);
    Test.add_func("/text/ellipsize_short_text_unchanged", test_ellipsize_short_text_unchanged);
    Test.add_func("/text/ellipsize_long_text_truncated", test_ellipsize_long_text_truncated);
    Test.add_func("/text/ellipsize_max_len_three_no_ellipsis", test_ellipsize_max_len_three_no_ellipsis);
    Test.add_func("/text/ellipsize_max_len_zero_returns_empty", test_ellipsize_max_len_zero_returns_empty);
    Test.add_func("/text/ellipsize_null_returns_empty", test_ellipsize_null_returns_empty);
    Test.add_func("/text/title_long_line_is_ellipsized_to_80", test_title_long_line_is_ellipsized_to_80);
    Test.add_func("/text/title_from_heading_marker_only_line", test_title_from_heading_marker_only_line);
    Test.add_func("/text/title_from_null_content_is_untitled", test_title_from_null_content_is_untitled);
    Test.add_func("/text/relative_time_seconds", test_relative_time_seconds);
    Test.add_func("/text/relative_time_minutes", test_relative_time_minutes);
    Test.add_func("/text/relative_time_exact_60_seconds_formats_minutes", test_relative_time_exact_60_seconds_formats_minutes);
    Test.add_func("/text/relative_time_unknown", test_relative_time_unknown);
    Test.add_func("/text/relative_time_future_is_just_now", test_relative_time_future_is_just_now);
    Test.add_func("/text/relative_time_hours", test_relative_time_hours);
    Test.add_func("/text/relative_time_exact_3600_seconds_formats_hours", test_relative_time_exact_3600_seconds_formats_hours);
    Test.add_func("/text/relative_time_days", test_relative_time_days);
    Test.add_func("/text/relative_time_exact_86400_seconds_formats_days", test_relative_time_exact_86400_seconds_formats_days);
    Test.add_func("/text/trim/default_mode_leaves_a_line_with_no_trailing_whitespace_unchanged",
                  test_trim_default_mode_leaves_a_line_with_no_trailing_whitespace_unchanged);
    Test.add_func("/text/trim/default_mode_removes_a_single_trailing_space",
                  test_trim_default_mode_removes_a_single_trailing_space);
    Test.add_func("/text/trim/default_mode_preserves_exactly_two_trailing_spaces",
                  test_trim_default_mode_preserves_exactly_two_trailing_spaces);
    Test.add_func("/text/trim/default_mode_reduces_three_or_more_trailing_spaces_to_two",
                  test_trim_default_mode_reduces_three_or_more_trailing_spaces_to_two);
    Test.add_func("/text/trim/default_mode_removes_trailing_tabs",
                  test_trim_default_mode_removes_trailing_tabs);
    Test.add_func(
        "/text/trim/default_mode_does_not_credit_spaces_before_a_trailing_tab_as_a_hard_break",
        test_trim_default_mode_does_not_credit_spaces_before_a_trailing_tab_as_a_hard_break
    );
    Test.add_func("/text/trim/default_mode_cleans_a_whitespace_only_line_to_empty",
                  test_trim_default_mode_cleans_a_whitespace_only_line_to_empty);
    Test.add_func("/text/trim/default_mode_processes_every_line_independently",
                  test_trim_default_mode_processes_every_line_independently);
    Test.add_func("/text/trim/preserve_on_leaves_everything_exactly_as_typed",
                  test_trim_preserve_on_leaves_everything_exactly_as_typed);
    Test.add_func("/text/trim/preserve_on_overrides_the_other_two_settings",
                  test_trim_preserve_on_overrides_the_other_two_settings);
    Test.add_func("/text/trim/two_space_line_endings_strips_a_genuine_hard_break_run_to_zero",
                  test_trim_two_space_line_endings_strips_a_genuine_hard_break_run_to_zero);
    Test.add_func(
        "/text/trim/two_space_line_endings_does_not_change_ordinary_trailing_whitespace_handling",
        test_trim_two_space_line_endings_does_not_change_ordinary_trailing_whitespace_handling
    );
    Test.add_func("/text/trim/code_block_lines_are_untouched_by_default_even_with_trailing_whitespace",
                  test_trim_code_block_lines_are_untouched_by_default_even_with_trailing_whitespace);
    Test.add_func("/text/trim/whitespace_in_code_blocks_strips_everything_there_unconditionally",
                  test_trim_whitespace_in_code_blocks_strips_everything_there_unconditionally);
    Test.add_func("/text/trim/whitespace_in_code_blocks_does_not_canonicalize_it_always_strips_fully",
                  test_trim_whitespace_in_code_blocks_does_not_canonicalize_it_always_strips_fully);
    Test.add_func("/text/trim/code_block_fence_lines_themselves_are_excluded_from_ordinary_trimming_too",
                  test_trim_code_block_fence_lines_themselves_are_excluded_from_ordinary_trimming_too);
    Test.add_func("/text/trim/two_independent_code_blocks_are_both_exempt_by_default",
                  test_trim_two_independent_code_blocks_are_both_exempt_by_default);
    Test.add_func("/text/trim/an_unfenced_trailing_whitespace_line_between_two_code_blocks_is_still_cleaned",
                  test_trim_an_unfenced_trailing_whitespace_line_between_two_code_blocks_is_still_cleaned);

    return Test.run();
}
