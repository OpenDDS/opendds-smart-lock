import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypted_shared_preferences/encrypted_shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../style/style.dart';

abstract class Setting<T, W> {
  String key;
  T value;
  Function(T) change = (T) {};

  Setting(this.key, this.value);

  Future<W?> read(dynamic prefs) async => prefs.get(key) as W;
  Future<bool> store(dynamic prefs);
  T convert(W index);
  W access(T value);
  bool valid(W index);

  Future<dynamic> getPrefs() async => await SharedPreferences.getInstance();

  Future<T> getStored() async {
    try {
      final start = access(value);
      final prefs = await getPrefs();
      W index = await read(prefs) ?? start;
      if (!valid(index)) {
        index = start;
      }
      value = convert(index);
    } catch (_) {
      // Ignored.
    }
    return value;
  }

  Future<bool> setStored(T? newValue) async {
    if (newValue == null) {
      return false;
    } else {
      value = newValue;
      change(value);
      final prefs = await getPrefs();
      return await store(prefs);
    }
  }
}

class ThemeSetting extends Setting<ThemeMode, int> {
  ThemeSetting(super.key, super.value);

  @override
  int access(ThemeMode value) => value.index;

  @override
  ThemeMode convert(int index) => ThemeMode.values[index];

  @override
  bool valid(int index) => index < ThemeMode.values.length;

  @override
  Future<bool> store(dynamic prefs) async =>
      await prefs.setInt(key, access(value));
}

class ColorSetting extends Setting<Color, int> {
  ColorSetting(super.key, super.value);

  @override
  int access(Color value) => value.value;

  @override
  Color convert(int index) => Color(index);

  @override
  bool valid(int index) => index <= 0xffffffff;

  @override
  Future<bool> store(dynamic prefs) async =>
      await prefs.setInt(key, access(value));
}

abstract class SimpleSetting<T> extends Setting<T, T> {
  SimpleSetting(super.key, super.value);

  @override
  T access(T value) => value;

  @override
  T convert(T index) => index;

  @override
  bool valid(T index) => true;
}

class BoolSetting extends SimpleSetting<bool> {
  BoolSetting(super.key, super.value);

  @override
  Future<bool> store(prefs) async => await prefs.setBool(key, access(value));
}

class IntSetting extends SimpleSetting<int> {
  IntSetting(super.key, super.value);

  @override
  Future<bool> store(prefs) async => await prefs.setInt(key, access(value));
}

class StringSetting extends SimpleSetting<String> {
  StringSetting(super.key, super.value);

  @override
  Future<bool> store(prefs) async => await prefs.setString(key, access(value));
}

class EncryptedStringSetting extends SimpleSetting<String> {
  EncryptedStringSetting(super.key, super.value);

  @override
  Future<dynamic> getPrefs() async => EncryptedSharedPreferences();

  @override
  Future<String?> read(dynamic prefs) async {
    // Because the EncryptedSharedPreferences object returns an empty string
    // if it is unable to read a string from the preferences, we will change
    // that to null (as the caller expects).
    final String s = await prefs.getString(key);
    return s.isEmpty ? null : s;
  }

  @override
  Future<bool> store(dynamic prefs) async {
    return await prefs.setString(key, access(value));
  }
}

final List<Color> _lightColors = [
  Colors.red.shade800,
  Colors.orange.shade800,
  Colors.lightGreen.shade900,
  Colors.teal.shade600,
  Colors.blue.shade800,
  Colors.indigo.shade800,
  Colors.purple.shade600,
];

final List<Color> _darkColors = [
  Colors.red.shade200,
  Colors.orange.shade300,
  Colors.yellow.shade600,
  Colors.green.shade300,
  Colors.teal.shade200,
  Colors.blue.shade200,
  Colors.indigo.shade200,
  Colors.purple.shade200,
];

class _PortInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    } else {
      final int? value = int.tryParse(newValue.text);
      return value == null || value < 0 || value > 65535 ? oldValue : newValue;
    }
  }
}

