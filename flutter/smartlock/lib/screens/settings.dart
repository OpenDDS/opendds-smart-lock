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
  }

  final Function() download;
  const Settings({super.key, required this.download});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Color? _selected;
  bool _restartChanges = false;
  final _usernameController =
      TextEditingController(text: Settings.username.value);
  final _passwordController =
      TextEditingController(text: Settings.password.value);
  final _apiURLController = TextEditingController(text: Settings.apiURL.value);
  final _topicPrefixController =
      TextEditingController(text: Settings.topicPrefix.value);
  final _domainIdController =
      TextEditingController(text: Settings.domainId.value.toString());
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

  Widget _renderContent() {
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
                child: TextField(
                  controller: _passwordController,
                  decoration: Style.hintDecoration('Password'),
                  onChanged: (s) => Settings.password.setStored(s),
                  obscureText: true,
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: ElevatedButton(
                  onPressed: () async {
                    if (await widget.download()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Please restart the app to use the new certificates.")),
                      );
                    }
                  },
                  child: const Text("Download"),
                ),
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
                  keyboardType: TextInputType.number,
                  controller: _domainIdController,
                  decoration: Style.hintDecoration('Domain Id'),
                  onChanged: (s) => Settings.domainId.setStored(int.parse(s)),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'\d'))
                  ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Changes will take effect after the app is restarted.")),
      );
    }
    return true;
  }

  @override
  void initState() {
    super.initState();

    // Set the change function to indicate that changes will take affect on
    // restart.  The change function is only called if the setting changes.
    for (var setting in [
      Settings.username,
      Settings.password,
      Settings.apiURL,
      Settings.topicPrefix,
      Settings.group,
    ]) {
      setting.change = (v) => _restartChanges = true;
    }
    Settings.domainId.change = (v) => _restartChanges = true;
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
