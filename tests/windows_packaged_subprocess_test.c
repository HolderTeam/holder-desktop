#include <gio/gio.h>
#include <string.h>

/* Exercise the same piped GSubprocess launch used to detect gh in the GUI.
 * Invoke a built-in Windows command so this test needs no installed gh or Git. */
int main(void) {
    const gchar *system_root = g_getenv("SystemRoot");
    if (system_root == NULL) return 1;
    gchar *cmd = g_build_filename(system_root, "System32", "cmd.exe", NULL);
    GError *error = NULL;
    GSubprocess *process = g_subprocess_new(
        G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_PIPE,
        &error, cmd, "/d", "/c", "echo holder-subprocess-ok", NULL);
    g_free(cmd);
    gchar *output = NULL;
    gchar *diagnostic = NULL;
    gboolean ok = process != NULL &&
        g_subprocess_communicate_utf8(process, NULL, NULL, &output, &diagnostic, &error) &&
        g_subprocess_get_successful(process) &&
        output != NULL && strcmp(g_strstrip(output), "holder-subprocess-ok") == 0;
    if (!ok) {
        g_printerr("Packaged subprocess failed: %s\n",
                   error != NULL ? error->message : (diagnostic != NULL ? diagnostic : "unexpected output"));
    }
    g_clear_error(&error);
    g_free(output);
    g_free(diagnostic);
    g_clear_object(&process);
    return ok ? 0 : 1;
}
