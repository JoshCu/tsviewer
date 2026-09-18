/* tsviewer-open.c -- Windows shell helper for the "Open with tsviewer" verb.
 *
 * Explorer invokes a command-line context-menu verb once per selected file,
 * so selecting four files and choosing "Open with tsviewer" would start four
 * separate viewers.  Setting MultiSelectModel=Player raises the selection
 * limit but does not change that: there is no registry setting that makes
 * Explorer pass a whole selection to one command line.
 *
 * This helper is registered as the verb instead of tsviewer.exe.  It is still
 * started once per file, but the instances find each other through a named
 * shared memory block: the first one to start collects the paths the others
 * contribute, waits briefly for the selection to finish arriving, and then
 * starts a single tsviewer.exe with all of them.
 *
 * Every failure path falls back to starting tsviewer.exe with just this
 * instance's own file, which is the behaviour before this helper existed.
 *
 * Built by the Makefile as part of "make windows"; not used on Linux.
 */

#ifndef _WIN32
#error "tsviewer-open.c is a Windows-only helper"
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>

/* Kept in step with MAX_INPUT_FILES in tsviewer_main.c by the Makefile */
#ifndef MAX_INPUT_FILES
#define MAX_INPUT_FILES 4
#endif

/* Stop collecting once no new file has arrived for this long */
#define QUIET_PERIOD_MS 300
/* Never collect for longer than this, however files keep arriving */
#define MAX_WAIT_MS 5000
#define POLL_MS 25

#define MUTEX_NAME   L"Local\\tsviewer_open_mutex_v1"
#define MAPPING_NAME L"Local\\tsviewer_open_shm_v1"

typedef struct {
    LONG  total;                              /* files offered, including dropped ones */
    LONG  stored;                             /* files actually held in path[] */
    DWORD last_tick;                          /* GetTickCount() of the most recent arrival */
    WCHAR path[MAX_INPUT_FILES][MAX_PATH];
} SharedState;

/* WAIT_ABANDONED also grants ownership; anything else, including WAIT_FAILED,
   means the block must not be touched. */
static int lock_shared(HANDLE mutex)
{
    DWORD r = WaitForSingleObject(mutex, 5000);
    return (r == WAIT_OBJECT_0 || r == WAIT_ABANDONED);
}

/* Start tsviewer.exe, which sits next to this helper, with n files. */
static void launch_viewer(WCHAR paths[][MAX_PATH], int n)
{
    static WCHAR exe[MAX_PATH];
    static WCHAR cmd[(MAX_INPUT_FILES + 1) * (MAX_PATH + 4)];
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    WCHAR *slash;
    size_t len;
    int i;

    if (n <= 0) return;

    if (GetModuleFileNameW(NULL, exe, MAX_PATH) == 0) return;
    slash = wcsrchr(exe, L'\\');
    if (!slash) return;
    slash[1] = L'\0';
    if (wcslen(exe) + wcslen(L"tsviewer.exe") >= MAX_PATH) return;
    wcscat(exe, L"tsviewer.exe");

    /* lpCommandLine must repeat the program name as argv[0] */
    cmd[0] = L'\0';
    wcscat(cmd, L"\"");
    wcscat(cmd, exe);
    wcscat(cmd, L"\"");
    for (i = 0; i < n; i++) {
        len = wcslen(cmd);
        if (len + wcslen(paths[i]) + 4 >= sizeof(cmd) / sizeof(cmd[0])) break;
        wcscat(cmd, L" \"");
        wcscat(cmd, paths[i]);
        wcscat(cmd, L"\"");
    }

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    if (CreateProcessW(exe, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR cmdline, int show)
{
    WCHAR   own[MAX_PATH];
    WCHAR   collected[MAX_INPUT_FILES][MAX_PATH];
    int     argc = 0;
    LPWSTR *argv;
    HANDLE  mutex = NULL;
    HANDLE  mapping = NULL;
    SharedState *shared = NULL;
    int     is_collector = 0;
    int     n = 0;
    LONG    total = 0;
    DWORD   started;

    (void)instance; (void)previous; (void)cmdline; (void)show;

    argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv || argc < 2) {
        if (argv) LocalFree(argv);
        return 1;
    }
    /* A path longer than MAX_PATH cannot be handed on; let tsviewer report it */
    if (wcslen(argv[1]) >= MAX_PATH) {
        LocalFree(argv);
        return 1;
    }
    wcscpy(own, argv[1]);
    LocalFree(argv);

    mutex = CreateMutexW(NULL, FALSE, MUTEX_NAME);
    if (!mutex) goto fallback;
    if (!lock_shared(mutex)) goto fallback;

    /* Whoever creates the block rather than opening it does the collecting */
    mapping = CreateFileMappingW(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE,
                                 0, sizeof(SharedState), MAPPING_NAME);
    if (!mapping) { ReleaseMutex(mutex); goto fallback; }
    is_collector = (GetLastError() != ERROR_ALREADY_EXISTS);

    shared = (SharedState *)MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0,
                                          sizeof(SharedState));
    if (!shared) { ReleaseMutex(mutex); goto fallback; }

    shared->total++;
    if (shared->stored < MAX_INPUT_FILES)
        wcscpy(shared->path[shared->stored++], own);
    shared->last_tick = GetTickCount();
    ReleaseMutex(mutex);

    if (!is_collector) {
        /* Someone else will start the viewer with this file included */
        UnmapViewOfFile(shared);
        CloseHandle(mapping);
        CloseHandle(mutex);
        return 0;
    }

    /* Wait for the rest of the selection to arrive */
    started = GetTickCount();
    for (;;) {
        DWORD quiet;
        Sleep(POLL_MS);
        if (!lock_shared(mutex)) break;
        quiet = GetTickCount() - shared->last_tick;
        /* Deliberately keep waiting once MAX_INPUT_FILES have been collected,
           so that shared->total ends up reflecting the whole selection and an
           over-limit selection can be reported rather than silently trimmed */
        if (quiet >= QUIET_PERIOD_MS) {
            ReleaseMutex(mutex);
            break;
        }
        ReleaseMutex(mutex);
        if (GetTickCount() - started > MAX_WAIT_MS) break;
    }

    if (lock_shared(mutex)) {
        n = (int)shared->stored;
        total = shared->total;
        if (n > MAX_INPUT_FILES) n = MAX_INPUT_FILES;
        for (int i = 0; i < n; i++) wcscpy(collected[i], shared->path[i]);
        ReleaseMutex(mutex);
    }

    /* Drop the shared block so the next selection starts a fresh session */
    UnmapViewOfFile(shared);
    CloseHandle(mapping);

    if (n <= 0) { CloseHandle(mutex); goto fallback; }

    launch_viewer(collected, n);

    if (total > MAX_INPUT_FILES) {
        WCHAR note[256];
        wsprintfW(note,
                  L"tsviewer can display %d files at once.\n\n"
                  L"You selected %ld files, so the first %d were opened.",
                  MAX_INPUT_FILES, (long)total, MAX_INPUT_FILES);
        MessageBoxW(NULL, note, L"tsviewer", MB_OK | MB_ICONINFORMATION);
    }

    CloseHandle(mutex);
    return 0;

fallback:
    /* Could not coordinate with the other instances: open this file alone,
       which is what would have happened without this helper at all. */
    if (shared) UnmapViewOfFile(shared);
    if (mapping) CloseHandle(mapping);
    if (mutex) CloseHandle(mutex);
    {
        WCHAR one[1][MAX_PATH];
        wcscpy(one[0], own);
        launch_viewer(one, 1);
    }
    return 0;
}
