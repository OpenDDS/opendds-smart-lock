#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#  if !defined(LOCAL_TEST)
#    include <windows.h>
#  endif
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

typedef enum { UNLOCKED, PENDING_UNLOCK, LOCKED, PENDING_LOCK } State;
typedef struct {
  const char* id;
  State state;
  int enabled;
} SmartLockStatus;

typedef void (*notifier)(const char* message);
typedef void (*lock_update)(const SmartLockStatus* status);

typedef struct {
  // The full path of the ini file.
  const char* ini;

  // These are downloaded from the Permissions Manager and are
  // stored as files in the documents directory.  The values here
  // are the full path names.
  const char* id_ca;
  const char* perm_ca;
  const char* perm_gov;
  const char* perm_perms;
  const char* id_cert;
  const char* id_pkey;

  // The user of the bridge can provide a function to receive
  // message back from the bridge.
  notifier receiver;

  // In order to call back into Dart from another thread, it
  // must be done through a mechanism that can be forced through
  // the main thread.  We should be able to use Dart_PostCObject_DL().
  // But, that was causing a segmentation fault.  As a last resort,
  // I fell back to sending data through a loopback socket.
  short send_port;
} OpenDdsBridgeConfig;

FFI_PLUGIN_EXPORT OpenDdsBridge* createOpenDdsBridge();
FFI_PLUGIN_EXPORT void destroyOpenDdsBridge(OpenDdsBridge* bridge);

FFI_PLUGIN_EXPORT void startOpenDdsBridge(OpenDdsBridge* bridge,
                                          const OpenDdsBridgeConfig* config);
FFI_PLUGIN_EXPORT void updateOpenDdsBridgeLockState(OpenDdsBridge* bridge,
                                                    const SmartLockStatus* status);
FFI_PLUGIN_EXPORT void shutdownOpenDdsBridge();

#if defined(__cplusplus)
}
#endif
