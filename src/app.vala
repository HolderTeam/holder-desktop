namespace HolderLinux {

public class App : Adw.Application {
    public App() {
        Object(
            application_id: "io.holder.linux",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );

        var quit_action = new SimpleAction("quit", null);
        quit_action.activate.connect(() => {
            quit();
        });
        add_action(quit_action);

        set_accels_for_action("win.new-card", {"<Primary>n"});
        set_accels_for_action("win.new-project", {"<Primary><Shift>n"});
        set_accels_for_action("win.refresh", {"<Primary>r"});
        set_accels_for_action("app.quit", {"<Primary>q"});
    }

    protected override void activate() {
        var window = this.active_window as MainWindow;
        if (window == null) {
            window = new MainWindow(this);
        }
        window.present();
    }
}

}
