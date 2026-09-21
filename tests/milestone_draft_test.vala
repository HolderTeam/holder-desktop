using GLib;

namespace HolderLinuxTests {

private TimeZone? london() {
    // GLib on Windows resolves named zones through the registry, not IANA zoneinfo files, so the
    // UK zone is "GMT Standard Time" there (same UK DST rules).
    var name = Path.DIR_SEPARATOR == '\\' ? "GMT Standard Time" : "Europe/London";
    try {
        return new TimeZone.identifier(name);
    } catch (Error e) {
        return null;
    }
}

private HolderLinux.CardSummary card(string card_id, string project_id, string title) {
    return new HolderLinux.CardSummary(card_id, project_id, title, card_id + ".md", 1024.0, null, 1, 1);
}

private HolderLinux.Milestone editing_milestone(int64 start_at,
                                                int64? end_at,
                                                bool all_day,
                                                string? kind = null,
                                                string? description = null,
                                                string? card_title = null) {
    return new HolderLinux.Milestone(
        "m1", "c1", start_at, end_at, all_day, kind, description, 1, 1, card_title
    );
}

private void test_static_labels_and_presets() {
    var presets = HolderLinux.MilestoneDraft.kind_presets();
    assert(presets.length == 9);
    assert(presets[0] == "Deadline");
    assert(presets[8] == "MOT");

    assert(HolderLinux.MilestoneDraft.form_title(false) == "Add milestone");
    assert(HolderLinux.MilestoneDraft.form_title(true) == "Edit milestone");
    assert(HolderLinux.MilestoneDraft.form_subtitle(false) == "Attach a date to a card in this project.");
    assert(HolderLinux.MilestoneDraft.form_subtitle(true)
           == "Update this milestone without changing its identity.");
    assert(HolderLinux.MilestoneDraft.submit_label(false) == "Add milestone");
    assert(HolderLinux.MilestoneDraft.submit_label(true) == "Save changes");
    assert(HolderLinux.MilestoneDraft.card_label(editing_milestone(1, null, true, null, null, "Passport"))
           == "Passport");
    assert(HolderLinux.MilestoneDraft.card_label(editing_milestone(1, null, true)) == "c1");
}

private void test_form_precondition_error() {
    var message = "Select a project and connect to Holder first.";
    assert(HolderLinux.MilestoneDraft.form_precondition_error(true, true, true, false) == null);
    assert(HolderLinux.MilestoneDraft.form_precondition_error(false, true, true, false) == message);
    assert(HolderLinux.MilestoneDraft.form_precondition_error(true, false, true, false) == message);
    assert(HolderLinux.MilestoneDraft.form_precondition_error(true, true, false, false) == message);
    // Editing does not need the card list.
    assert(HolderLinux.MilestoneDraft.form_precondition_error(true, true, false, true) == null);
    assert(HolderLinux.MilestoneDraft.form_precondition_error(false, true, false, true) == message);
}

private void test_card_options_filter_project_and_pick_selected_card() {
    var cards = new Gee.ArrayList<HolderLinux.CardSummary>();
    cards.add(card("other-1", "p2", "Other project"));
    cards.add(card("c1", "p1", "First"));
    cards.add(card("other-2", "p2", "Other again"));
    cards.add(card("c2", "p1", "Second"));
    cards.add(card("c3", "p1", "Third"));

    var options = HolderLinux.MilestoneDraft.card_options(cards, "p1", "c3");
    assert(options.card_ids.size == 3);
    assert(options.card_ids[0] == "c1" && options.card_ids[2] == "c3");
    assert(options.card_names[1] == "Second");
    // Index counts only the cards that were offered.
    assert(options.selected_index == 2);

    assert(HolderLinux.MilestoneDraft.card_options(cards, "p1", null).selected_index == 0);
    assert(HolderLinux.MilestoneDraft.card_options(cards, "p1", "other-1").selected_index == 0);
    assert(HolderLinux.MilestoneDraft.card_options(cards, "p9", "c1").card_ids.size == 0);
}

private void test_resolve_card_id() {
    var ids = new Gee.ArrayList<string>();
    ids.add("c1");
    ids.add("c2");
    assert(HolderLinux.MilestoneDraft.resolve_card_id(ids, 0, null) == "c1");
    assert(HolderLinux.MilestoneDraft.resolve_card_id(ids, 1, null) == "c2");
    assert(HolderLinux.MilestoneDraft.resolve_card_id(ids, 2, null) == null);
    assert(HolderLinux.MilestoneDraft.resolve_card_id(ids, uint.MAX, null) == null);
    assert(HolderLinux.MilestoneDraft.resolve_card_id(new Gee.ArrayList<string>(), 0, null) == null);
    // When editing, the milestone's own card wins and the dropdown is ignored.
    assert(HolderLinux.MilestoneDraft.resolve_card_id(
        new Gee.ArrayList<string>(), uint.MAX, editing_milestone(1, null, true)) == "c1");
}

private void test_new_form_defaults_follow_the_clock() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var calendar_date = new DateTime(z, 2026, 3, 12, 0, 0, 0.0);

