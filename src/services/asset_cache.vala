namespace HolderLinux {

public class AssetCache : Object {
    private string root_dir;
    private bool operation_in_progress = false;

    public AssetCache(string? root_dir = null) {
        this.root_dir = root_dir ?? Path.build_filename(
            Environment.get_user_cache_dir(), "holder", "asset-cache"
        );
    }

    public string cache_path_for(ResourceAsset asset) {
        return Path.build_filename(
            root_dir,
            safe_component(asset.asset_id, "asset"),
            safe_filename(asset.original_filename)
        );
    }

    public async string ensure_cached(IResourceStorageApi api,
                                      ProjectResource resource,
                                      ResourceAsset asset,
                                      Cancellable? cancellable = null) throws Error {
        yield acquire_operation(cancellable);
        try {
            var destination_path = cache_path_for(asset);
            if (validate_file(destination_path, asset)) {
                return destination_path;
            }

            var asset_dir = Path.get_dirname(destination_path);
            ensure_private_directory(asset_dir);
            var partial_path = destination_path + ".partial-" + Uuid.string_random();
            try {
                yield api.download_asset(resource.resource_id, asset.asset_id, partial_path);
                if (cancellable != null) {
                    cancellable.set_error_if_cancelled();
                }
                FileUtils.chmod(partial_path, 0600);
                if (!validate_file(partial_path, asset)) {
                    throw new IOError.INVALID_DATA(
                        "Downloaded Asset failed its size or SHA-256 integrity check."
                    );
                }
                var partial = File.new_for_path(partial_path);
                var destination = File.new_for_path(destination_path);
                partial.move(destination, FileCopyFlags.OVERWRITE, cancellable, null);
                FileUtils.chmod(destination_path, 0600);
                return destination_path;
            } catch (Error e) {
                FileUtils.remove(partial_path);
                throw e;
            }
        } finally {
            operation_in_progress = false;
        }
    }

    public async void export_cached(string cached_path,
                                    string destination_path,
                                    Cancellable? cancellable = null) throws Error {
        var source = File.new_for_path(cached_path);
        var destination = File.new_for_path(destination_path);
        yield source.copy_async(
            destination,
            FileCopyFlags.OVERWRITE,
            Priority.DEFAULT,
            cancellable,
            null
        );
    }

    public bool validate_file(string path, ResourceAsset asset) {
        if (!FileUtils.test(path, FileTest.IS_REGULAR)) {
            return false;
        }
        try {
            var file = File.new_for_path(path);
            var info = file.query_info(
                FileAttribute.STANDARD_SIZE,
                FileQueryInfoFlags.NONE,
                null
            );
            if (asset.byte_size >= 0 && info.get_size() != asset.byte_size) {
                return false;
            }
            if (asset.plaintext_sha256.strip().length == 0) {
                return true;
            }
            return checksum_for_file(file) == asset.plaintext_sha256.down();
        } catch (Error e) {
            return false;
        }
    }

    internal static string safe_filename(string filename) {
        var basename = Path.get_basename(filename.strip());
        if (basename.length == 0 || basename == "." || basename == "..") {
            return "asset";
        }
        return safe_component(basename, "asset");
    }

    private static string safe_component(string value, string fallback) {
        var out_text = new StringBuilder();
        int offset = 0;
        unichar ch;
        while (value.get_next_char(ref offset, out ch)) {
            if (ch.isalnum() || ch == '.' || ch == '-' || ch == '_') {
                out_text.append_unichar(ch);
            } else {
                out_text.append_c('_');
            }
        }
        var result = out_text.str.strip();
        if (result.length == 0 || result == "." || result == "..") {
            return fallback;
        }
        return result;
    }

    private void ensure_private_directory(string directory) throws Error {
        if (DirUtils.create_with_parents(directory, 0700) != 0 &&
            !FileUtils.test(directory, FileTest.IS_DIR)) {
            throw new IOError.FAILED("Could not create private Asset cache directory.");
        }
        FileUtils.chmod(root_dir, 0700);
        FileUtils.chmod(directory, 0700);
    }

    private static string checksum_for_file(File file) throws Error {
        var checksum = new Checksum(ChecksumType.SHA256);
        var stream = file.read(null);
        uint8[] buffer = new uint8[64 * 1024];
        while (true) {
            var count = stream.read(buffer, null);
            if (count <= 0) {
                break;
            }
            checksum.update(buffer, (size_t) count);
        }
        stream.close(null);
        return checksum.get_string().down();
    }

    private async void acquire_operation(Cancellable? cancellable) throws Error {
        while (operation_in_progress) {
            if (cancellable != null) {
                cancellable.set_error_if_cancelled();
            }
            Timeout.add(20, () => {
                acquire_operation.callback();
                return Source.REMOVE;
            });
            yield;
        }
        if (cancellable != null) {
            cancellable.set_error_if_cancelled();
        }
        operation_in_progress = true;
    }
}

}
