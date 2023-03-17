#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct {
  void* ptr;
} OpenDdsBridge;

FFI_PLUGIN_EXPORT OpenDdsBridge* createOpenDdsBridge();
FFI_PLUGIN_EXPORT void destroyOpenDdsBridge(OpenDdsBridge* bridge);

FFI_PLUGIN_EXPORT void startOpenDdsBridge(OpenDdsBridge* bridge);
FFI_PLUGIN_EXPORT void shutdownOpenDdsBridge();

#if defined(__cplusplus)
}
#endif
