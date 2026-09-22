namespace HolderLinux {

public enum AssetImportOutcome {
    COMPLETED,
    NEEDS_LOCATION,
    NOT_READY,
    FAILED,
    TIMED_OUT
}

public class AssetImportResult : Object {
    public AssetImportOutcome outcome { get; construct; }
    public string toast_message { get; construct; }
    public string error_title { get; construct; }
    public string error_details { get; construct; }
    public AssetImportJob? job { get; construct; }
    public bool still_selected { get; construct; }
    public bool insert_image_markdown { get; construct; }
    public string image_filename { get; construct; }

    public AssetImportResult(AssetImportOutcome outcome,
                             string toast_message = "",
                             string error_title = "",
                             string error_details = "",
                             AssetImportJob? job = null,
                             bool still_selected = false,
                             bool insert_image_markdown = false,
                             string image_filename = "") {
        Object(
            outcome: outcome,
            toast_message: toast_message,
            error_title: error_title,
            error_details: error_details,
            job: job,
            still_selected: still_selected,
            insert_image_markdown: insert_image_markdown,
            image_filename: image_filename
        );
    }
}

public delegate void ImportSelectionReader(out string? project_id, out string? card_id);

// Imports a dropped local file into the current Card's preferred Storage Location and polls
// the daemon's import job. The view applies the result to widgets (toasts, editor markdown,
// Resources tool, attachment refresh).
public class AssetImportFlow : Object {
    public const int MAX_POLL_ATTEMPTS = 600;
    public const uint POLL_INTERVAL_MS = 100;
    public const string NOT_READY_MESSAGE = "Select a Card before dropping local files.";
    public const string NEEDS_LOCATION_MESSAGE = "Add and choose a preferred Storage Location first.";
    public const string FAILED_TITLE = "Failed to import Asset";

    private IScheduler scheduler; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer
    private ImportSelectionReader selection_reader; // LCOV_EXCL_LINE GCOVR_EXCL_LINE: field released only by the generated finalizer

    public signal void status_changed(string text);

    public AssetImportFlow(IScheduler scheduler, owned ImportSelectionReader selection_reader) {
        this.scheduler = scheduler;
        this.selection_reader = (owned) selection_reader;
    }

    public static bool is_still_selected(string? current_project_id,
                                         string? current_card_id,
                                         string project_id,
                                         string card_id) {
        return current_project_id != null && current_card_id != null &&
            current_project_id == project_id && current_card_id == card_id;
    }

    public async AssetImportResult run(IResourceStorageApi? storage_api,
                                       string? project_id,
                                       string? card_id,
                                       string? source_path,
                                       string? basename) {
        if (storage_api == null || project_id == null || card_id == null || source_path == null) {
            return new AssetImportResult(AssetImportOutcome.NOT_READY, NOT_READY_MESSAGE);
        }
        var api = (!) storage_api;
        var label = basename ?? "asset";
        try {
            var locations = yield api.list_storage_locations((!) project_id);
            if (locations.preferred_location_id == null) {
                return new AssetImportResult(
                    AssetImportOutcome.NEEDS_LOCATION, NEEDS_LOCATION_MESSAGE
                );
            }
            status_changed("Importing %s…".printf(label));
            var job = yield api.start_asset_import(
                (!) project_id,
                (!) card_id,
                (!) locations.preferred_location_id,
                (!) source_path
            );
            string? last_status = null;
            for (int attempt = 0; attempt < MAX_POLL_ATTEMPTS; attempt++) {
                job = yield api.get_asset_import_job(job.job_id);
                if (job.status == "completed") {
                    if (job.resource_id == null) {
                        throw new ApiError.PROTOCOL(
                            "Completed Asset import did not return a Resource ID"
                        );
                    }
                    status_changed("Imported %s".printf(label));
                    return completed_result((!) project_id, (!) card_id, basename, job);
                }
                if (job.status == "failed") {
                    throw new ApiError.PROTOCOL(job.error ?? "Asset import failed");
                }
                if (job.status != last_status) {
                    last_status = job.status;
                    status_changed("Importing %s · %s".printf(label, job.status));
                }
                yield wait_for_poll();
            }
            return new AssetImportResult(
                AssetImportOutcome.TIMED_OUT, "", FAILED_TITLE, "Asset import timed out"
            );
        } catch (Error e) {
            return new AssetImportResult(AssetImportOutcome.FAILED, "", FAILED_TITLE, e.message);
        }
    }

    private AssetImportResult completed_result(string project_id,
                                               string card_id,
                                               string? basename,
                                               AssetImportJob job) {
        string? current_project_id;
        string? current_card_id;
        selection_reader(out current_project_id, out current_card_id);
        var still_selected = is_still_selected(
            current_project_id, current_card_id, project_id, card_id
        );
        var filename = basename ?? "image";
        return new AssetImportResult(
            AssetImportOutcome.COMPLETED,
            AssetPreviewController.import_completion_message(job),
            "",
            "",
            job,
            still_selected,
            still_selected && MarkdownResourceImageController.filename_is_image(filename),
            filename
        );
    }

    private async void wait_for_poll() {
        scheduler.schedule_once(POLL_INTERVAL_MS, () => {
            wait_for_poll.callback();
            return Source.REMOVE;
        });
        yield;
    }
}

}
