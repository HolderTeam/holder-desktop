namespace HolderLinux {

internal interface IFindReplaceOps : Object {
    public abstract bool find_next(string find_text);
    public abstract bool replace_next(string find_text, string replace_text) throws Error;
    public abstract uint replace_all(string find_text, string replace_text) throws Error;
}

}
