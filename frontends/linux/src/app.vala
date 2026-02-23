namespace HolderLinux {

public class App : Adw.Application {
    private int startup_width;
    private int startup_height;

    public App(int startup_width = 0, int startup_height = 0) {
        Object(
            application_id: "io.holder.linux",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
        this.startup_width = startup_width;
        this.startup_height = startup_height;

        var quit_action = new SimpleAction("quit", null);
        quit_action.activate.connect(() => {
            quit();
        });
        add_action(quit_action);

        set_accels_for_action("win.new-card", {"<Primary>n"});
        set_accels_for_action("win.new-project", {"<Primary><Shift>n"});
        set_accels_for_action("win.find-replace", {"<Primary>f", "<Primary>h"});
        set_accels_for_action("win.print", {"<Primary>p"});
        set_accels_for_action("win.refresh", {"<Primary>r"});
        set_accels_for_action("win.toggle-toolbox", {"<Primary>b"});
        set_accels_for_action("app.quit", {"<Primary>q"});
    }

    protected override void activate() {
        var window = this.active_window as MainWindow;
        if (window == null) {
            window = new MainWindow(this, startup_width, startup_height);
        }
        window.present();
    }
}

}
