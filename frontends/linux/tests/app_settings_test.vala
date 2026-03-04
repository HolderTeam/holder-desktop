using GLib;

private void test_color_scheme_to_key_default() {
    assert(HolderLinux.AppSettings.color_scheme_to_key(Adw.ColorScheme.DEFAULT) == "default");
}

private void test_color_scheme_to_key_force_light() {
    assert(HolderLinux.AppSettings.color_scheme_to_key(Adw.ColorScheme.FORCE_LIGHT) == "force-light");
}

private void test_color_scheme_to_key_force_dark() {
    assert(HolderLinux.AppSettings.color_scheme_to_key(Adw.ColorScheme.FORCE_DARK) == "force-dark");
}

private void test_key_to_color_scheme_default() {
    assert(HolderLinux.AppSettings.key_to_color_scheme("default") == Adw.ColorScheme.DEFAULT);
}

private void test_key_to_color_scheme_force_light() {
    assert(HolderLinux.AppSettings.key_to_color_scheme("force-light") == Adw.ColorScheme.FORCE_LIGHT);
}

private void test_key_to_color_scheme_force_dark() {
    assert(HolderLinux.AppSettings.key_to_color_scheme("force-dark") == Adw.ColorScheme.FORCE_DARK);
}

private void test_key_to_color_scheme_unknown_falls_back_default() {
    assert(HolderLinux.AppSettings.key_to_color_scheme("surprise-value") == Adw.ColorScheme.DEFAULT);
}

int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/app_settings/color_scheme_to_key/default", test_color_scheme_to_key_default);
    Test.add_func("/app_settings/color_scheme_to_key/force_light", test_color_scheme_to_key_force_light);
    Test.add_func("/app_settings/color_scheme_to_key/force_dark", test_color_scheme_to_key_force_dark);
    Test.add_func("/app_settings/key_to_color_scheme/default", test_key_to_color_scheme_default);
    Test.add_func("/app_settings/key_to_color_scheme/force_light", test_key_to_color_scheme_force_light);
    Test.add_func("/app_settings/key_to_color_scheme/force_dark", test_key_to_color_scheme_force_dark);
    Test.add_func("/app_settings/key_to_color_scheme/unknown_falls_back_default",
                  test_key_to_color_scheme_unknown_falls_back_default);
    return Test.run();
}
