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
                                     bool inject_initial_api = true) {
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
            search_selection,
            search_text,
            editor_text,
            new MainControllerFakeApiFactory(api, api),
            discovery ?? new FakeServerDiscovery(),
            clock,
            scheduler,
            inject_initial_api ? (initial_api ?? api) : null
        );
    }
}

}
