import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
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

typedef SnackCallback = Function(String);
typedef LockUpdate = Function(bool, String, LockState);

class Bridge {
  late Pointer<OpenDdsBridge> bridge;
  static ServerSocket? server;
  static const int port = 31214;
  static SnackCallback snack = (message) {};
  static LockUpdate update = (enabled, id, state) {};

  /// Initializes the underlying OpenDdsBridge.
  Bridge() {
    bridge = _bindings.createOpenDdsBridge();
  }

  /// Start the OpenDdsBridge.
  ///
  /// The receiver will be given string messages from the native code.
  ///
  /// The uiLockUpdater will be given lock status info from the native code.
  void start(
      SnackCallback receiver,
      LockUpdate uiLockUpdater,
      String ini,
      String idCa,
      String permCa,
      String permGov,
      String permPerms,
      String idCert,
      String idPrivateKey) async {
    // Create a server socket and listen on that port, if we haven't done so
    // already.
    if (server == null) {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      server?.listen((client) => client.listen(_lockUpdate));
    }

    // Keep a reference to these functions for use in our own static methods
    // that we will give to the native code.
    snack = receiver;
    update = uiLockUpdater;

    final Pointer<OpenDdsBridgeConfig> config =
        ffi.malloc<OpenDdsBridgeConfig>();
    config.ref.ini = ini.toNativeUtf8().cast<Char>();
    config.ref.id_ca = idCa.toNativeUtf8().cast<Char>();
    config.ref.perm_ca = permCa.toNativeUtf8().cast<Char>();
    config.ref.perm_gov = permGov.toNativeUtf8().cast<Char>();
    config.ref.perm_perms = permPerms.toNativeUtf8().cast<Char>();
    config.ref.id_cert = idCert.toNativeUtf8().cast<Char>();
    config.ref.id_pkey = idPrivateKey.toNativeUtf8().cast<Char>();
    config.ref.receiver = Pointer.fromFunction(_receive);
    config.ref.send_port = port;

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

  /// Sends lock state information to the native code to send to the lock.
  void updateLockState(bool enabled, String id, LockState state) {
    final Pointer<SmartLockStatus> status = ffi.malloc<SmartLockStatus>();
    status.ref.id = id.toNativeUtf8().cast<Char>();
    status.ref.enabled = enabled ? 1 : 0;
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

  static void _receive(Pointer<Char> message) {
    snack(message.cast<ffi.Utf8>().toDartString());
  }

  static void _lockUpdate(Uint8List data) async {
    int index = 0;
    final nativeState = data[index++];
    final nativeEnabled = data[index++];
    final String id = String.fromCharCodes(data, index);

    LockState state = LockState.locked;
    switch (nativeState) {
      case State.LOCKED:
        state = LockState.locked;
        break;
      case State.PENDING_LOCK:
        state = LockState.pendingLock;
        break;
      case State.PENDING_UNLOCK:
        state = LockState.pendingUnlock;
        break;
      case State.UNLOCKED:
      default:
        state = LockState.unlocked;
        break;
    }
    final bool enabled = nativeEnabled == 0 ? false : true;

    update(enabled, id, state);
  }

  /// Shuts down the OpenDdsBridge.
  static void shutdown() {
    _bindings.shutdownOpenDdsBridge();
  }

  /// Destroys the OpenDdsBridge associated with this class.
  void dispose() {
    _bindings.destroyOpenDdsBridge(bridge);
    bridge = nullptr;
  }
}
