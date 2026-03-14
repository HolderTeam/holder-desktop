namespace HolderLinux {

public class ToolboxNavigationController : Object {
    private uint current_sequence = 0;

    public uint begin_navigation() {
        current_sequence++;
        return current_sequence;
    }

    public bool is_current(uint sequence) {
        return sequence == current_sequence;
    }
}

}