    var morning = HolderLinux.MilestoneDraft.form_defaults(
        null, calendar_date, new DateTime(z, 2026, 3, 5, 9, 15, 0.0), z);
    assert(morning.start == calendar_date);
    assert(morning.end == calendar_date);
    assert(!morning.include_end);
    assert(morning.all_day);
    assert(morning.start_hour == 9 && morning.start_minute == 15);
    assert(morning.end_hour == 10 && morning.end_minute == 15);
    assert(morning.kind == "" && morning.description == "");

    // The default end hour never rolls past 23.
    var late = HolderLinux.MilestoneDraft.form_defaults(
        null, calendar_date, new DateTime(z, 2026, 3, 5, 23, 40, 0.0), z);
    assert(late.start_hour == 23 && late.end_hour == 23 && late.end_minute == 40);
    var midnight = HolderLinux.MilestoneDraft.form_defaults(
        null, calendar_date, new DateTime(z, 2026, 3, 5, 0, 0, 0.0), z);
    assert(midnight.start_hour == 0 && midnight.end_hour == 1);
}

private void test_editing_form_defaults_come_from_the_milestone() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    var now = new DateTime(z, 2026, 8, 1, 4, 4, 0.0);
    var calendar_date = new DateTime(z, 2026, 8, 1, 0, 0, 0.0);
    var start = new DateTime(z, 2026, 3, 5, 9, 30, 0.0).to_unix();
    var end = new DateTime(z, 2026, 3, 6, 17, 45, 0.0).to_unix();

    var timed = HolderLinux.MilestoneDraft.form_defaults(
        editing_milestone(start, end, false, "Event", "Bring ID"), calendar_date, now, z);
    assert(timed.start.to_unix() == start);
    assert(timed.end.to_unix() == end);
    assert(timed.include_end);
    assert(!timed.all_day);
    assert(timed.start_hour == 9 && timed.start_minute == 30);
    assert(timed.end_hour == 17 && timed.end_minute == 45);
    assert(timed.kind == "Event" && timed.description == "Bring ID");

    // Without an end the end fields mirror the start and "Add end" stays off.
    var open_ended = HolderLinux.MilestoneDraft.form_defaults(
        editing_milestone(start, null, true), calendar_date, now, z);
    assert(!open_ended.include_end);
    assert(open_ended.all_day);
    assert(open_ended.end.to_unix() == start);
    assert(open_ended.end_hour == 9 && open_ended.end_minute == 30);
    assert(open_ended.kind == "" && open_ended.description == "");
}

private void test_optional_text_and_date_with_time() {
    assert(HolderLinux.MilestoneDraft.optional_text("") == null);
    assert(HolderLinux.MilestoneDraft.optional_text("   \t") == null);
    assert(HolderLinux.MilestoneDraft.optional_text("  Exam ") == "Exam");

    var z = new TimeZone.utc();
    var value = HolderLinux.MilestoneDraft.date_with_time(new DateTime(z, 2026, 3, 5, 13, 13, 13.0), 7, 8, z);
    assert(value.get_year() == 2026 && value.get_month() == 3 && value.get_day_of_month() == 5);
    assert(value.get_hour() == 7 && value.get_minute() == 8 && value.get_second() == 0);
}

