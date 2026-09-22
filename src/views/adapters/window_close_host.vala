namespace HolderLinux {

internal class MainControllerCloseHost : Object, IWindowCloseHost {
    private MainController controller;

    public MainControllerCloseHost(MainController controller) {
        this.controller = controller;
    }

    public bool has_unsaved_editor_changes() {
        return controller.has_unsaved_editor_changes();
    }

    public bool is_editor_save_in_flight() {
        return controller.is_editor_save_in_flight();
    }

    public bool save_emergency_recovery_draft() throws Error {
        return controller.save_emergency_recovery_draft();
    }

    public async bool save_now() {
        return yield controller.save_now();
    }
}

}
