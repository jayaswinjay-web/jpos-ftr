#include "utils.h"
#include <windows.h>
#include <winreg.h>
#include <string>
#include <shlobj.h>

namespace Utils {

void RegisterStartup() {
    HKEY hkey;
    if (RegOpenKeyEx(HKEY_CURRENT_USER,
                     L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                     0, KEY_SET_VALUE, &hkey) == ERROR_SUCCESS) {
        wchar_t path[MAX_PATH];
        GetModuleFileName(NULL, path, MAX_PATH);
        RegSetValueEx(hkey, L"JayPOS", 0, REG_SZ,
                      (BYTE*)path, (wcslen(path) + 1) * sizeof(wchar_t));
        RegCloseKey(hkey);
    }
}

void UnregisterStartup() {
    HKEY hkey;
    if (RegOpenKeyEx(HKEY_CURRENT_USER,
                     L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                     0, KEY_SET_VALUE, &hkey) == ERROR_SUCCESS) {
        RegDeleteValue(hkey, L"JayPOS");
        RegCloseKey(hkey);
    }
}

void StartOpenWA() {
    STARTUPINFO si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    wchar_t command[] = L"node openwa-server.js";
    if (CreateProcess(NULL, command, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }
}

void StopOpenWA() {
    system("taskkill /f /im node.exe 2>nul");
}

std::string GetAppDataPath() {
    wchar_t path[MAX_PATH];
    if (SHGetFolderPath(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, path) == S_OK) {
        wchar_t app_path[MAX_PATH];
        wcscpy_s(app_path, path);
        wcscat_s(app_path, L"\\JayPOS");
        CreateDirectory(app_path, NULL);
        char mb_path[MAX_PATH];
        WideCharToMultiByte(CP_UTF8, 0, app_path, -1, mb_path, MAX_PATH, NULL, NULL);
        return std::string(mb_path);
    }
    return "";
}

}
