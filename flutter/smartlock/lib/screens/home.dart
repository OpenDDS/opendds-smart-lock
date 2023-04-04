import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' show join, basename;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartlock_idl_plugin/smartlock_idl_plugin.dart'
    as smartlock_idl;

import '../style/style.dart';
import 'settings.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

// Shorten the LockState enum namespace
typedef LockState = smartlock_idl.LockState;

class _LockStatus {
  bool enabled;
  LockState state;

  _LockStatus(this.enabled, this.state);
}

class _HomeState extends State<Home> {
  // Data for downloading certs.
  static const String _apiURL = "https://dpm.unityfoundation.io/api";
  static const String _username = "54";
  static const String _password = "WNg97wLeR7Rk5eHz";
  static const String _nonce = "mobile";

  // The SmartLock bridge and associated locks
  smartlock_idl.Bridge? _bridge;
  final Map<String, _LockStatus> _locks = {};
  final String _prefsLockKey = "locks";

  Future<Map<String, String>> _downloadCerts(String directory) async {
    _snack("Beginning to download the certs.");

    // Download all of the required certs and return them in a map.
    Map<String, String> certs = {};
    try {
      final dio = Dio();
      dio.interceptors.add(CookieManager(CookieJar()));

      var response = await dio.post("$_apiURL/login",
          options: Options(
            followRedirects: false,
            headers: {"Content-Type": "application/json"},
            validateStatus: (status) => status! < 400,
          ),
          data: {"username": _username, "password": _password});
      if (response.statusCode == 303) {
        Map<String, dynamic> headers = {"Content-Type": "text/plain"};
        for (var entry in {
          "id_ca": "applications/identity_ca.pem",
          "perm_ca": "applications/permissions_ca.pem",
          "perm_gov": "applications/governance.xml.p7s",
          "perm_perms": "applications/permissions.xml.p7s?nonce=$_nonce",
        }.entries) {
          String filename = join(directory, basename(entry.value));
          final int index = filename.indexOf('?');
          if (index >= 0) {
            filename = filename.substring(0, index);
          }
          response = await dio.download("$_apiURL/${entry.value}", filename,
              options: Options(headers: headers));
          if (response.statusCode == 200) {
            certs[entry.key] = filename;
          }
        }
        final filename = join(directory, "keypair.json");
        response = await dio.download(
            "$_apiURL/applications/key_pair?nonce=$_nonce", filename,
            options: Options(headers: headers));
        if (response.statusCode == 200) {
          final fp = File(filename);
          Map keyPair = json.decode(fp.readAsStringSync());
          fp.delete();

          final cert = File(join(directory, "id_cert.pem"));
          cert.writeAsStringSync(keyPair['public']);
          final privateKey = File(join(directory, "id_private.pem"));
          privateKey.writeAsStringSync(keyPair['private']);
          certs['id_cert'] = cert.path;
          certs['id_private'] = privateKey.path;

          _snack("All of the certs have been downloaded.");
        }
      }
    } catch (err) {
      _snack(err.toString());
    }
    return certs;
  }

  void _startBridge() async {
    // Read the ini config file from the assets and write it to a local file.
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = documentsDirectory.path;
    final ini = File(join(path, 'opendds_config.ini'));
    ini.writeAsStringSync(
        await rootBundle.loadString('assets/opendds_config.ini'));

    // Download the certs from the permissions manager.
    final certs = await _downloadCerts(path);

    // Start the bridge if we have all of the certs.
    if (certs.containsKey('id_private')) {
      _bridge?.start(
          _snack,
          _addOrUpdateLock,
          ini.path,
          certs['id_ca']!,
          certs['perm_ca']!,
          certs['perm_gov']!,
          certs['perm_perms']!,
          certs['id_cert']!,
          certs['id_private']!);
    } else {
      _snack("The OpenDDS Bridge has not been started.");
    }
  }

