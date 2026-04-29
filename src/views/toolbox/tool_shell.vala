namespace HolderLinux {

public class ToolShell : Object {
    private Gtk.Box root;
    private Gtk.Box header_row;
    private ToolActionBar action_bar;
    private Gtk.Box content_row;

    public Gtk.Widget widget { get; private set; }

    public ToolShell(NavigationBreadcrumbs breadcrumbs, Gtk.Widget switcher) {
        root = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        header_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        breadcrumbs.widget.set_hexpand(true);
        header_row.append(breadcrumbs.widget);
        header_row.append(switcher);
        root.append(header_row);

        action_bar = new ToolActionBar();
        root.append(action_bar.widget);

        content_row = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        content_row.set_hexpand(true);
        content_row.set_vexpand(true);
        root.append(content_row);

        widget = root;
    }

    public void set_actions_widget(Gtk.Widget? actions) {
        action_bar.set_actions_widget(actions);
    }

    public void set_loading(bool loading) {
        action_bar.set_loading(loading);
    }

    public void set_content_widget(Gtk.Widget child) {
        Gtk.Widget? existing = content_row.get_first_child();
        while (existing != null) {
            var next = existing.get_next_sibling();
            content_row.remove(existing);
            existing = next;
        }
        content_row.append(child);
    }
}

}
