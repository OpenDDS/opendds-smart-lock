import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' show join, basename;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'package:smartlock_idl_plugin/smartlock_idl_plugin.dart'
    as smartlock_idl;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const String _apiURL = "https://dpm.unityfoundation.io/api";
  static const String _username = "54";
  static const String _password = "WNg97wLeR7Rk5eHz";
  static const String _nonce = "mobile";
  final List<String> _text = [];
  final ScrollController _scrollController = ScrollController();
  smartlock_idl.Bridge? _bridge;

  // TESTING:
  smartlock_idl.LockState state = smartlock_idl.LockState.unlocked;

  @override
  void initState() {
    super.initState();
    _bridge = smartlock_idl.Bridge();
    startBridge();
  }

  Future<Map<String, String>> downloadCerts(String directory) async {
    Map<String, String> certs = {};
    final dio = Dio();
    dio.interceptors.add(CookieManager(CookieJar()));

    var response = await dio.post("$_apiURL/login",
        options: Options(
          followRedirects: false,
          headers: {"Content-Type": "application/json"},
          validateStatus: (status) => status! < 500,
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
            options: Options(
              headers: headers,
              validateStatus: (status) => status! < 500,
            ));
        if (response.statusCode == 200) {
          certs[entry.key] = filename;
        }
      }
      final filename = join(directory, "keypair.json");
      response = await dio.download(
          "$_apiURL/applications/key_pair?nonce=$_nonce", filename,
          options: Options(
            headers: headers,
            validateStatus: (status) => status! < 500,
          ));
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
      }
    }
    return certs;
  }

  void startBridge() async {
    // Read the ini config file from the assets
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = documentsDirectory.path;
    final ini = File(join(path, 'opendds_config.ini'));
    ini.writeAsStringSync(
        await rootBundle.loadString('assets/opendds_config.ini'));

    final certs = await downloadCerts(path);

    // Start the bridge if we have all of the certs
    if (certs.containsKey('id_private')) {
      _bridge?.start(
          snack,
          tryToUpdateLock,
          ini.path,
          certs['id_ca']!,
          certs['perm_ca']!,
          certs['perm_gov']!,
          certs['perm_perms']!,
          certs['id_cert']!,
          certs['id_private']!);
    }
  }

  void snack(String message) {
    // Check to see if this widget is mounted, since this is called
    // by the bridge from the native code and it would have no idea if
    // this screen is still around.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void tryToUpdateLock(bool enabled, String id, smartlock_idl.LockState state) {
    setState(() {
      _text.add("$enabled - $id - $state");
    });
  }

  @override
  dispose() {
    super.dispose();
    smartlock_idl.Bridge.shutdown();
    _bridge?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Packages'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Text(
                  'A SmartLock bridge was created and started in initState()',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _text.add("${_text.length} The UI is reactive.");
                      if (state == smartlock_idl.LockState.unlocked) {
                        state = smartlock_idl.LockState.locked;
                      } else {
                        state = smartlock_idl.LockState.unlocked;
                      }
                      _bridge?.updateLockState(true, "lock1", state);
                    });
                  },
                  child: const Text("Do Something"),
                ),
                ListView(
                  controller: _scrollController,
                  shrinkWrap: true,
                  children: _text.map((t) => Text(t)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