class Settings extends StatefulWidget {
  static ThemeSetting theme = ThemeSetting("themeMode", ThemeMode.system);
  static ColorSetting lightSeed = ColorSetting("lightSeed", _lightColors[3]);
  static ColorSetting darkSeed = ColorSetting("darkSeed", _darkColors[4]);
  static var username = EncryptedStringSetting("username", "54");
  static var password = EncryptedStringSetting("password", "WNg97wLeR7Rk5eHz");
  static var apiURL =
      StringSetting("apiURL", "https://dpm.unityfoundation.io/api");
  static var topicPrefix = StringSetting("topicPrefix", "C.53.");
  static var domainId = IntSetting("domainId", 1);
  static var useRelay = BoolSetting("useRelay", false);
  static var relayIP = StringSetting("relayIP", "35.224.27.187");
  static var spdpPort = IntSetting("spdpPort", 4444);
  static var sedpPort = IntSetting("sedpPort", 4445);
  static var dataPort = IntSetting("dataPort", 4446);
  static var group = StringSetting("group", "");

  static Future<void> load() async {
    await theme.getStored();
    await lightSeed.getStored();
    await darkSeed.getStored();
    await username.getStored();
    await password.getStored();
    await apiURL.getStored();
    await topicPrefix.getStored();
    await domainId.getStored();
    await useRelay.getStored();
    await relayIP.getStored();
    await spdpPort.getStored();
    await sedpPort.getStored();
    await dataPort.getStored();
    await group.getStored();
  }

  static bool validateIPAddress(String value) {
    final RegExp regex = RegExp(r'^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)');
    final RegExpMatch? match = regex.firstMatch(value);
    if (match != null) {
      for (int i = 0; i < 4; i++) {
        final int? octet = int.tryParse(match[i + 1]!);
        if (octet == null || octet < 0 || octet > 255) {
          return false;
        }
      }
    }
    return true;
  }

  final Function() download;
  final Function() restart;
  const Settings({super.key, required this.download, required this.restart});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const int _partialTextFlex = 11;
  Color? _selected;
  bool _restartChanges = false;
  bool _obscurePassword = true;
  IconData _eye = Icons.remove_red_eye;
  final List<TextInputFormatter> _portInputFormatter = [_PortInputFormatter()];
  final _usernameController =
      TextEditingController(text: Settings.username.value);
  final _passwordController =
      TextEditingController(text: Settings.password.value);
  final _apiURLController = TextEditingController(text: Settings.apiURL.value);
  final _topicPrefixController =
      TextEditingController(text: Settings.topicPrefix.value);
  final _domainIdController =
      TextEditingController(text: Settings.domainId.value.toString());
  final _relayIPController =
      TextEditingController(text: Settings.relayIP.value);
  final _spdpPortController =
      TextEditingController(text: Settings.spdpPort.value.toString());
  final _sedpPortController =
      TextEditingController(text: Settings.sedpPort.value.toString());
  final _dataPortController =
      TextEditingController(text: Settings.dataPort.value.toString());
  TextStyle? _relayIPStyle;
  TextStyle? _portStyle;
  final List<int> _originalPorts = [];
  final _groupController =
      TextEditingController(text: Settings.group.value);

  void _updateThemeMode(ThemeMode? value) {
    Settings.theme.setStored(value);
    setState(() {});
  }

  void _updateLight() {
    if (_selected != null) {
      Settings.lightSeed.setStored(_selected);
      setState(() {});
    }
  }

  void _updateDark() {
    if (_selected != null) {
      Settings.darkSeed.setStored(_selected);
      setState(() {});
    }
  }

  Widget _pickerLayout(
      BuildContext context, List<Color> colors, PickerItem child) {
    final Orientation orientation = MediaQuery.of(context).orientation;
    final count = orientation == Orientation.portrait ? 4 : 6;
    return SizedBox(
      width: double.maxFinite,
      height: 80.0 * ((colors.length > 20 ? 20 : colors.length) / count).ceil(),
      child: GridView.count(
        crossAxisCount: count,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        children: colors.map((e) => child(e)).toList(),
      ),
    );
  }

