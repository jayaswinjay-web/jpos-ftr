#ifndef FLUTTER_WINDOWS_UTILS_H_
#define FLUTTER_WINDOWS_UTILS_H_

#include <string>

namespace Utils {
    void RegisterStartup();
    void UnregisterStartup();
    void StartOpenWA();
    void StopOpenWA();
    std::string GetAppDataPath();
}

#endif
