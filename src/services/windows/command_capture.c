#include <gio/gio.h>

#ifdef __APPLE__
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdlib.h>
#endif

#ifdef G_OS_WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/* Quote one argv element using Windows CRT rules, without a command shell. */
static void append_argument(GString *command, const gchar *argument) {
    g_string_append_c(command, '"');
    guint slashes = 0;
    for (const gchar *p = argument; ; ++p) {
        if (*p == '\\') { ++slashes; continue; }
        guint count = (*p == '"' || *p == '\0') ? slashes * 2 : slashes;
        for (guint i = 0; i < count; ++i) g_string_append_c(command, '\\');
        slashes = 0;
        if (*p == '\0') break;
        if (*p == '"') g_string_append_c(command, '\\');
        g_string_append_c(command, *p);
    }
    g_string_append_c(command, '"');
}

static gchar *find_command(const gchar *name) {
    gchar *found = g_find_program_in_path(name);
    if (found != NULL || (g_ascii_strcasecmp(name, "gh") != 0 &&
                          g_ascii_strcasecmp(name, "gh.exe") != 0)) return found;

    /* Explorer can retain an old PATH, and MSYS2 omits native Windows CLI
     * installations. Prefer PATH, then the standard GitHub CLI locations. */
    const gchar *variables[] = { "ProgramFiles", "ProgramW6432", "LOCALAPPDATA" };
    for (guint i = 0; i < G_N_ELEMENTS(variables); ++i) {
        const gchar *base = g_getenv(variables[i]);
        if (base == NULL || *base == '\0') continue;
        gchar *candidate = i == 2
            ? g_build_filename(base, "Programs", "GitHub CLI", "gh.exe", NULL)
            : g_build_filename(base, "GitHub CLI", "gh.exe", NULL);
        if (g_file_test(candidate, G_FILE_TEST_IS_REGULAR)) return candidate;
        g_free(candidate);
    }
    return NULL;
}
#endif

/* GLib's GUI spawn helper redirects CRT descriptors but some Windows tools
 * read Win32 standard handles instead. Supply explicit handles for those tools.
 * The caller runs this blocking capture on a worker thread. */
/* The directory this program runs from on macOS, with links resolved, or NULL if it cannot be found
 * (and always off macOS). Free with g_free. */
gchar *holder_macos_program_directory(void) {
#ifdef __APPLE__
    uint32_t size = 0;
    _NSGetExecutablePath(NULL, &size); /* reports the length needed */
    gchar *buffer = g_malloc0((gsize)size + 1);
    if (_NSGetExecutablePath(buffer, &size) != 0) {
        g_free(buffer);
        return NULL;
    }
    char resolved[PATH_MAX];
    gchar *directory = realpath(buffer, resolved) != NULL ? g_path_get_dirname(resolved)
                                                           : g_path_get_dirname(buffer);
    g_free(buffer);
    return directory;
#else
    return NULL;
#endif
}

/* The directory this program was started from, or NULL if it cannot be found (and always off
 * Windows, where /proc or the platform has its own way). Free with g_free. */
gchar *holder_windows_program_directory(void) {
#ifdef G_OS_WIN32
    wchar_t path[32768];
    DWORD length = GetModuleFileNameW(NULL, path, G_N_ELEMENTS(path));
    if (length == 0 || length >= G_N_ELEMENTS(path)) return NULL;
    gchar *full = g_utf16_to_utf8((const gunichar2 *)path, (glong)length, NULL, NULL, NULL);
    if (full == NULL) return NULL;
    gchar *directory = g_path_get_dirname(full);
    g_free(full);
    return directory;
#else
    return NULL;
#endif
}

