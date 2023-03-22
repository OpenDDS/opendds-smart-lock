import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi;

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

enum LockState { unlocked, pendingUnlock, locked, pendingLock }

typedef Messenger = Void Function(Pointer<Char>);

class Bridge {
  late Pointer<OpenDdsBridge> bridge;
  static Function snack = (message) {};

  Bridge() {
    bridge = _bindings.createOpenDdsBridge();
  }

  void start(
      Function func,
      String ini,
      String idCa,
      String permCa,
      String permGov,
      String permPerms,
      String idCert,
      String idPrivateKey) async {
    snack = func;

    final Pointer<OpenDdsBridgeConfig> config =
        ffi.malloc<OpenDdsBridgeConfig>();
    config.ref.ini = ini.toNativeUtf8().cast<Char>();
    config.ref.id_ca = idCa.toNativeUtf8().cast<Char>();
    config.ref.perm_ca = permCa.toNativeUtf8().cast<Char>();
    config.ref.perm_gov = permGov.toNativeUtf8().cast<Char>();
    config.ref.perm_perms = permPerms.toNativeUtf8().cast<Char>();
    config.ref.id_cert = idCert.toNativeUtf8().cast<Char>();
    config.ref.id_pkey = idPrivateKey.toNativeUtf8().cast<Char>();
    config.ref.receiver = Pointer.fromFunction(receive);

    _bindings.startOpenDdsBridge(bridge, config);

    ffi.malloc.free(config.ref.ini);
    ffi.malloc.free(config.ref.id_ca);
    ffi.malloc.free(config.ref.perm_ca);
    ffi.malloc.free(config.ref.perm_gov);
    ffi.malloc.free(config.ref.perm_perms);
    ffi.malloc.free(config.ref.id_cert);
    ffi.malloc.free(config.ref.id_pkey);
    ffi.malloc.free(config);
  }

  void updateLockState(String id, LockState state) {
    final Pointer<SmartLockStatus> status = ffi.malloc<SmartLockStatus>();
    status.ref.id = id.toNativeUtf8().cast<Char>();
    switch (state) {
      case LockState.locked:
        status.ref.state = State.LOCKED;
        break;
      case LockState.pendingLock:
        status.ref.state = State.PENDING_LOCK;
        break;
      case LockState.pendingUnlock:
        status.ref.state = State.PENDING_UNLOCK;
        break;
      case LockState.unlocked:
        status.ref.state = State.UNLOCKED;
        break;
    }
    _bindings.updateOpenDdsBridgeLockState(bridge, status);
    ffi.malloc.free(status.ref.id);
    ffi.malloc.free(status);
  }

  static void receive(Pointer<Char> message) {
    String msg = message.cast<ffi.Utf8>().toDartString();
    snack(msg);
  }
  static void shutdown() {
    _bindings.shutdownOpenDdsBridge();
  }

  void dispose() {
    _bindings.destroyOpenDdsBridge(bridge);
    bridge = nullptr;
  }
}
