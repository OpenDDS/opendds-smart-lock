import 'package:flutter/material.dart';

import 'screens/home.dart';
import 'screens/settings.dart';

void main() async {
  // This must be called before attempting to load shared preferences.
  WidgetsFlutterBinding.ensureInitialized();

  await Settings.theme.getStored();
  await Settings.lightSeed.getStored();
  await Settings.darkSeed.getStored();
  await Settings.username.getStored();
  await Settings.password.getStored();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Settings.theme.change = (mode) => setState((){});
      Settings.lightSeed.change = (color) => setState((){});
      Settings.darkSeed.change = (color) => setState((){});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: Settings.theme.value,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Settings.darkSeed.value,
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Settings.lightSeed.value,
      ),
      home: const Home(),
    );
  }
}
