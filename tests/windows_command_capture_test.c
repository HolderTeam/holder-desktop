#include <gio/gio.h>
#include <glib/gstdio.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

gchar *holder_windows_capture_command(gchar **argv, gint *exit_code, GError **error);
gchar *holder_windows_program_directory(void);
void holder_windows_capture_async(gchar **argv, GAsyncReadyCallback callback, gpointer data);
gchar *holder_windows_capture_finish(GAsyncResult *result, gint *exit_code, GError **error);

typedef struct { GMainLoop *loop; gboolean passed; } State;

static void captured(GObject *source, GAsyncResult *result, gpointer data) {
    State *state = data;
    GError *error = NULL;
    gint status = -1;
    gchar *output = holder_windows_capture_finish(result, &status, &error);
    state->passed = error == NULL && status == 7 && output != NULL &&
        strcmp(output, "space \"quoted\" & literal\\\nerror-output") == 0;
    g_clear_error(&error);
    g_free(output);
    g_main_loop_quit(state->loop);
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--sleeper") == 0) {
        Sleep((DWORD)atoi(argv[2]));
        return 0;
    }
    if (argc == 2 && strcmp(argv[1], "--leaky-child") == 0) {
        /* Start a long-lived descendant that inherits our standard handles, as a daemon started
         * by a command-line tool can, then finish at once. */
        STARTUPINFOW startup = { sizeof startup };
        startup.dwFlags = STARTF_USESTDHANDLES;
        startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
        wchar_t path[MAX_PATH];
        if (GetModuleFileNameW(NULL, path, MAX_PATH) == 0) return 6;
        wchar_t command[MAX_PATH + 32];
        _snwprintf(command, sizeof command / sizeof command[0], L"\"%ls\" --sleeper 6000", path);
        PROCESS_INFORMATION process = { 0 };
        if (!CreateProcessW(path, command, NULL, NULL, TRUE,
                            DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP, NULL, NULL, &startup, &process)) {
            return 5;
        }
        CloseHandle(process.hThread);
        CloseHandle(process.hProcess);
        DWORD count;
        if (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), "started", 7, &count, NULL)) return 7;
        return 0;
    }
    if (argc == 3 && strcmp(argv[1], "--child") == 0) {
        DWORD count;
        if (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), argv[2], strlen(argv[2]), &count, NULL)) return 2;
        if (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), "\n", 1, &count, NULL)) return 3;
        if (!WriteFile(GetStdHandle(STD_ERROR_HANDLE), "error-output", 12, &count, NULL)) return 4;
        return 7;
    }
    /* Reproduce a GUI launched without a console or usable standard handles. */
    FreeConsole();
    SetStdHandle(STD_INPUT_HANDLE, NULL);
    SetStdHandle(STD_OUTPUT_HANDLE, NULL);
    SetStdHandle(STD_ERROR_HANDLE, NULL);
    gchar *command[] = { argv[0], "--child", "space \"quoted\" & literal\\", NULL };
    State state = { g_main_loop_new(NULL, FALSE), FALSE };
    holder_windows_capture_async(command, captured, &state);
    g_main_loop_run(state.loop);
    g_main_loop_unref(state.loop);
    if (!state.passed) return 1;

    /* A program that leaves a long-lived child holding the pipe must not make the capture wait for
     * that child: the child lives for six seconds, the capture must return well before. */
    {
        gchar *leaky[] = { argv[0], "--leaky-child", NULL };
        GError *leaky_error = NULL;
        gint leaky_status = -1;
        gint64 started = g_get_monotonic_time();
        gchar *leaky_output = holder_windows_capture_command(leaky, &leaky_status, &leaky_error);
        gint64 elapsed_ms = (g_get_monotonic_time() - started) / 1000;
        gboolean leaky_ok = leaky_error == NULL && leaky_status == 0 && leaky_output != NULL &&
            strcmp(leaky_output, "started") == 0 && elapsed_ms < 3000;
        g_clear_error(&leaky_error);
        g_free(leaky_output);
        if (!leaky_ok) return 8;
    }

    /* The program directory is where this executable lives. */
    {
        gchar *directory = holder_windows_program_directory();
        gchar *expected = g_path_get_dirname(argv[0]);
        gchar *absolute = g_canonicalize_filename(expected, NULL);
        gboolean directory_ok = FALSE;
        if (directory != NULL) {
            /* Windows accepts either slash; compare with one kind, ignoring case. */
            g_strdelimit(directory, "/", '\\');
            g_strdelimit(absolute, "/", '\\');
            directory_ok = g_ascii_strcasecmp(directory, absolute) == 0;
        }
        g_free(directory);
        g_free(expected);
        g_free(absolute);
        if (!directory_ok) return 9;
    }

    /* A source launch's PATH can exclude the native CLI installation. Use a
     * disposable standard install directory containing this test executable. */
    GError *setup_error = NULL;
    gchar *temporary = g_dir_make_tmp("holder-cli-discovery-XXXXXX", &setup_error);
    if (temporary == NULL) { g_clear_error(&setup_error); return 1; }
    gchar *cli_directory = g_build_filename(temporary, "GitHub CLI", NULL);
    gchar *cli_path = g_build_filename(cli_directory, "gh.exe", NULL);
    GFile *source_file = g_file_new_for_path(argv[0]);
    GFile *target_file = g_file_new_for_path(cli_path);
    gboolean copied = g_mkdir(cli_directory, 0700) == 0 &&
        g_file_copy(source_file, target_file, G_FILE_COPY_NONE, NULL, NULL, NULL, &setup_error);
    g_object_unref(source_file);
    g_object_unref(target_file);
    gboolean discovery_ok = FALSE;
    if (copied) {
        /* Keep runtime DLLs discoverable for the copied child while excluding
         * native CLI installations from PATH. */
        WCHAR runtime_path[MAX_PATH];
        GetModuleFileNameW(GetModuleHandleW(L"libglib-2.0-0.dll"), runtime_path, MAX_PATH);
        gchar *runtime_utf8 = g_utf16_to_utf8((gunichar2 *)runtime_path, -1, NULL, NULL, NULL);
        gchar *runtime_directory = g_path_get_dirname(runtime_utf8);
        gchar *child_path = g_strconcat(temporary, ";", runtime_directory, NULL);
        g_setenv("PATH", child_path, TRUE);
        g_free(child_path);
        g_free(runtime_directory);
        g_free(runtime_utf8);
        g_setenv("ProgramFiles", temporary, TRUE);
        gchar *cli_command[] = { "gh", "--child", "space \"quoted\" & literal\\", NULL };
        gint cli_status;
        gchar *cli_output = holder_windows_capture_command(cli_command, &cli_status, &setup_error);
        discovery_ok = setup_error == NULL && cli_status == 7 && cli_output != NULL &&
            strcmp(cli_output, "space \"quoted\" & literal\\\nerror-output") == 0;
        g_free(cli_output);
    }
    g_clear_error(&setup_error);
    g_unlink(cli_path);
    g_rmdir(cli_directory);
    g_rmdir(temporary);
    g_free(cli_path);
    g_free(cli_directory);
    g_free(temporary);
    if (!discovery_ok) return 1;

    GError *error = NULL;
    gint status;
    gchar *missing[] = { "__holder_missing_windows_command__", NULL };
    gchar *output = holder_windows_capture_command(missing, &status, &error);
    gboolean missing_ok = output == NULL && g_error_matches(error, G_IO_ERROR, G_IO_ERROR_NOT_FOUND);
    g_free(output);
    g_clear_error(&error);
    return missing_ok ? 0 : 1;
}
