using GLib;

namespace HolderLinuxTests {

private void test_zoom_steps_from_fit_and_from_zoomed() {
    assert(HolderLinux.AssetPreviewPresenter.zoom_out_target(0.0) == 0.8);
    assert(HolderLinux.AssetPreviewPresenter.zoom_in_target(0.0) == 1.2);
    assert(Math.fabs(HolderLinux.AssetPreviewPresenter.zoom_out_target(1.0) - 0.8) < 0.0001);
    assert(Math.fabs(HolderLinux.AssetPreviewPresenter.zoom_in_target(1.0) - 1.2) < 0.0001);
}

private void test_zoom_scales_texture_and_labels_percent() {
    var zoom = HolderLinux.AssetPreviewPresenter.zoom(1.0, 800, 600);
    assert(zoom.zoom == 1.0);
    assert(zoom.width == 800);
    assert(zoom.height == 600);
    assert(zoom.label == "100%");

    var half = HolderLinux.AssetPreviewPresenter.zoom(0.5, 801, 600);
    assert(half.width == 400);
    assert(half.height == 300);
    assert(half.label == "50%");
}

private void test_zoom_is_clamped() {
    var low = HolderLinux.AssetPreviewPresenter.zoom(0.01, 1000, 1000);
    assert(low.zoom == HolderLinux.AssetPreviewPresenter.MIN_ZOOM);
    assert(low.label == "20%");

    var high = HolderLinux.AssetPreviewPresenter.zoom(99.0, 1000, 1000);
    assert(high.zoom == HolderLinux.AssetPreviewPresenter.MAX_ZOOM);
    assert(high.label == "400%");
}

private void test_pixel_size_is_clamped() {
    var tiny = HolderLinux.AssetPreviewPresenter.zoom(0.2, 1, 1);
    assert(tiny.width == 1);
    assert(tiny.height == 1);

    var huge = HolderLinux.AssetPreviewPresenter.zoom(4.0, 10000, 20000);
    assert(huge.width == 16384);
    assert(huge.height == 16384);
}

private void test_navigation_state() {
    var none = HolderLinux.AssetPreviewPresenter.navigation(-1, 0);
    assert(!none.previous_enabled);
    assert(!none.next_enabled);

    var only = HolderLinux.AssetPreviewPresenter.navigation(0, 1);
    assert(!only.previous_enabled);
    assert(!only.next_enabled);

    var first = HolderLinux.AssetPreviewPresenter.navigation(0, 3);
    assert(!first.previous_enabled);
    assert(first.next_enabled);

    var middle = HolderLinux.AssetPreviewPresenter.navigation(1, 3);
    assert(middle.previous_enabled);
    assert(middle.next_enabled);

    var last = HolderLinux.AssetPreviewPresenter.navigation(2, 3);
    assert(last.previous_enabled);
    assert(!last.next_enabled);
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/asset-preview-presenter/zoom-steps", test_zoom_steps_from_fit_and_from_zoomed);
    Test.add_func("/asset-preview-presenter/zoom-scaling", test_zoom_scales_texture_and_labels_percent);
    Test.add_func("/asset-preview-presenter/zoom-clamp", test_zoom_is_clamped);
    Test.add_func("/asset-preview-presenter/pixel-clamp", test_pixel_size_is_clamped);
    Test.add_func("/asset-preview-presenter/navigation", test_navigation_state);
    return Test.run();
}

}
