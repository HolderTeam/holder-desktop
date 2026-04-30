namespace HolderLinux {

internal class FlowboardContextController : Object {
    private uint latest_request_serial = 0;

    public uint begin_request() {
        latest_request_serial++;
        return latest_request_serial;
    }

    public async void load_context(uint request_serial,
                                   string project_id,
                                   string? parent_card_id,
                                   IHolderApi? api,
                                   FlowboardController flowboard_controller) {
        if (api == null) {
            return;
        }

        try {
            var context = yield api.get_card_context(project_id, parent_card_id);
            if (request_serial != latest_request_serial) {
                return;
            }
            flowboard_controller.apply_card_context(project_id, parent_card_id, context);
        } catch (Error e) {
            warning("Flowboard context load failed for %s: %s", project_id, e.message);
        }
    }
}

}
