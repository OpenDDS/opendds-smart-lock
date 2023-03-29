import 'dart:ffi';
import 'dart:io';

import 'smartlock_idl_plugin_bindings_generated.dart';

const String _libName = 'smartlock_idl_plugin';

/// The dynamic library in which the symbols for [SmartlockIdlPluginBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final SmartlockIdlPluginBindings _bindings = SmartlockIdlPluginBindings(_dylib);

class Bridge {
  late Pointer<OpenDdsBridge> bridge;

  Bridge() {
    bridge = _bindings.createOpenDdsBridge();
  }

  // Once the C++ code starts to actually do something, we will may need
  // to modify this to use "isolates".
  void start() async {
    _bindings.startOpenDdsBridge(bridge);
  }

  static void shutdown() {
    _bindings.shutdownOpenDdsBridge();
  }

  void dispose() {
    _bindings.destroyOpenDdsBridge(bridge);
    bridge = nullptr;
  }
}