  void _showColorPicker(
      List<Color> colors, Color current, String buttonText, Function select) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select a color"),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Style.cornerRadius)),
        ),
        children: <Widget>[
          BlockPicker(
            availableColors: colors,
            pickerColor: current,
            onColorChanged: (c) => _selected = c,
            layoutBuilder: _pickerLayout,
          ),
          Container(
            padding: Style.columnPadding,
            child: ElevatedButton(
              onPressed: () {
                select();
                Navigator.pop(context);
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  void _showLightPicker() {
    _showColorPicker(
      _lightColors,
      Settings.lightSeed.value,
      "Set Light Color",
      _updateLight,
    );
  }

  void _showDarkPicker() {
    _showColorPicker(
      _darkColors,
      Settings.darkSeed.value,
      "Set Dark Color",
      _updateDark,
    );
  }

  void _updateRelayStyle() {
    // Use the text style default color if the IP address is valid.  Use
    // the theme error color, otherwise.
    Color? relayIPColor = Settings.validateIPAddress(Settings.relayIP.value)
        ? null
        : Theme.of(context).errorColor;

    // If we're using the relay, just use the color.  If we're not using the
    // relay, make the text italic and a little lighter.
    TextStyle style;
    if (Settings.useRelay.value) {
      style = TextStyle(color: relayIPColor);
      _portStyle = null;
    } else {
      _portStyle = const TextStyle(
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
      );
      style = _portStyle!.merge(TextStyle(color: relayIPColor));
    }

    // The default text style for a TextField is subtitle1.  So, we will use
    // that and merge in our additional style settings.
    _relayIPStyle = Theme.of(context).textTheme.subtitle1!.merge(style);
  }

  Widget _renderContent() {
    if (_relayIPStyle == null) {
      // _updateRelayStyle() cannot be called in initState().  But, we need
      // to update the relay style before the first screen build.  So, do it
      // here but only if we don't yet have a style.
      _updateRelayStyle();
    }

    return ListView(
      children: <Widget>[
        Padding(
          padding: Style.columnPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: Style.columnPadding,
                child: Text("Credentials", style: Style.titleText),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  controller: _apiURLController,
                  decoration: Style.hintDecoration('API URL'),
                  onChanged: (s) => Settings.apiURL.setStored(s),
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  controller: _usernameController,
                  decoration: Style.hintDecoration('Username'),
                  onChanged: (s) => Settings.username.setStored(s),
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: Row(
                  children: [
                    Expanded(
                      flex: _partialTextFlex,
                      child: TextField(
                        controller: _passwordController,
                        decoration: Style.hintDecoration('Password'),
                        onChanged: (s) => Settings.password.setStored(s),
                        obscureText: _obscurePassword,
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        onPressed: () => setState(() {
                          // Flip the obscure flag and switch the icon.
                          _obscurePassword ^= true;
                          _eye = _obscurePassword
                              ? Icons.remove_red_eye
                              : Icons.remove_red_eye_outlined;
                        }),
                        icon: Icon(_eye),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: ElevatedButton(
                  onPressed: () async {
                    if (await widget.download()) {
                      _restartChanges = true;
                    }
                  },
                  child: const Text("Download"),
                ),
              ),
              const Padding(
                padding: Style.columnPadding,
                child: Text("RTPS Relay", style: Style.titleText),
              ),
              Padding(
                padding: Style.textPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: Checkbox(
                        value: Settings.useRelay.value,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (bool? value) async {
                          await Settings.useRelay.setStored(value);
                          setState(() => _updateRelayStyle());
                        },
                      ),
                    ),
                    const Expanded(
                      flex: _partialTextFlex,
                      child: Text("Use the relay"),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Padding(
                    padding: Style.columnPadding,
                    child: Text("IP Address:"),
                  ),
                  Expanded(
                    child: TextField(
                      enabled: Settings.useRelay.value,
                      style: _relayIPStyle,
                      controller: _relayIPController,
                      decoration: Style.hintDecoration('e.g., 35.224.27.187'),
                      onChanged: (s) {
                        Settings.relayIP.setStored(s);
                        setState(() => _updateRelayStyle());
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Padding(
                    padding: Style.columnPadding,
                    child: Column(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(bottom: 50),
                          child: Text("Spdp Port:"),
                        ),
                        Text("Sedp Port:")
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: Style.columnPadding,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: _portStyle,
                              controller: _spdpPortController,
                              decoration: Style.hintDecoration("e.g., 4444"),
                              onChanged: (s) =>
                                  Settings.spdpPort.setStored(int.parse(s)),
                              inputFormatters: _portInputFormatter,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: _portStyle,
                              controller: _sedpPortController,
                              decoration: Style.hintDecoration("e.g., 4445"),
                              onChanged: (s) =>
                                  Settings.sedpPort.setStored(int.parse(s)),
                              inputFormatters: _portInputFormatter,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: Style.columnPadding,
                    child: Column(
                      children: const [
                        Text("Data Port:"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: Style.textPadding,
                      child: Column(
                        children: [
                          TextField(
                            keyboardType: TextInputType.number,
                            style: _portStyle,
                            controller: _dataPortController,
                            decoration: Style.hintDecoration("e.g., 4446"),
                            onChanged: (s) =>
                                Settings.dataPort.setStored(int.parse(s)),
                            inputFormatters: _portInputFormatter,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: Style.columnPadding,
                child: Text("Group/Topic Prefix/Domain Id", style: Style.titleText),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  controller: _groupController,
                  decoration: Style.hintDecoration('Group'),
                  onChanged: (s) => Settings.group.setStored(s),
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  controller: _topicPrefixController,
                  decoration: Style.hintDecoration('Topic Prefix'),
                  onChanged: (s) => Settings.topicPrefix.setStored(s),
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  readOnly: true,
                  keyboardType: TextInputType.number,
                  controller: _domainIdController,
                  decoration: Style.hintDecoration('Domain Id'),
                  onChanged: (s) => Settings.domainId.setStored(int.parse(s)),
                ),
              ),
              const Padding(
                padding: Style.columnPadding,
                child: Text(
                  "Theme",
                  style: Style.titleText,
                ),
              ),
              ListTile(
                title: const Text("System default"),
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                leading: Radio<ThemeMode>(
                  activeColor: Theme.of(context).colorScheme.primary,
                  value: ThemeMode.system,
                  groupValue: Settings.theme.value,
                  onChanged: _updateThemeMode,
                ),
              ),
              ListTile(
                title: const Text("Dark"),
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                leading: Radio<ThemeMode>(
                  activeColor: Theme.of(context).colorScheme.primary,
                  value: ThemeMode.dark,
                  groupValue: Settings.theme.value,
                  onChanged: _updateThemeMode,
                ),
                trailing: ElevatedButton(
                  onPressed: _showDarkPicker,
                  child: const Text("Set Dark Color"),
                ),
              ),
              ListTile(
                title: const Text("Light"),
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                leading: Radio<ThemeMode>(
                  activeColor: Theme.of(context).colorScheme.primary,
                  value: ThemeMode.light,
                  groupValue: Settings.theme.value,
                  onChanged: _updateThemeMode,
                ),
                trailing: ElevatedButton(
                  onPressed: _showLightPicker,
                  child: const Text("Set Light Color"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    if (_restartChanges) {
      // See if we need to restore port values.
      bool restored = false;
      if (_spdpPortController.text.isEmpty) {
        Settings.spdpPort.setStored(_originalPorts[0]);
        restored = true;
      }
      if (_sedpPortController.text.isEmpty) {
        Settings.sedpPort.setStored(_originalPorts[1]);
        restored = true;
      }
      if (_dataPortController.text.isEmpty) {
        Settings.dataPort.setStored(_originalPorts[2]);
        restored = true;
      }
      if (restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "One or more of the relay ports were restored to the original value.")),
        );
      }

      // Show the message indicating a restart.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Restarting the connection...")),
      );
      widget.restart();
    }
    return true;
  }

  @override
  void initState() {
    super.initState();

    // Save the original ports so that if the user leaves them empty, we can
    // restore back to the original values.
    _originalPorts.add(Settings.spdpPort.value);
    _originalPorts.add(Settings.sedpPort.value);
    _originalPorts.add(Settings.dataPort.value);

    // Set the change function to indicate that changes requiring a restart have
    // been made.  The change function is only called if the setting is changed
    // via the UI and persisted.
    for (var setting in [Settings.topicPrefix, Settings.relayIP, Settings.group]) {
      setting.change = (v) => _restartChanges = true;
    }
    Settings.useRelay.change = (v) => _restartChanges = true;
    for (var setting in [
      Settings.domainId,
      Settings.spdpPort,
      Settings.sedpPort,
      Settings.dataPort
    ]) {
      setting.change = (v) => _restartChanges = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: SafeArea(child: _renderContent()),
      ),
    );
  }
}
