using GLib;

namespace HolderLinux.Tests {

private HolderLinux.SearchSelectionController make_controller() {
    var store = new GLib.ListStore(typeof(Object));
    store.append(new Object());
    store.append(new Object());
    return new HolderLinux.SearchSelectionController(store);
}

private void test_position_for_request_returns_invalid_for_negative_or_out_of_range() {
    var controller = make_controller();

    assert(controller.position_for_request(-1) == Gtk.INVALID_LIST_POSITION);
    assert(controller.position_for_request(2) == Gtk.INVALID_LIST_POSITION);
    assert(controller.position_for_request(99) == Gtk.INVALID_LIST_POSITION);
}

private void test_position_for_request_returns_requested_position_when_in_range() {
    var controller = make_controller();

    assert(controller.position_for_request(0) == 0);
    assert(controller.position_for_request(1) == 1);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/holder/search-selection/invalid-positions", test_position_for_request_returns_invalid_for_negative_or_out_of_range);
    Test.add_func("/holder/search-selection/in-range-position", test_position_for_request_returns_requested_position_when_in_range);
    return Test.run();
}

}
