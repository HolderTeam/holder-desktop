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

private void test_schema_candidate_dir_for_executable_path() {
    var dir = HolderLinux.AppSettings.schema_candidate_dir_for_executable_path("/tmp/holder/bin/holder-desktop");
    assert(dir == "/tmp/holder/bin/data");
}

private void test_has_compiled_schema_in_dir_false_for_missing() {
    assert(!HolderLinux.AppSettings.has_compiled_schema_in_dir("/tmp/holder-missing-schema-dir"));
}

private void test_has_compiled_schema_in_dir_true_when_file_exists() {
    string tmp_dir = "";
    try {
        tmp_dir = DirUtils.make_tmp("holder-linux-app-settings-test-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
    assert(tmp_dir != null);
    var compiled_path = Path.build_filename(tmp_dir, "gschemas.compiled");
    try {
        FileUtils.set_contents(compiled_path, "");
    } catch (FileError e) {
        assert_not_reached();
    }
    assert(HolderLinux.AppSettings.has_compiled_schema_in_dir(tmp_dir));
    FileUtils.remove(compiled_path);
    DirUtils.remove(tmp_dir);
}

private void test_open_or_null_for_invalid_executable_emits_warning_and_returns_null() {
    string warning_text = "";
    HolderLinux.AppSettings.set_warning_sink((message) => {
        warning_text = message;
    });
    var settings = HolderLinux.AppSettings.open_or_null_for_executable_path("/tmp/holder-invalid-exe");
    HolderLinux.AppSettings.set_warning_sink(null);
    assert(settings == null);
    assert(warning_text.contains("GSettings schema"));
}

private void test_emit_warning_without_sink_logs_warning() {
    HolderLinux.AppSettings.set_warning_sink(null);
    Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*line-28-warning-test*");
    HolderLinux.AppSettings.emit_warning_for_tests("line-28-warning-test");
    Test.assert_expected_messages();
}

private void test_open_or_null_uses_default_schema_lookup_when_available_subprocess() {
    if (Test.subprocess()) {
        var settings = HolderLinux.AppSettings.open_or_null_for_executable_path("/tmp/holder-invalid-exe");
        assert(settings != null);
        return;
    }

    string exe_path;
    try {
        exe_path = FileUtils.read_link("/proc/self/exe");
    } catch (Error e) {
        assert_not_reached();
    }
    var data_dir = HolderLinux.AppSettings.schema_candidate_dir_for_executable_path(exe_path);
    assert(HolderLinux.AppSettings.has_compiled_schema_in_dir(data_dir));

    var previous_schema_dir = Environment.get_variable("GSETTINGS_SCHEMA_DIR");
    Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
    Environment.set_variable("GSETTINGS_SCHEMA_DIR", data_dir, true);
    HolderLinux.AppSettings.set_skip_default_schema_lookup_for_tests(false);
    HolderLinux.AppSettings.set_force_read_link_failure_for_tests(false);
    Test.trap_subprocess("/app_settings/open_or_null_uses_default_schema_lookup_when_available_subprocess", 0, 0);
    Test.trap_assert_passed();

    if (previous_schema_dir == null) {
        Environment.unset_variable("GSETTINGS_SCHEMA_DIR");
    } else {
        Environment.set_variable("GSETTINGS_SCHEMA_DIR", previous_schema_dir, true);
    }
}

private void test_open_or_null_when_read_link_fails_returns_null() {
    HolderLinux.AppSettings.set_skip_default_schema_lookup_for_tests(true);
    HolderLinux.AppSettings.set_force_read_link_failure_for_tests(true);
    HolderLinux.AppSettings.set_warning_sink((message) => {});

    var settings = HolderLinux.AppSettings.open_or_null_for_executable_path(null);

    HolderLinux.AppSettings.set_warning_sink(null);
    HolderLinux.AppSettings.set_force_read_link_failure_for_tests(false);
    HolderLinux.AppSettings.set_skip_default_schema_lookup_for_tests(false);
    assert(settings == null);
}

private void test_open_or_null_for_bad_local_schema_dir_emits_warning_and_returns_null() {
    string tmp_dir = "";
    try {
        tmp_dir = DirUtils.make_tmp("holder-linux-app-settings-bad-schema-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }
    var fake_exe = Path.build_filename(tmp_dir, "holder-desktop");
    var data_dir = Path.build_filename(tmp_dir, "data");
    DirUtils.create_with_parents(data_dir, 0700);
    try {
        FileUtils.set_contents(fake_exe, "");
        FileUtils.set_contents(Path.build_filename(data_dir, "gschemas.compiled"), "");
    } catch (FileError e) {
        assert_not_reached();
    }

    string warning_text = "";
    HolderLinux.AppSettings.set_warning_sink((message) => {
        warning_text = message;
    });
    var settings = HolderLinux.AppSettings.open_or_null_for_executable_path(fake_exe);
    HolderLinux.AppSettings.set_warning_sink(null);

    assert(settings == null);
    assert(warning_text.contains("Failed to load schema dir") || warning_text.contains("GSettings schema"));

    FileUtils.remove(Path.build_filename(data_dir, "gschemas.compiled"));
    DirUtils.remove(data_dir);
    FileUtils.remove(fake_exe);
    DirUtils.remove(tmp_dir);
}

private void test_open_or_null_when_local_schema_missing_emits_specific_warning() {
    string tmp_dir = "";
    try {
        tmp_dir = DirUtils.make_tmp("holder-linux-app-settings-missing-schema-XXXXXX");
    } catch (FileError e) {
        assert_not_reached();
    }

    var fake_exe = Path.build_filename(tmp_dir, "holder-desktop");
    var data_dir = Path.build_filename(tmp_dir, "data");
    DirUtils.create_with_parents(data_dir, 0700);

    var xml_path = Path.build_filename(data_dir, "org.example.test.gschema.xml");
    var xml = """
<schemalist>
  <schema id='org.example.test' path='/org/example/test/'>
    <key name='dummy' type='s'>
      <default>'x'</default>
    </key>
  </schema>
</schemalist>
""";
    try {
        FileUtils.set_contents(fake_exe, "");
        FileUtils.set_contents(xml_path, xml);
    } catch (FileError e) {
        assert_not_reached();
    }

    int status = -1;
    string stdout_text = "";
    string stderr_text = "";
    try {
        Process.spawn_command_line_sync("glib-compile-schemas \"%s\"".printf(data_dir),
                                        out stdout_text,
                                        out stderr_text,
                                        out status);
    } catch (SpawnError e) {
        assert_not_reached();
    }
    assert(status == 0);

    string warning_text = "";
    HolderLinux.AppSettings.set_warning_sink((message) => {
        warning_text = message;
    });
    var settings = HolderLinux.AppSettings.open_or_null_for_executable_path(fake_exe);
    HolderLinux.AppSettings.set_warning_sink(null);

    assert(settings == null);
    assert(warning_text.contains("missing from local schema directory"));

    FileUtils.remove(Path.build_filename(data_dir, "gschemas.compiled"));
    FileUtils.remove(xml_path);
    DirUtils.remove(data_dir);
    FileUtils.remove(fake_exe);
    DirUtils.remove(tmp_dir);
}

private void test_key_constants_are_non_empty() {
    assert(HolderLinux.AppSettings.KEY_STYLE_VARIANT.length > 0);
    assert(HolderLinux.AppSettings.KEY_STYLE_SCHEME_ID.length > 0);
    assert(HolderLinux.AppSettings.KEY_SHOW_LINE_NUMBERS.length > 0);
    assert(HolderLinux.AppSettings.KEY_SHOW_SPELL_CHECKING.length > 0);
    assert(HolderLinux.AppSettings.KEY_WINDOW_WIDTH.length > 0);
    assert(HolderLinux.AppSettings.KEY_WINDOW_HEIGHT.length > 0);
    assert(HolderLinux.AppSettings.KEY_WINDOW_MAXIMIZED.length > 0);
    assert(HolderLinux.AppSettings.KEY_SIDEBAR_WIDTH.length > 0);
    assert(HolderLinux.AppSettings.KEY_TINY_CLOSE_STREAK.length > 0);
    assert(HolderLinux.AppSettings.KEY_CUSTOM_CARD_LINK_KINDS.length > 0);
    assert(HolderLinux.AppSettings.KEY_GIT_GITHUB_USERNAME.length > 0);
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
    Test.add_func("/app_settings/schema_candidate_dir_for_executable_path",
                  test_schema_candidate_dir_for_executable_path);
    Test.add_func("/app_settings/has_compiled_schema_in_dir_false_for_missing",
                  test_has_compiled_schema_in_dir_false_for_missing);
    Test.add_func("/app_settings/has_compiled_schema_in_dir_true_when_file_exists",
                  test_has_compiled_schema_in_dir_true_when_file_exists);
    Test.add_func("/app_settings/open_or_null_for_invalid_executable_emits_warning_and_returns_null",
                  test_open_or_null_for_invalid_executable_emits_warning_and_returns_null);
    Test.add_func("/app_settings/emit_warning_without_sink_logs_warning",
                  test_emit_warning_without_sink_logs_warning);
    Test.add_func("/app_settings/open_or_null_uses_default_schema_lookup_when_available_subprocess",
                  test_open_or_null_uses_default_schema_lookup_when_available_subprocess);
    Test.add_func("/app_settings/open_or_null_when_read_link_fails_returns_null",
                  test_open_or_null_when_read_link_fails_returns_null);
    Test.add_func("/app_settings/open_or_null_for_bad_local_schema_dir_emits_warning_and_returns_null",
                  test_open_or_null_for_bad_local_schema_dir_emits_warning_and_returns_null);
    Test.add_func("/app_settings/open_or_null_when_local_schema_missing_emits_specific_warning",
                  test_open_or_null_when_local_schema_missing_emits_specific_warning);
    Test.add_func("/app_settings/key_constants_are_non_empty",
                  test_key_constants_are_non_empty);
    return Test.run();
}
