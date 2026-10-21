import 'package:flutter/material.dart';

import 'auto_screen.dart';
import 'manual_screen.dart';
import 'settings.dart';
import 'settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlyerApp());
}

class FlyerApp extends StatelessWidget {
  const FlyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE91E8C); // magenta de club
    return MaterialApp(
      title: 'Flyer GPTetal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Settings? _settings;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Settings.load().then((s) {
      setState(() => _settings = s);
      if (!s.isConfigured) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openSettings());
      }
    });
  }

  Future<void> _openSettings() async {
    final s = _settings;
    if (s == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(settings: s)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Flyer GPTetal'),
            Text(s.providerLabel,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: _openSettings,
            icon: Icon(s.isConfigured ? Icons.settings : Icons.warning_amber,
                color: s.isConfigured ? null : Colors.amber),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          AutoScreen(settings: s),
          ManualScreen(settings: s),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Automático'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Manual'),
        ],
      ),
    );
  }
}
