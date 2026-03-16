namespace HolderLinux {

public delegate void CardActionConfirmed();

internal class CardActionDialogAdapter : Object {
    private Gtk.Window parent;

    public CardActionDialogAdapter(Gtk.Window parent) {
        this.parent = parent;
    }

    public void confirm_move_to_trash(string card_title, owned CardActionConfirmed on_confirmed) {
        var dialog = new Adw.MessageDialog(
            parent,
            "Move to Trash",
            "Move \"%s\" to Trash?\n\nYou can restore it from the Trash tool.".printf(card_title)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("trash", "Move to Trash");
        dialog.set_response_appearance("trash", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("trash");
        dialog.set_close_response("cancel");
        dialog.response.connect((response) => {
            if (response == "trash") {
                on_confirmed();
            }
            dialog.close();
        });
        dialog.present();
    }

    public void confirm_create_linked_card(string target, owned CardActionConfirmed on_confirmed) {
        var dialog = new Adw.MessageDialog(
            parent,
            "Create Linked Card?",
            "No card matches [[%s]] in this project.".printf(target)
        );
        dialog.add_response("cancel", "Cancel");
        dialog.add_response("create", "Create Card");
        dialog.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("create");
        dialog.set_close_response("cancel");
        dialog.response.connect((response) => {
            if (response == "create") {
                on_confirmed();
            }
            dialog.close();
        });
        dialog.present();
    }
}

}
