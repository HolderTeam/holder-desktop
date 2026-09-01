using GLib;

namespace HolderLinuxTests {

private const string COMPLETE_TRANSCRIPT =
    "**********************\r\n" +
    "PowerShell transcript start\r\n" +
    "Start time: 20260901153327\r\n" +
    "PSVersion: 7.6.5\r\n" +
    "**********************\r\n" +
    "Transcript started, output file is C:\\Temp\\holder.txt\r\n" +
    "PS C:\\Work> Write-Output 'Unicode: café — 日本語 — 😀'\r\n" +
    "Unicode: café — 日本語 — 😀\r\n" +
    "PS C:\\Work> cmd.exe /c 'echo Native stdout & echo Native stderr 1>&2'\r\n" +
    "Native stdout\r\n" +
    "Native stderr\r\n" +
    "PS C:\\Work> Stop-Transcript\r\n" +
    "**********************\r\n" +
    "PowerShell transcript end\r\n" +
    "End time: 20260901153424\r\n" +
    "**********************\r\n";

private void test_complete_transcript_extracts_useful_text() {
    var parser = new HolderLinux.PowerShellTranscriptParser();
    var snapshot = parser.parse(COMPLETE_TRANSCRIPT);

    assert(snapshot.completed);
    assert(!snapshot.raw_text.contains("\r"));
    assert(!snapshot.useful_text.contains("PowerShell transcript start"));
    assert(!snapshot.useful_text.contains("Transcript started, output file"));
    assert(!snapshot.useful_text.contains("Stop-Transcript"));
    assert(snapshot.useful_text.contains("Unicode: café — 日本語 — 😀"));
    assert(snapshot.useful_text.contains("Native stdout\nNative stderr"));
}

private void test_interrupted_transcript_preserves_completed_content() {
    var parser = new HolderLinux.PowerShellTranscriptParser();
    var snapshot = parser.parse("""**********************
PowerShell transcript start
PSVersion: 7.6.5
**********************
Transcript started, output file is C:\\Temp\\holder.txt
PS C:\\Work> Get-ChildItem
file-one.txt
PS C:\\Work> ping.exe 127.0.0.1 -n 2
""");

    assert(!snapshot.completed);
    assert(snapshot.useful_text == """PS C:\\Work> Get-ChildItem
file-one.txt
PS C:\\Work> ping.exe 127.0.0.1 -n 2""");
}

private void test_plain_text_is_left_useful() {
    var parser = new HolderLinux.PowerShellTranscriptParser();
    var snapshot = parser.parse("PS> echo hello\r\nhello\r\n");

    assert(!snapshot.completed);
    assert(snapshot.useful_text == "PS> echo hello\nhello");
}

private void test_utf8_bom_is_removed() {
    var parser = new HolderLinux.PowerShellTranscriptParser();
    var snapshot = parser.parse("\xEF\xBB\xBFPS> café\r\n");

    assert(snapshot.raw_text == "PS> café\n");
    assert(snapshot.useful_text == "PS> café");
}

private void test_ansi_control_sequences_are_removed_from_useful_text() {
    var parser = new HolderLinux.PowerShellTranscriptParser();
    var snapshot = parser.parse("PS> test\n\x1b[31mfailed\x1b[0m\n");

    assert(snapshot.raw_text.contains("\x1b[31m"));
    assert(snapshot.useful_text == "PS> test\nfailed");
}

private void test_terminal_session_state_round_trip() {
    assert(HolderLinux.TerminalSessionState.from_storage_value("active")
           == HolderLinux.TerminalSessionState.ACTIVE);
    assert(HolderLinux.TerminalSessionState.from_storage_value("completed")
           == HolderLinux.TerminalSessionState.COMPLETED);
    assert(HolderLinux.TerminalSessionState.from_storage_value("unexpected")
           == HolderLinux.TerminalSessionState.INTERRUPTED);
    assert(HolderLinux.TerminalSessionState.INTERRUPTED.to_storage_value() == "interrupted");
}

public static int main(string[] args) {
    Test.init(ref args);
    Test.add_func(
        "/powershell_transcript/complete_extracts_useful_text",
        test_complete_transcript_extracts_useful_text
    );
    Test.add_func(
        "/powershell_transcript/interrupted_preserves_completed_content",
        test_interrupted_transcript_preserves_completed_content
    );
    Test.add_func(
        "/powershell_transcript/plain_text_is_left_useful",
        test_plain_text_is_left_useful
    );
    Test.add_func(
        "/powershell_transcript/utf8_bom_is_removed",
        test_utf8_bom_is_removed
    );
    Test.add_func(
        "/powershell_transcript/ansi_sequences_are_removed",
        test_ansi_control_sequences_are_removed_from_useful_text
    );
    Test.add_func(
        "/powershell_transcript/session_state_round_trip",
        test_terminal_session_state_round_trip
    );
    return Test.run();
}

}
