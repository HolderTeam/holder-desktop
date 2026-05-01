namespace HolderLinux {

internal class WindowRecoveryContext : Object, IRecoveryContext {
    private MainController owner;

    public WindowRecoveryContext(MainController owner) {
        this.owner = owner;
    }

    public IHolderApi? get_api_client() {
        return owner.get_api_client();
    }

    public async void reload_everything() {
        yield owner.reload_everything();
    }
}

}
