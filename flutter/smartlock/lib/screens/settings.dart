import 'package:flutter/material.dart';
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

class EncryptedStringSetting extends SimpleSetting<String> {
  EncryptedStringSetting(super.key, super.value);

  @override
  Future<dynamic> getPrefs() async => EncryptedSharedPreferences();

  @override
  Future<String?> read(dynamic prefs) async {
    // Because the EncryptedSharedPreferences object return an empty string
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

  final Function() restart;
  const Settings({super.key, required this.restart});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Color? _selected;
  final _usernameController =
      TextEditingController(text: Settings.username.value);
  final _passwordController =
      TextEditingController(text: Settings.password.value);

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
                child: Text(
                  "Credentials",
                  style: Style.titleText,
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: 'Username'),
                  onChanged: (s) => Settings.username.setStored(s),
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: 'Password'),
                  onChanged: (s) => Settings.password.setStored(s),
                  obscureText: true,
                ),
              ),
              Padding(
                padding: Style.textPadding,
                child: ElevatedButton(
                  onPressed: widget.restart,
                  child: const Text("Restart Bridge"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(child: _renderContent()),
    );
  }
}
