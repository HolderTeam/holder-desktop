using GLib;

namespace HolderLinuxTests {

public class MainControllerTestHarness : Object {
    public GLib.ListStore project_store;
    public GLib.ListStore card_store;
    public GLib.ListStore thread_store;
    public GLib.ListStore search_store;
    public StoreSelectionState project_selection;
    public StoreSelectionState card_selection;
    public StoreSelectionState thread_selection;
    public StoreSelectionState search_selection;
    public MutableTextProvider search_text;
    public MutableTextProvider editor_text;
    public HolderLinux.MainController controller;

    public MainControllerTestHarness(MainControllerFakeApi api,
                                     TestScheduler scheduler,
                                     FakeClock clock,
                                     FakeServerDiscovery? discovery = null,
                                     HolderLinux.IHolderApi? initial_api = null,
                                     bool inject_initial_api = true,
                                     HolderLinux.IEditorRecoveryDraftService? recovery_draft_service = null,
                                     HolderLinux.IExplorerStateSink? explorer_state_sink = null) {
        project_store = new GLib.ListStore(typeof(HolderLinux.Project));
        card_store = new GLib.ListStore(typeof(HolderLinux.CardSummary));
        thread_store = new GLib.ListStore(typeof(HolderLinux.AiThreadSummary));
        search_store = new GLib.ListStore(typeof(HolderLinux.SearchCardResult));
        project_selection = new StoreSelectionState(project_store);
        card_selection = new StoreSelectionState(card_store);
        thread_selection = new StoreSelectionState(thread_store);
        search_selection = new StoreSelectionState(search_store);
        search_text = new MutableTextProvider();
        editor_text = new MutableTextProvider();
        controller = new HolderLinux.MainController(
            project_store,
            project_selection,
            card_store,
            card_selection,
            thread_store,
            thread_selection,
            search_store,
            search_text,
            editor_text,
            new MainControllerFakeApiFactory(api, api),
            discovery ?? new FakeServerDiscovery(),
            clock,
            scheduler,
            inject_initial_api ? (initial_api ?? api) : null,
            explorer_state_sink,
            recovery_draft_service
        );

        controller.editor_state_changed.connect((text, editable) => {
            editor_text.value = text;
        });

        controller.project_selection_requested.connect((project_id) => {
            if (project_id == null || project_id.strip().length == 0) {
                project_selection.set_selected_index(uint.MAX);
                return;
            }
            for (uint i = 0; i < project_store.get_n_items(); i++) {
                var project = project_store.get_item(i) as HolderLinux.Project;
                if (project != null && project.project_id == project_id) {
                    project_selection.set_selected_index(i);
                    return;
                }
            }
            project_selection.set_selected_index(uint.MAX);
        });

        controller.card_selection_requested.connect((card_id) => {
            if (card_id == null || card_id.strip().length == 0) {
                card_selection.set_selected_index(uint.MAX);
                return;
            }
            for (uint i = 0; i < card_store.get_n_items(); i++) {
                var card = card_store.get_item(i) as HolderLinux.CardSummary;
                if (card != null && card.card_id == card_id) {
                    card_selection.set_selected_index(i);
                    return;
                }
            }
            card_selection.set_selected_index(uint.MAX);
        });
    }
}

}
