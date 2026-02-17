namespace HolderLinux {

public class App : Adw.Application {
    public App() {
        Object(
            application_id: "io.holder.linux",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
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
