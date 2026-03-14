namespace HolderLinux {

internal class SelectionController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public SelectionController(MainController owner) {
        this.owner = owner;
    }

    public async void on_project_selected() {
        yield owner.reload_cards_for_selected_project();
    }

    public async void on_card_selected() {
        yield owner.load_selected_card();
    }
}

}
