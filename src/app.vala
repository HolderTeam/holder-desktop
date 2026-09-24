namespace HolderLinux {

public class App : Adw.Application {
    private const string DEFAULT_APPLICATION_ID = "team.holder.Holder";

    private int startup_width;
    private int startup_height;

    private static string resolve_application_id() {
        var configured_id = Environment.get_variable("HOLDER_DESKTOP_APPLICATION_ID");
        if (configured_id != null && configured_id.strip() != "") {
            return configured_id;
        }
        return DEFAULT_APPLICATION_ID;
    }

    public App(int startup_width = 0, int startup_height = 0) {
        Object(
            application_id: resolve_application_id(),
            resource_base_path: "/team/holder/Holder",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
        this.startup_width = startup_width;
        this.startup_height = startup_height;

        var quit_action = new SimpleAction("quit", null);
        quit_action.activate.connect(() => {
            var window = active_window;
            if (window != null) {
                window.close(); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: requires display-backed windowing environment
            } else {
                quit();
            }
        });
        add_action(quit_action);

        // GTK expects null-terminated arrays; Vala constants need an explicit sentinel.
        const string[] WIN_NEW_CARD_ACCELS = {"<Primary>n", null};
        set_accels_for_action("win.new-card", WIN_NEW_CARD_ACCELS);
        const string[] WIN_NEW_PROJECT_ACCELS = {"<Primary><Shift>n", null};
        set_accels_for_action("win.new-project", WIN_NEW_PROJECT_ACCELS);
        const string[] WIN_FLOWBOARD_NEW_CHILD_CARD_ACCELS = {"<Primary><Alt>n", null};
        set_accels_for_action("win.flowboard-new-child-card", WIN_FLOWBOARD_NEW_CHILD_CARD_ACCELS);
        const string[] WIN_FIND_REPLACE_ACCELS = {"<Primary>f", "<Primary>h", null};
        set_accels_for_action("win.find-replace", WIN_FIND_REPLACE_ACCELS);
        const string[] WIN_PRINT_ACCELS = {"<Primary>p", null};
        set_accels_for_action("win.print", WIN_PRINT_ACCELS);
        const string[] WIN_REFRESH_ACCELS = {"<Primary>r", null};
        set_accels_for_action("win.refresh", WIN_REFRESH_ACCELS);
        const string[] WIN_SAVE_ACCELS = {"<Primary>s", null};
        set_accels_for_action("win.save", WIN_SAVE_ACCELS);
        const string[] WIN_SHOW_PREFERENCES_ACCELS = {"<Primary>comma", null};
        set_accels_for_action("win.show-preferences", WIN_SHOW_PREFERENCES_ACCELS);
        const string[] APP_QUIT_ACCELS = {"<Primary>q", null};
        set_accels_for_action("app.quit", APP_QUIT_ACCELS); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: accelerator normalization branch artifact
    } // LCOV_EXCL_LINE GCOVR_EXCL_LINE: Vala constructor closing brace coverage artifact

    protected override void activate() { // LCOV_EXCL_LINE GCOVR_EXCL_LINE: requires display-backed windowing environment
        var window = this.active_window as MainWindow; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: requires display-backed windowing environment
        if (window == null) { // LCOV_EXCL_LINE GCOVR_EXCL_LINE: requires display-backed windowing environment
            window = new MainWindow(this, startup_width, startup_height); // LCOV_EXCL_LINE GCOVR_EXCL_LINE: requires display-backed windowing environment
        }
        window.present(); // LCOV_EXCL_LINE GCOVR_EXCL_LINE LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: display backend side-effect artifact
    }
}

}
