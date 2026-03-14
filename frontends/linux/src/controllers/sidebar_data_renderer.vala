namespace HolderLinux {

internal class SidebarDataRenderer : Object {
    private GLib.ListStore project_store;
    private GLib.ListStore card_store;
    private GLib.ListStore ai_thread_store;

    public SidebarDataRenderer(GLib.ListStore project_store,
                               GLib.ListStore card_store,
                               GLib.ListStore ai_thread_store) {
        this.project_store = project_store;
        this.card_store = card_store;
        this.ai_thread_store = ai_thread_store;
    }

    public void apply(Gee.ArrayList<Project> projects,
                      Gee.ArrayList<CardSummary> cards,
                      Gee.ArrayList<AiThreadSummary> ai_threads) {
        project_store.remove_all();
        foreach (var project in projects) {
            project_store.append(project);
        }

        card_store.remove_all();
        foreach (var card in cards) {
            card_store.append(card);
        }

        ai_thread_store.remove_all();
        foreach (var thread in ai_threads) {
            ai_thread_store.append(thread);
        }
    }
}

}
