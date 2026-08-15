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
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
        this.startup_width = startup_width;
        this.startup_height = startup_height;

        var quit_action = new SimpleAction("quit", null);
        quit_action.activate.connect(() => {
            quit(); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: signal callback edge artifact
        });
        add_action(quit_action);

        set_accels_for_action("win.new-card", {"<Primary>n"});
        set_accels_for_action("win.new-project", {"<Primary><Shift>n"});
        set_accels_for_action("win.flowboard-new-child-card", {"<Primary><Alt>n"});
        set_accels_for_action("win.find-replace", {"<Primary>f", "<Primary>h"});
        set_accels_for_action("win.print", {"<Primary>p"});
        set_accels_for_action("win.refresh", {"<Primary>r"});
        set_accels_for_action("win.toggle-toolbox", {"<Primary>b"});
        set_accels_for_action("win.show-preferences", {"<Primary>comma"});
        set_accels_for_action("app.quit", {"<Primary>q"}); // LCOV_EXCL_BR_LINE GCOVR_EXCL_BR_LINE: accelerator normalization branch artifact
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
