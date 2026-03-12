namespace HolderLinux {

internal class SelectionController : Object {
    private MainController owner;

    public SelectionController(MainController owner) {
        this.owner = owner;
    }

    public void on_project_selected() {
        owner.reload_cards_for_selected_project.begin();
    }

    public void on_card_selected() {
        owner.load_selected_card.begin();
    }
}

}
