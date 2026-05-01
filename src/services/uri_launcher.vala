namespace HolderLinux {

public interface IUriLauncher : Object {
    public abstract void launch(string uri) throws Error;
}

// LCOV_EXCL_START
// GCOVR_EXCL_START
// Thin GLib desktop-launcher shim, not meaningful application behavior.
internal class AppInfoUriLauncher : Object, IUriLauncher {
    public void launch(string uri) throws Error {
        AppInfo.launch_default_for_uri(uri, null);
    }
}
// GCOVR_EXCL_STOP
// LCOV_EXCL_STOP

}
