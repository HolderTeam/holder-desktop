namespace HolderLinux {

public class ToolActionBar : Object {
    private Gtk.Box root;
    private Gtk.Box actions_slot;
    private Gtk.Spinner spinner;
    private Gtk.Widget? current_actions;
    public Gtk.Widget widget { get; private set; }

    public ToolActionBar() {
        root = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        root.set_hexpand(true);

        actions_slot = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        actions_slot.set_hexpand(true);
        root.append(actions_slot);

        spinner = new Gtk.Spinner();
        spinner.set_visible(false);
        root.append(spinner);

        widget = root;
    }

    public void set_actions_widget(Gtk.Widget? actions) {
        if (current_actions != null) {
            actions_slot.remove((!) current_actions);
            current_actions = null;
        }
        if (actions != null) {
            actions_slot.append(actions);
            current_actions = actions;
            root.set_visible(true);
            return;
        }
        root.set_visible(false);
    }

    public void set_loading(bool loading) {
        spinner.set_visible(loading);
        if (loading) {
            spinner.start();
        } else {
            spinner.stop();
        }
    }
}

}
