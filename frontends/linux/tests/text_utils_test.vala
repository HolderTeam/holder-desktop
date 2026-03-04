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

private void test_title_long_line_is_ellipsized_to_80() {
    var text = "# " +
               "12345678901234567890123456789012345678901234567890123456789012345678901234567890" +
               "tail";
    var title = HolderLinux.TextUtils.title_from_content(text);
    assert(title.length == 80);
}

private void test_relative_time_seconds() {
    var out_text = HolderLinux.TextUtils.format_relative_time(100, 95);
    assert(out_text == "5s ago");
}

private void test_relative_time_minutes() {
    var out_text = HolderLinux.TextUtils.format_relative_time(2000, 1940);
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

private void test_relative_time_days() {
    var out_text = HolderLinux.TextUtils.format_relative_time(200000, 200000 - 172800);
    assert(out_text == "2d ago");
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
    Test.add_func("/text/title_long_line_is_ellipsized_to_80", test_title_long_line_is_ellipsized_to_80);
    Test.add_func("/text/relative_time_seconds", test_relative_time_seconds);
    Test.add_func("/text/relative_time_minutes", test_relative_time_minutes);
    Test.add_func("/text/relative_time_unknown", test_relative_time_unknown);
    Test.add_func("/text/relative_time_future_is_just_now", test_relative_time_future_is_just_now);
    Test.add_func("/text/relative_time_hours", test_relative_time_hours);
    Test.add_func("/text/relative_time_days", test_relative_time_days);

    return Test.run();
}
