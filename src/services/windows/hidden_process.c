#include <gio/gio.h>

#ifdef G_OS_WIN32
#include <windows.h>

gboolean
holder_windows_run_hidden (const gchar *executable,
                           const gchar *command_line,
                           gint        *exit_code,
                           GError     **error)
{
  gunichar2 *application = NULL;
  gunichar2 *command = NULL;
  STARTUPINFOW startup = { 0 };
  PROCESS_INFORMATION process = { 0 };
  DWORD status;
  gboolean success = FALSE;

  application = g_utf8_to_utf16 (executable, -1, NULL, NULL, error);
  if (application == NULL)
    goto out;

  command = g_utf8_to_utf16 (command_line, -1, NULL, NULL, error);
  if (command == NULL)
    goto out;

  startup.cb = sizeof startup;
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;

  if (!CreateProcessW ((LPCWSTR) application,
                       (LPWSTR) command,
                       NULL,
                       NULL,
                       FALSE,
                       CREATE_NO_WINDOW,
                       NULL,
                       NULL,
                       &startup,
                       &process))
    {
      g_set_error (error,
                   G_IO_ERROR,
                   g_io_error_from_win32_error (GetLastError ()),
                   "Could not start PowerShell (Windows error %lu)",
                   GetLastError ());
      goto out;
    }

  status = WaitForSingleObject (process.hProcess, INFINITE);
  if (status != WAIT_OBJECT_0)
    {
      g_set_error (error, G_IO_ERROR, G_IO_ERROR_FAILED,
                   "Could not wait for PowerShell (Windows error %lu)",
                   GetLastError ());
      goto close_process;
    }

  if (!GetExitCodeProcess (process.hProcess, &status))
    {
      g_set_error (error, G_IO_ERROR, G_IO_ERROR_FAILED,
                   "Could not read PowerShell's exit status (Windows error %lu)",
                   GetLastError ());
      goto close_process;
    }

  if (exit_code != NULL)
    *exit_code = (gint) status;
  success = TRUE;

close_process:
  CloseHandle (process.hThread);
  CloseHandle (process.hProcess);
out:
  g_free (command);
  g_free (application);
  return success;
}
#else
gboolean
holder_windows_run_hidden (const gchar *executable,
                           const gchar *command_line,
                           gint        *exit_code,
                           GError     **error)
{
  (void) executable;
  (void) command_line;
  (void) exit_code;
  g_set_error_literal (error,
                       G_IO_ERROR,
                       G_IO_ERROR_NOT_SUPPORTED,
                       "Hidden Windows processes are only available on Windows");
  return FALSE;
}
#endif
