private bool parse_dimension(string value, string name, out int result) {
    result = 0;
    if (!int.try_parse(value, out result) || result <= 0) {
        stderr.printf("Invalid %s value: %s\n", name, value);
        return false;
    }
    return true;
}

public int main(string[] args) {
    int width = 0;
    int height = 0;
    var forwarded = new Gee.ArrayList<string>();
    forwarded.add(args[0]);

    for (int i = 1; i < args.length; i++) {
        var arg = args[i];

        if (arg.has_prefix("--width=")) {
            if (!parse_dimension(arg.substring("--width=".length), "width", out width)) {
                return 1;
            }
            continue;
        }
        if (arg == "--width") {
            if (i + 1 >= args.length || !parse_dimension(args[++i], "width", out width)) {
                stderr.printf("Missing or invalid value for --width\n");
                return 1;
            }
            continue;
        }

        if (arg.has_prefix("--height=")) {
            if (!parse_dimension(arg.substring("--height=".length), "height", out height)) {
                return 1;
            }
            continue;
        }
        if (arg == "--height") {
            if (i + 1 >= args.length || !parse_dimension(args[++i], "height", out height)) {
                stderr.printf("Missing or invalid value for --height\n");
                return 1;
            }
            continue;
        }

        forwarded.add(arg);
    }

    return new HolderLinux.App(width, height).run(forwarded.to_array());
}
