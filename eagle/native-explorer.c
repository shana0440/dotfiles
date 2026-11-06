// Prefix-local Explorer adapter. Preserve Wine's desktop and shell startup.
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>
#include <wctype.h>
#include <stdlib.h>

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, WCHAR *command, int show)
{
    (void)instance;
    (void)previous;
    (void)show;
    int count = 0;
    WCHAR **args = CommandLineToArgvW(GetCommandLineW(), &count);
    if (!args) return 1;
    WCHAR *target = count > 1 ? args[1] : L"";
    if (!_wcsnicmp(target, L"/select,", 8)) {
        target += 8;
        if (!*target && count > 2) target = args[2];
    }
    while (iswspace(*target)) target++;
    if (*target == L'"') target++;

    // Only filesystem paths go native; /desktop and other shell switches retain
    // the real Explorer. This also works when Eagle invokes Explorer directly.
    if ((iswalpha(target[0]) && target[1] == L':') ||
        (target[0] == L'\\' && target[1] == L'\\')) {
        WCHAR *path = _wcsdup(target);
        if (!path) {
            LocalFree(args);
            return 1;
        }
        size_t length = wcslen(path);
        if (length && path[length - 1] == L'"') path[length - 1] = 0;
        char *helper = getenv("EAGLE_NATIVE_REVEAL");
        typedef char * (__cdecl *unix_path_fn)(const WCHAR *);
        typedef LONG (WINAPI *spawn_fn)(char * const [], int);
        unix_path_fn unix_path = (unix_path_fn)(void *)GetProcAddress(
            GetModuleHandleW(L"kernel32.dll"), "wine_get_unix_file_name");
        spawn_fn spawn = (spawn_fn)(void *)GetProcAddress(
            GetModuleHandleW(L"ntdll.dll"), "__wine_unix_spawnvp");
        char *filename = unix_path ? unix_path(path) : NULL;
        free(path);
        if (helper && filename && spawn) {
            char *native_args[] = { helper, filename, NULL };
            LONG status = spawn(native_args, 0);
            HeapFree(GetProcessHeap(), 0, filename);
            if (!status) {
                LocalFree(args);
                return 0;
            }
        } else if (filename) {
            HeapFree(GetProcessHeap(), 0, filename);
        }
    }

    LocalFree(args);
    const WCHAR *original = L"C:\\windows\\system32\\eagle-wine-explorer.exe";
    size_t length = wcslen(original) + wcslen(command) + 5;
    WCHAR *forward = calloc(length, sizeof(WCHAR));
    if (!forward) return 1;
    swprintf(forward, length, L"\"%ls\" %ls", original, command);
    STARTUPINFOW startup = { .cb = sizeof(startup) };
    PROCESS_INFORMATION process;
    BOOL started = CreateProcessW(original, forward, NULL, NULL, FALSE, 0,
                                  NULL, NULL, &startup, &process);
    free(forward);
    if (!started) return 1;
    CloseHandle(process.hThread);
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(process.hProcess, &code);
    CloseHandle(process.hProcess);
    return code;
}
