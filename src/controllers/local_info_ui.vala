namespace HolderLinux {

internal class LocalInfoUiController : Object {
    private LocalInfoFlowController local_info_flow_controller;
    private LocalInfoViewAdapter local_info_view_adapter;

    public LocalInfoUiController(LocalInfoFlowController local_info_flow_controller,
                                 LocalInfoViewAdapter local_info_view_adapter) {
        this.local_info_flow_controller = local_info_flow_controller;
        this.local_info_view_adapter = local_info_view_adapter;
    }

    public async void show_page() {
        var result = yield local_info_flow_controller.load();
        switch (result.state) {
        case LocalInfoLoadState.NOT_CONNECTED:
            local_info_view_adapter.render_not_connected();
            break;
        case LocalInfoLoadState.SUCCESS:
            local_info_view_adapter.render_success(result.markdown);
            break;
        case LocalInfoLoadState.FAILURE:
            local_info_view_adapter.render_failure(result.error_details);
            break;
        }
    }
}

}
