namespace HolderLinux {

public class NavigationBreadcrumbs : Object {
    private Gtk.Box breadcrumb_bar;
    public Gtk.Widget widget { get; private set; }

    public signal void segment_activated(int index);

    public NavigationBreadcrumbs() {
        breadcrumb_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        breadcrumb_bar.update_property(Gtk.AccessibleProperty.LABEL, "Toolbox breadcrumbs", -1);
        breadcrumb_bar.set_hexpand(true);
        widget = breadcrumb_bar;
    }

    public void set_segments(Gee.ArrayList<NavigationBreadcrumbSegment> segments) {
        clear_box_children(breadcrumb_bar);
        for (int i = 0; i < segments.size; i++) {
            var segment = segments[i];
            if (segment.clickable) {
                var btn = new Gtk.Button.with_label(segment.label);
                btn.add_css_class("flat");
                if (segment.emphasized) {
                    btn.add_css_class("title-5");
                } else {
                    btn.add_css_class("heading");
                }
                int idx = segment.index;
                btn.clicked.connect(() => {
                    segment_activated(idx);
                });
                breadcrumb_bar.append(btn);
            } else {
                var label = new Gtk.Label(segment.label) { xalign = 0.0f };
                if (segment.emphasized) {
                    label.add_css_class("title-5");
                } else {
                    label.add_css_class("heading");
                }
                breadcrumb_bar.append(label);
            }

            if (i < segments.size - 1) {
                var sep = new Gtk.Label("  >  ");
                sep.add_css_class("dim-label");
                breadcrumb_bar.append(sep);
            }
        }
    }

    private void clear_box_children(Gtk.Box box) {
        Gtk.Widget? child = box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            box.remove(child);
            child = next;
        }
    }
}

}
