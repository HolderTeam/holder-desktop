using GLib;

namespace HolderLinux {

internal errordomain TestFindReplaceError {
    FAILED
}

internal class RecordingFindReplaceOps : Object, IFindReplaceOps {
    public bool find_next_result = true;
    public bool replace_next_result = true;
    public uint replace_all_result = 0;
    public Error? replace_next_error = null;
    public Error? replace_all_error = null;

    public int find_next_calls = 0;
    public int replace_next_calls = 0;
    public int replace_all_calls = 0;
    public string last_find_text = "";
    public string last_replace_find_text = "";
    public string last_replace_text = "";
    public string last_replace_all_find_text = "";
    public string last_replace_all_text = "";

    public bool find_next(string find_text) {
        find_next_calls++;
        last_find_text = find_text;
        return find_next_result;
    }

    public bool replace_next(string find_text, string replace_text) throws Error {
        replace_next_calls++;
        last_replace_find_text = find_text;
        last_replace_text = replace_text;
        if (replace_next_error != null) {
            throw replace_next_error;
        }
        return replace_next_result;
    }

    public uint replace_all(string find_text, string replace_text) throws Error {
        replace_all_calls++;
        last_replace_all_find_text = find_text;
        last_replace_all_text = replace_text;
        if (replace_all_error != null) {
            throw replace_all_error;
        }
        return replace_all_result;
    }
}

}

namespace HolderLinux.Tests {

private void test_find_next_requires_non_empty_text() {
    var ops = new HolderLinux.RecordingFindReplaceOps();
    var controller = new HolderLinux.FindReplaceController(ops);
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    controller.on_find_next_requested("   ");

    assert(ops.find_next_calls == 0);
    assert(last_toast == "Enter text to find.");
}

private void test_find_next_trims_and_reports_no_match() {
    var ops = new HolderLinux.RecordingFindReplaceOps();
    ops.find_next_result = false;
    var controller = new HolderLinux.FindReplaceController(ops);
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    controller.on_find_next_requested("  needle  ");

    assert(ops.find_next_calls == 1);
    assert(ops.last_find_text == "needle");
    assert(last_toast == "No match found.");
}

private void test_replace_requested_reports_result_and_reselects_next_match() {
    var ops = new HolderLinux.RecordingFindReplaceOps();
    var controller = new HolderLinux.FindReplaceController(ops);
    string? last_toast = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });

    controller.on_replace_requested("  needle  ", "replacement");

    assert(ops.replace_next_calls == 1);
    assert(ops.last_replace_find_text == "needle");
    assert(ops.last_replace_text == "replacement");
    assert(last_toast == "Replaced one match.");
    assert(ops.find_next_calls == 1);
    assert(ops.last_find_text == "needle");
}

private void test_replace_requested_handles_no_match_and_errors() {
    var ops = new HolderLinux.RecordingFindReplaceOps();
    var controller = new HolderLinux.FindReplaceController(ops);
    string? last_toast = null;
    string? error_title = null;
    string? error_details = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });
    controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    controller.on_replace_requested("   ", "replacement");
    assert(last_toast == "Enter text to find.");
    assert(ops.replace_next_calls == 0);
    assert(ops.find_next_calls == 0);

    ops.replace_next_result = false;
    controller.on_replace_requested("needle", "replacement");
    assert(last_toast == "No match found.");
    assert(ops.find_next_calls == 0);

    ops.replace_next_error = new HolderLinux.TestFindReplaceError.FAILED("boom");
    controller.on_replace_requested("needle", "replacement");
    assert(error_title == "Replace failed");
    assert(error_details == "boom");
}

private void test_replace_all_requested_reports_count_and_errors() {
    var ops = new HolderLinux.RecordingFindReplaceOps();
    var controller = new HolderLinux.FindReplaceController(ops);
    string? last_toast = null;
    string? error_title = null;
    string? error_details = null;
    controller.toast_requested.connect((message) => {
        last_toast = message;
    });
    controller.error_reported.connect((title, details) => {
        error_title = title;
        error_details = details;
    });

    controller.on_replace_all_requested("   ", "replacement");
    assert(last_toast == "Enter text to find.");
    assert(ops.replace_all_calls == 0);

    ops.replace_all_result = 3;
    controller.on_replace_all_requested("  needle  ", "replacement");
    assert(ops.replace_all_calls == 1);
    assert(ops.last_replace_all_find_text == "needle");
    assert(last_toast == "Replaced 3 matches.");

    ops.replace_all_error = new HolderLinux.TestFindReplaceError.FAILED("all boom");
    controller.on_replace_all_requested("needle", "replacement");
    assert(error_title == "Replace all failed");
    assert(error_details == "all boom");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/find-replace/find-next-requires-non-empty-text", test_find_next_requires_non_empty_text);
    Test.add_func("/holder/find-replace/find-next-trims-and-reports-no-match", test_find_next_trims_and_reports_no_match);
    Test.add_func("/holder/find-replace/replace-requested-reports-result-and-reselects-next-match", test_replace_requested_reports_result_and_reselects_next_match);
    Test.add_func("/holder/find-replace/replace-requested-handles-no-match-and-errors", test_replace_requested_handles_no_match_and_errors);
    Test.add_func("/holder/find-replace/replace-all-requested-reports-count-and-errors", test_replace_all_requested_reports_count_and_errors);
    return Test.run();
}

}
