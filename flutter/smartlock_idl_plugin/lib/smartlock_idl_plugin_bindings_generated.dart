// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names

// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
import 'dart:ffi' as ffi;

/// Bindings for `src/smartlock_idl_plugin.h`.
///
/// Regenerate bindings with `flutter pub run ffigen --config ffigen.yaml`.
///
class SmartlockIdlPluginBindings {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  SmartlockIdlPluginBindings(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  SmartlockIdlPluginBindings.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  ffi.Pointer<OpenDdsBridge> createOpenDdsBridge() {
    return _createOpenDdsBridge();
  }

  late final _createOpenDdsBridgePtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<OpenDdsBridge> Function()>>(
          'createOpenDdsBridge');
  late final _createOpenDdsBridge = _createOpenDdsBridgePtr
      .asFunction<ffi.Pointer<OpenDdsBridge> Function()>();

  void destroyOpenDdsBridge(
    ffi.Pointer<OpenDdsBridge> bridge,
  ) {
    return _destroyOpenDdsBridge(
      bridge,
    );
  }

  late final _destroyOpenDdsBridgePtr = _lookup<
          ffi.NativeFunction<ffi.Void Function(ffi.Pointer<OpenDdsBridge>)>>(
      'destroyOpenDdsBridge');
  late final _destroyOpenDdsBridge = _destroyOpenDdsBridgePtr
      .asFunction<void Function(ffi.Pointer<OpenDdsBridge>)>();

  void startOpenDdsBridge(
    ffi.Pointer<OpenDdsBridge> bridge,
    ffi.Pointer<OpenDdsBridgeConfig> config,
  ) {
    return _startOpenDdsBridge(
      bridge,
      config,
    );
  }

  late final _startOpenDdsBridgePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(ffi.Pointer<OpenDdsBridge>,
              ffi.Pointer<OpenDdsBridgeConfig>)>>('startOpenDdsBridge');
  late final _startOpenDdsBridge = _startOpenDdsBridgePtr.asFunction<
      void Function(
          ffi.Pointer<OpenDdsBridge>, ffi.Pointer<OpenDdsBridgeConfig>)>();

  void updateOpenDdsBridgeLockState(
    ffi.Pointer<OpenDdsBridge> bridge,
    ffi.Pointer<SmartLockStatus> status,
  ) {
    return _updateOpenDdsBridgeLockState(
      bridge,
      status,
    );
  }

  late final _updateOpenDdsBridgeLockStatePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(ffi.Pointer<OpenDdsBridge>,
              ffi.Pointer<SmartLockStatus>)>>('updateOpenDdsBridgeLockState');
  late final _updateOpenDdsBridgeLockState =
      _updateOpenDdsBridgeLockStatePtr.asFunction<
          void Function(
              ffi.Pointer<OpenDdsBridge>, ffi.Pointer<SmartLockStatus>)>();

  void shutdownOpenDdsBridge() {
    return _shutdownOpenDdsBridge();
  }

  late final _shutdownOpenDdsBridgePtr =
      _lookup<ffi.NativeFunction<ffi.Void Function()>>('shutdownOpenDdsBridge');
  late final _shutdownOpenDdsBridge =
      _shutdownOpenDdsBridgePtr.asFunction<void Function()>();
}

class OpenDdsBridge extends ffi.Struct {
  external ffi.Pointer<ffi.Void> ptr;
}

abstract class State {
  static const int UNLOCKED = 0;
  static const int PENDING_UNLOCK = 1;
  static const int LOCKED = 2;
  static const int PENDING_LOCK = 3;
}

class SmartLockStatus extends ffi.Struct {
  external ffi.Pointer<ffi.Char> id;

  @ffi.Int32()
  external int state;

  @ffi.Int()
  external int enabled;
}

class OpenDdsBridgeConfig extends ffi.Struct {
  /// The full path of the ini file.
  external ffi.Pointer<ffi.Char> ini;

  /// These are downloaded from the Permissions Manager and are
  /// stored as files in the documents directory.  The values here
  /// are the full path names.
  external ffi.Pointer<ffi.Char> id_ca;

  external ffi.Pointer<ffi.Char> perm_ca;

  external ffi.Pointer<ffi.Char> perm_gov;

  external ffi.Pointer<ffi.Char> perm_perms;

  external ffi.Pointer<ffi.Char> id_cert;

  external ffi.Pointer<ffi.Char> id_pkey;

  /// The user of the bridge can provide a function to receive
  /// message back from the bridge.
  external notifier receiver;

  /// In order to call back into Dart from another thread, it
  /// must be done through a mechanism that can be forced through
  /// the main thread.  We will be using Dart_PostCObject_DL().
  @ffi.Int64()
  external int send_port;

  /// Configuration Items.
  external ffi.Pointer<ffi.Char> group;

  external ffi.Pointer<ffi.Char> topic_prefix;

  @ffi.Int32()
  external int domain_id;
}

typedef notifier
    = ffi.Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>;