  void _snack(String message) {
    // Check to see if this widget is mounted, since this is called
    // by the bridge from the native code and it would have no idea if
    // this screen is still around.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _saveLocks() async {
    // Store the ids of the locks encoded as a jSON string as the shared
    // preferences.
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_prefsLockKey, json.encode(_locks.keys.toList()));
  }

  void _loadLocks() async {
    // Get the list of lock ids and recreate them in the locks map.  They
    // will start out disabled and unlocked until they are updated by the
    // bridge.
    final prefs = await SharedPreferences.getInstance();
    final String? ids = prefs.getString(_prefsLockKey);
    if (ids != null) {
      setState(() {
        for (String id in json.decode(ids)) {
          _locks[id] = _LockStatus(false, LockState.unlocked);
        }
      });
    }
  }

  void _addOrUpdateLock(bool enabled, String id, LockState state) {
    bool updateState = false;
    // First, see if this lock already exists.
    if (_locks.containsKey(id)) {
      // If it does, check each field and only update the UI if anything
      // actually changes.
      if (_locks[id]!.enabled != enabled) {
        updateState = true;
        _locks[id]!.enabled = enabled;
      }
      if (_locks[id]!.state != state) {
        updateState = true;
        _locks[id]!.state = state;
      }
    } else {
      // Create the lock state in our lock map.
      _locks[id] = _LockStatus(enabled, state);
      _saveLocks();
      updateState = true;
    }

    if (updateState) {
      // Calling setState() lets the UI know that it needs to update.
      setState(() {});
    }
  }

  Widget _renderLock(String id, _LockStatus status) {
    // Create a row that shows the lock id, a switch for locking and unlocking
    // the lock, an icon that shows the lock state, and a button to delete the
    // lock from the display list.
    final bool locked = status.state == LockState.locked ||
        status.state == LockState.pendingLock;
    return Row(
      children: [
        Expanded(
            child: Padding(
                padding: Style.columnPadding,
                child: Text(id, style: Style.lockIdText))),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              const Expanded(child: Text("Lock/Unlock")),
              Expanded(
                child: Switch(
                  value: locked,
                  onChanged: _locks[id]!.enabled
                      ? (bool value) {
                          // Tell our lock display that the action is pending.
                          setState(() {
                            _locks[id]!.state = value
                                ? LockState.pendingLock
                                : LockState.pendingUnlock;
                          });

                          // Send the lock state to the bridge.
                          final LockState state =
                              value ? LockState.locked : LockState.unlocked;
                          _bridge?.updateLockState(true, id, state);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: Icon(locked ? Icons.lock_outline : Icons.lock_open_rounded)),
        IconButton(
          onPressed: () => setState(() => _deleteLock(id)),
          icon: const Icon(Icons.delete_forever_outlined),
        ),
      ],
    );
  }

  Widget _renderLocks() {
    // Get the list of lock ids and sort them alphabetically.
    final List<String> keys = _locks.keys.toList();
    keys.sort();

    // Use a ListView to display each lock.  The builder iterates over the
    // list of keys for us.
    return ListView.builder(
      shrinkWrap: true,
      itemCount: keys.length,
      itemBuilder: (context, index) {
        return _renderLock(keys[index], _locks[keys[index]]!);
      },
    );
  }

  List<Widget> _bottomIcons() {
    return [
      IconButton(
        icon:
            Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
        iconSize: Style.iconSize,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Settings()),
          );
        },
      ),
    ];
  }

  void _deleteLock(String id) {
    _locks.remove(id);
    _saveLocks();
  }

  @override
  void initState() {
    super.initState();
    _loadLocks();
    _bridge = smartlock_idl.Bridge();
    _startBridge();
  }

  @override
  dispose() {
    super.dispose();
    smartlock_idl.Bridge.shutdown();
    _bridge?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make the title bar 15% of the display height and then resize the
    // logo to be 85% of that height.
    final double height = MediaQuery.of(context).size.height * .15;
    final Image image = Image(
      image: ResizeImage(
        const AssetImage('assets/logo.png'),
        height: (height * .85).toInt(),
      ),
    );

    return Scaffold(
      appBar: AppBar(toolbarHeight: height, title: image),
      body: SafeArea(child: _renderLocks()),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          padding: Style.bottomBarPadding,
          decoration: Style.bottomBarDecoration(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _bottomIcons(),
          ),
        ),
      ),
    );
  }
}
