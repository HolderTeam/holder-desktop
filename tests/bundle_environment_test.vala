using GLib;

namespace HolderLinuxTests {

private string make_temp_dir() {
    try {
        return DirUtils.make_tmp("holder-bundle-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
}

// A directory laid out like the runtime part of a macOS app bundle.
private string make_resources(string app_root, bool with_runtime = true) {
    var resources = Path.build_filename(app_root, "Holder.app", "Contents", "Resources");
    DirUtils.create_with_parents(Path.build_filename(resources, "bin"), 0755);
    DirUtils.create_with_parents(Path.build_filename(app_root, "Holder.app", "Contents", "MacOS"), 0755);
    if (with_runtime) {
        DirUtils.create_with_parents(Path.build_filename(resources, "share", "glib-2.0", "schemas"), 0755);
    }
    return resources;
}

private string? nothing_set(string name) {
    return null;
}

private bool has_variable(string[] plan, string name, string value) {
    for (int i = 0; i + 1 < plan.length; i += 2) {
        if (plan[i] == name && plan[i + 1] == value) {
            return true;
        }
    }
    return false;
}

private bool names_variable(string[] plan, string name) {
    for (int i = 0; i + 1 < plan.length; i += 2) {
        if (plan[i] == name) {
            return true;
        }
    }
    return false;
}

private void test_finds_the_runtime_root_from_the_desktop_inside_resources() {
    var resources = make_resources(make_temp_dir());
    var root = HolderLinux.BundleEnvironment.runtime_root(Path.build_filename(resources, "bin"));
    assert(root == resources);
}

private void test_finds_the_runtime_root_from_the_desktop_as_the_main_executable() {
    var base_dir = make_temp_dir();
    var resources = make_resources(base_dir);
    var main_dir = Path.build_filename(base_dir, "Holder.app", "Contents", "MacOS");
    var root = HolderLinux.BundleEnvironment.runtime_root(main_dir);
    assert(root == resources);
}

private void test_a_directory_that_is_not_a_bundle_has_no_runtime_root() {
    var base_dir = make_temp_dir();
    DirUtils.create_with_parents(Path.build_filename(base_dir, "build"), 0755);
    assert(HolderLinux.BundleEnvironment.runtime_root(Path.build_filename(base_dir, "build")) == null);
    assert(HolderLinux.BundleEnvironment.runtime_root(null) == null);
}

private void test_a_bundle_without_the_gtk_runtime_is_left_alone() {
    var resources = make_resources(make_temp_dir(), false);
    var root = HolderLinux.BundleEnvironment.runtime_root(Path.build_filename(resources, "bin"));
    assert(root == null);
}

private void test_plans_the_variables_the_launcher_used_to_set() {
    var resources = make_resources(make_temp_dir());

    var plan = HolderLinux.BundleEnvironment.plan(resources, nothing_set);

    assert(plan.length == 14);
    assert(has_variable(plan, "GSETTINGS_SCHEMA_DIR", Path.build_filename(resources, "share/glib-2.0/schemas")));
    assert(has_variable(plan, "GIO_MODULE_DIR", Path.build_filename(resources, "lib/gio/modules")));
    assert(has_variable(plan, "GDK_PIXBUF_MODULE_FILE",
                        Path.build_filename(resources, "lib/gdk-pixbuf-2.0/2.10.0/loaders.cache")));
    assert(has_variable(plan, "GTK_PATH", Path.build_filename(resources, "lib/gtk-4.0")));
    assert(has_variable(plan, "XDG_DATA_DIRS", Path.build_filename(resources, "share")));
    assert(has_variable(plan, "ENCHANT_CONFIG_DIR", Path.build_filename(resources, "share/enchant-2")));
    assert(has_variable(plan, "DICPATH", Path.build_filename(resources, "share/enchant/hunspell")));
}

private string? launcher_already_set(string name) {
    return name == "GTK_PATH" || name == "XDG_DATA_DIRS" ? "/from/the/launcher" : null;
}

private void test_does_not_override_what_the_launcher_already_set() {
    var resources = make_resources(make_temp_dir());

    var plan = HolderLinux.BundleEnvironment.plan(resources, launcher_already_set);

    assert(plan.length == 10);
    assert(!names_variable(plan, "GTK_PATH"));
    assert(!names_variable(plan, "XDG_DATA_DIRS"));
    assert(names_variable(plan, "GSETTINGS_SCHEMA_DIR"));
}

private string? empty_counts_as_unset(string name) {
    return name == "DICPATH" ? "" : "/set";
}

private void test_an_empty_value_counts_as_unset() {
    var resources = make_resources(make_temp_dir());

    var plan = HolderLinux.BundleEnvironment.plan(resources, empty_counts_as_unset);

    assert(plan.length == 2);
    assert(names_variable(plan, "DICPATH"));
}

[CCode (cname = "chdir", cheader_filename = "unistd.h")]
private extern int test_chdir(string path);

private void test_configuring_a_bundle_enters_its_resources_directory() {
    var original = Environment.get_current_dir();
    var resources = make_resources(make_temp_dir());

    HolderLinux.BundleEnvironment.configure(Path.build_filename(resources, "bin"));
    var after = Environment.get_current_dir();
    test_chdir(original);

    // The pixbuf loader cache lists its modules relative to Contents/Resources. The expected suffix is
    // built with the platform's separator: the test also runs on Windows.
    assert(after.has_suffix(Path.build_filename("Holder.app", "Contents", "Resources")));
}

private void test_configuring_outside_a_bundle_leaves_the_directory_alone() {
    var original = Environment.get_current_dir();
    var plain = make_temp_dir();

    HolderLinux.BundleEnvironment.configure(plain);

    assert(Environment.get_current_dir() == original);
}

public static int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/bundle_environment/root_from_resources_bin", test_finds_the_runtime_root_from_the_desktop_inside_resources);
    Test.add_func("/bundle_environment/root_from_contents_macos", test_finds_the_runtime_root_from_the_desktop_as_the_main_executable);
    Test.add_func("/bundle_environment/not_a_bundle", test_a_directory_that_is_not_a_bundle_has_no_runtime_root);
    Test.add_func("/bundle_environment/no_gtk_runtime", test_a_bundle_without_the_gtk_runtime_is_left_alone);
    Test.add_func("/bundle_environment/plans_the_launchers_variables", test_plans_the_variables_the_launcher_used_to_set);
    Test.add_func("/bundle_environment/does_not_override", test_does_not_override_what_the_launcher_already_set);
    Test.add_func("/bundle_environment/empty_is_unset", test_an_empty_value_counts_as_unset);
    Test.add_func("/bundle_environment/enters_resources", test_configuring_a_bundle_enters_its_resources_directory);
    Test.add_func("/bundle_environment/leaves_directory_outside_a_bundle", test_configuring_outside_a_bundle_leaves_the_directory_alone);

    return Test.run();
}

}
