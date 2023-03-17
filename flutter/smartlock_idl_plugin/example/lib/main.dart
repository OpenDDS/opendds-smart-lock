import 'package:flutter/material.dart';

import 'package:smartlock_idl_plugin/smartlock_idl_plugin.dart'
    as smartlock_idl;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> _text = [];
  ScrollController _scrollController = ScrollController();
  smartlock_idl.Bridge? _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = smartlock_idl.Bridge();
    _bridge?.start();
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
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
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
                    setState(
                        () => _text.add("${_text.length} The UI is reactive."));
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