gchar *holder_windows_capture_command(gchar **argv, gint *exit_code, GError **error) {
#ifdef G_OS_WIN32
    gchar *executable = find_command(argv[0]);
    if (executable == NULL) {
        g_set_error(error, G_IO_ERROR, G_IO_ERROR_NOT_FOUND, "Executable not found: %s", argv[0]);
        return NULL;
    }
    GString *command = g_string_new(NULL);
    for (guint i = 0; argv[i] != NULL; ++i) {
        if (i != 0) g_string_append_c(command, ' ');
        append_argument(command, argv[i]);
    }
    gunichar2 *application = g_utf8_to_utf16(executable, -1, NULL, NULL, error);
    gunichar2 *arguments = application != NULL ? g_utf8_to_utf16(command->str, -1, NULL, NULL, error) : NULL;
    g_free(executable);
    g_string_free(command, TRUE);
    if (arguments == NULL) { g_free(application); return NULL; }

    SECURITY_ATTRIBUTES security = { sizeof security, NULL, TRUE };
    HANDLE read_pipe = NULL, write_pipe = NULL, input = INVALID_HANDLE_VALUE;
    PROCESS_INFORMATION process = { 0 };
    STARTUPINFOEXW startup = { 0 };
    SIZE_T attributes_size = 0;
    DWORD failure = ERROR_SUCCESS;
    GString *output = g_string_new(NULL);
    gchar *result = NULL;
    startup.StartupInfo.cb = sizeof startup;
    if (!CreatePipe(&read_pipe, &write_pipe, &security, 0) ||
        !SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0)) goto failed;
    input = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                        &security, OPEN_EXISTING, 0, NULL);
    if (input == INVALID_HANDLE_VALUE) goto failed;
    InitializeProcThreadAttributeList(NULL, 1, 0, &attributes_size);
    startup.lpAttributeList = g_malloc0(attributes_size);
    if (!InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &attributes_size)) {
        failure = GetLastError();
        g_clear_pointer(&startup.lpAttributeList, g_free);
        goto failed;
    }
    HANDLE inherited[] = { input, write_pipe };
    if (!UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                                   inherited, sizeof inherited, NULL, NULL)) goto failed;
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startup.StartupInfo.hStdInput = input;
    startup.StartupInfo.hStdOutput = write_pipe;
    startup.StartupInfo.hStdError = write_pipe;
    if (!CreateProcessW((LPCWSTR)application, (LPWSTR)arguments, NULL, NULL, TRUE,
                        CREATE_NO_WINDOW | EXTENDED_STARTUPINFO_PRESENT, NULL, NULL,
                        &startup.StartupInfo, &process)) goto failed;
    CloseHandle(write_pipe); write_pipe = NULL;
    /* Read until the program has exited and what it wrote is drained, not until the pipe closes:
     * a program that starts a long-lived child, as holderctl does when it starts the daemon, can
     * leave that child holding the pipe's write end, and waiting for it to close would wait for
     * the child to exit. The exit is checked before the drain so output written before it is
     * not missed. */
    gchar buffer[4096];
    DWORD count;
    gboolean exited = FALSE;
    for (;;) {
        if (!exited && WaitForSingleObject(process.hProcess, 0) == WAIT_OBJECT_0) exited = TRUE;
        DWORD available = 0;
        if (!PeekNamedPipe(read_pipe, NULL, 0, NULL, &available, NULL)) {
            if (GetLastError() != ERROR_BROKEN_PIPE) goto failed;
            break; /* every writer has closed its end */
        }
        if (available > 0) {
            DWORD wanted = available < sizeof buffer ? available : (DWORD)sizeof buffer;
            if (!ReadFile(read_pipe, buffer, wanted, &count, NULL)) {
                if (GetLastError() != ERROR_BROKEN_PIPE) goto failed;
                break;
            }
            g_string_append_len(output, buffer, count);
            continue;
        }
        if (exited) break;
        WaitForSingleObject(process.hProcess, 20);
    }
    if (WaitForSingleObject(process.hProcess, INFINITE) != WAIT_OBJECT_0) goto failed;
    DWORD status;
    if (!GetExitCodeProcess(process.hProcess, &status)) goto failed;
    *exit_code = (gint)status;
    result = g_utf8_make_valid(output->str, output->len);
    goto cleanup;
failed:
    if (failure == ERROR_SUCCESS) failure = GetLastError();
    if (process.hProcess != NULL) {
        TerminateProcess(process.hProcess, 1);
        WaitForSingleObject(process.hProcess, 1000);
    }
    g_set_error(error, G_IO_ERROR, g_io_error_from_win32_error(failure),
                "Could not capture command output (Windows error %lu)", failure);
cleanup:
    if (process.hThread != NULL) CloseHandle(process.hThread);
    if (process.hProcess != NULL) CloseHandle(process.hProcess);
    if (read_pipe != NULL) CloseHandle(read_pipe);
    if (write_pipe != NULL) CloseHandle(write_pipe);
    if (input != INVALID_HANDLE_VALUE) CloseHandle(input);
    if (startup.lpAttributeList != NULL) {
        DeleteProcThreadAttributeList(startup.lpAttributeList);
        g_free(startup.lpAttributeList);
    }
    g_string_free(output, TRUE);
    g_free(application);
    g_free(arguments);
    return result;
#else
    g_set_error_literal(error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED, "Windows command capture is unavailable");
    return NULL;
#endif
}

typedef struct {
    gchar *output;
    gint status;
} CaptureResult;

static void capture_result_free(gpointer pointer) {
    CaptureResult *result = pointer;
    g_free(result->output);
    g_free(result);
}

static void capture_worker(GTask *task, gpointer source, gpointer argv, GCancellable *cancellable) {
    CaptureResult *result = g_new0(CaptureResult, 1);
    GError *error = NULL;
    result->output = holder_windows_capture_command(argv, &result->status, &error);
    if (error != NULL) {
        capture_result_free(result);
        g_task_return_error(task, error);
    } else {
        g_task_return_pointer(task, result, capture_result_free);
    }
}

void holder_windows_capture_async(gchar **argv, GAsyncReadyCallback callback, gpointer user_data) {
    GTask *task = g_task_new(NULL, NULL, callback, user_data);
    g_task_set_task_data(task, g_strdupv(argv), (GDestroyNotify)g_strfreev);
    g_task_run_in_thread(task, capture_worker);
    g_object_unref(task);
}

gchar *holder_windows_capture_finish(GAsyncResult *async_result, gint *exit_code, GError **error) {
    CaptureResult *result = g_task_propagate_pointer(G_TASK(async_result), error);
    if (result == NULL) return NULL;
    *exit_code = result->status;
    gchar *output = result->output;
    g_free(result);
    return output;
}
