namespace HolderLinux {

public delegate string? VariableLookup(string name);

[CCode (cname = "chdir", cheader_filename = "unistd.h")]
private extern int change_directory(string path);

// The GTK runtime of a macOS app bundle lives inside the bundle, and GTK has to be told where. The
// launcher used to set these variables just before starting the desktop; the desktop now does it
// itself, so it can be the program a bundle starts. Nothing happens outside a bundle, and a
// variable that is already set (by the launcher, or by a developer) is left as it is.
public class BundleEnvironment : Object {
    // The variables and where each points, relative to the bundle's Contents/Resources.
    private const string[] VARIABLES = {
        "GSETTINGS_SCHEMA_DIR", "share/glib-2.0/schemas",
        "GIO_MODULE_DIR", "lib/gio/modules",
        "GDK_PIXBUF_MODULE_FILE", "lib/gdk-pixbuf-2.0/2.10.0/loaders.cache",
        "GTK_PATH", "lib/gtk-4.0",
        "XDG_DATA_DIRS", "share",
        "ENCHANT_CONFIG_DIR", "share/enchant-2",
        "DICPATH", "share/enchant/hunspell",
    };

    // Contents/Resources of the bundle the program runs from, or null when it does not run from a
    // bundle that carries the GTK runtime. The program is either in Contents/Resources/bin (today)
    // or in Contents/MacOS (when the desktop is the bundle's main executable).
    public static string? runtime_root(string? program_dir) {
        if (program_dir == null) {
            return null;
        }
        var dir = (!) program_dir;
        string? resources = null;
        var parent = Path.get_dirname(dir);
        if (Path.get_basename(dir) == "bin" && Path.get_basename(parent) == "Resources") {
            resources = parent;
        } else if (Path.get_basename(dir) == "MacOS" && Path.get_basename(parent) == "Contents") {
            resources = Path.build_filename(parent, "Resources");
        }
        if (resources == null) {
            return null;
        }
        var contents = Path.get_dirname((!) resources);
        if (Path.get_basename(contents) != "Contents") {
            return null;
        }
        if (!FileUtils.test(Path.build_filename((!) resources, "share", "glib-2.0", "schemas"), FileTest.IS_DIR)) {
            return null;
        }
        return resources;
    }

    // The variables to set, as name and value pairs, leaving out any that are already set.
    public static string[] plan(string resources, VariableLookup lookup) {
        string[] steps = {};
        for (int i = 0; i + 1 < VARIABLES.length; i += 2) {
            var current = lookup(VARIABLES[i]);
            if (current != null && ((!) current) != "") {
                continue;
            }
            steps += VARIABLES[i];
            steps += Path.build_filename(resources, VARIABLES[i + 1]);
        }
        return steps;
    }

    // Sets the variables for the bundle the program runs from, if it runs from one, and enters its
    // Contents/Resources directory. Call it before GTK starts: some of its libraries read these early.
    public static void configure(string? program_dir) {
        var root = runtime_root(program_dir);
        if (root == null) {
            return;
        }
        var steps = plan((!) root, (name) => Environment.get_variable(name));
        for (int i = 0; i + 1 < steps.length; i += 2) {
            Environment.set_variable(steps[i], steps[i + 1], false);
        }

        // The loader cache for gdk-pixbuf lists its modules relative to Contents/Resources, which
        // resolves against the working directory, and a bundle opened from Finder starts in /. The
        // launcher this replaces always changed into Contents/Resources before starting the app, so
        // the modules (GIF, SVG, BMP, ICO and other formats GTK does not decode itself) kept working.
        if (change_directory((!) root) != 0) {
            warning("Could not enter %s; image formats that need a gdk-pixbuf module may not load", (!) root);
        }
    }
}

}
