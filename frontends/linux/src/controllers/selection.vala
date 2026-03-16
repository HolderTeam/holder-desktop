namespace HolderLinux {

internal class SelectionController : Object {
    private MainController owner; // LCOV_EXCL_LINE: field declaration-only coverage artifact

    public SelectionController(MainController owner) {
        this.owner = owner;
    }

    public async void on_project_selected() {
        yield owner.reload_cards_for_selected_project();
    }

    public async void on_card_selected(string card_id) {
        yield owner.load_card_by_id(card_id);
    }
}

}