private void test_build_zeroes_time_for_all_day_and_keeps_it_for_timed() {
    var z = new TimeZone.utc();
    var start_date = new DateTime(z, 2026, 3, 5, 0, 0, 0.0);
    var end_date = new DateTime(z, 2026, 3, 7, 0, 0, 0.0);

    var all_day = HolderLinux.MilestoneDraft.build(
        start_date, 9, 30, true, end_date, 17, 45, true, "  Deadline ", "", z);
    assert(all_day.error_message == null);
    assert(all_day.all_day);
    assert(all_day.start_at == new DateTime(z, 2026, 3, 5, 0, 0, 0.0).to_unix());
    assert(all_day.end_at == new DateTime(z, 2026, 3, 7, 0, 0, 0.0).to_unix());
    assert(all_day.kind == "Deadline");
    assert(all_day.description == null);

    var timed = HolderLinux.MilestoneDraft.build(
        start_date, 9, 30, true, end_date, 17, 45, false, "", " Bring ID ", z);
    assert(timed.error_message == null);
    assert(!timed.all_day);
    assert(timed.start_at == new DateTime(z, 2026, 3, 5, 9, 30, 0.0).to_unix());
    assert(timed.end_at == new DateTime(z, 2026, 3, 7, 17, 45, 0.0).to_unix());
    assert(timed.kind == null);
    assert(timed.description == "Bring ID");

    // The end widgets are ignored unless "Add end" is on.
    var no_end = HolderLinux.MilestoneDraft.build(
        start_date, 9, 30, false, new DateTime(z, 2020, 1, 1, 0, 0, 0.0), 0, 0, false, "", "", z);
    assert(no_end.error_message == null);
    assert(no_end.end_at == null);
}

private void test_build_rejects_an_end_before_the_start() {
    var z = new TimeZone.utc();
    var day = new DateTime(z, 2026, 3, 5, 0, 0, 0.0);
    var earlier_day = new DateTime(z, 2026, 3, 4, 0, 0, 0.0);
    var message = "The end must not be before the start.";

    var earlier_time = HolderLinux.MilestoneDraft.build(day, 10, 0, true, day, 9, 59, false, "", "", z);
    assert(earlier_time.error_message == message);
    var earlier_date = HolderLinux.MilestoneDraft.build(day, 10, 0, true, earlier_day, 23, 0, true, "", "", z);
    assert(earlier_date.error_message == message);
    // Equal start and end is allowed.
    var equal = HolderLinux.MilestoneDraft.build(day, 10, 0, true, day, 10, 0, false, "", "", z);
    assert(equal.error_message == null);
    assert(equal.end_at == equal.start_at);
    // With all-day the times are zeroed first, so a later time on the same day is not "before".
    var all_day_same = HolderLinux.MilestoneDraft.build(day, 18, 0, true, day, 1, 0, true, "", "", z);
    assert(all_day_same.error_message == null);
}

private void test_build_uses_the_supplied_zone_across_daylight_saving() {
    var zone = london();
    if (zone == null) {
        Test.skip("timezone database unavailable");
        return;
    }
    var z = (!) zone;
    // 28 March 09:00 GMT to 30 March 09:00 BST is 47 hours, not 48.
    var result = HolderLinux.MilestoneDraft.build(
        new DateTime(z, 2026, 3, 28, 0, 0, 0.0), 9, 0,
        true, new DateTime(z, 2026, 3, 30, 0, 0, 0.0), 9, 0,
        false, "", "", z);
    assert(result.error_message == null);
    assert(result.end_at - result.start_at == 47 * 3600);
}

public static int main(string[] args) {
    Environment.set_variable("TZ", "Europe/London", true);
    Test.init(ref args);

    Test.add_func("/milestone-draft/labels-and-presets", test_static_labels_and_presets);
    Test.add_func("/milestone-draft/form-precondition", test_form_precondition_error);
    Test.add_func("/milestone-draft/card-options", test_card_options_filter_project_and_pick_selected_card);
    Test.add_func("/milestone-draft/resolve-card-id", test_resolve_card_id);
    Test.add_func("/milestone-draft/new-defaults", test_new_form_defaults_follow_the_clock);
    Test.add_func("/milestone-draft/editing-defaults", test_editing_form_defaults_come_from_the_milestone);
    Test.add_func("/milestone-draft/optional-text-and-date-with-time", test_optional_text_and_date_with_time);
    Test.add_func("/milestone-draft/build-all-day-and-timed",
                  test_build_zeroes_time_for_all_day_and_keeps_it_for_timed);
    Test.add_func("/milestone-draft/build-rejects-end-before-start", test_build_rejects_an_end_before_the_start);
    Test.add_func("/milestone-draft/build-across-dst", test_build_uses_the_supplied_zone_across_daylight_saving);

    return Test.run();
}

}
