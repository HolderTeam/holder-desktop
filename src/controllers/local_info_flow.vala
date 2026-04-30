namespace HolderLinux {

public interface ILocalInfoFlowContext : Object {
    public abstract IHolderApi? get_api_client();
}

public enum LocalInfoLoadState {
    NOT_CONNECTED,
    SUCCESS,
    FAILURE
}

public class LocalInfoLoadResult : Object {
    public LocalInfoLoadState state { get; private set; }
    public string markdown { get; private set; }
    public string error_details { get; private set; }

    private LocalInfoLoadResult(LocalInfoLoadState state, string markdown, string error_details) {
        this.state = state;
        this.markdown = markdown;
        this.error_details = error_details;
    }

    public static LocalInfoLoadResult not_connected() {
        return new LocalInfoLoadResult(LocalInfoLoadState.NOT_CONNECTED, "", "");
    }

    public static LocalInfoLoadResult success(string markdown) {
        return new LocalInfoLoadResult(LocalInfoLoadState.SUCCESS, markdown, "");
    }

    public static LocalInfoLoadResult failure(string details) {
        return new LocalInfoLoadResult(LocalInfoLoadState.FAILURE, "", details);
    }
}

public class LocalInfoFlowController : Object {
    private ILocalInfoFlowContext context;
    private LocalInfoController local_info_controller;

    public LocalInfoFlowController(ILocalInfoFlowContext context,
                                   LocalInfoController local_info_controller) {
        this.context = context;
        this.local_info_controller = local_info_controller;
    }

    public async LocalInfoLoadResult load() {
        var api = context.get_api_client();
        if (api == null) {
            return LocalInfoLoadResult.not_connected();
        }

        try {
            var markdown = yield local_info_controller.build_local_info_markdown(api);
            return LocalInfoLoadResult.success(markdown);
        } catch (Error e) {
            return LocalInfoLoadResult.failure(e.message);
        }
    }
}

}
