import 'package:flutter/material.dart';
import 'db.dart';
import 'screens/home.dart';
import 'screens/lock.dart';

const kGold = Color(0xFFC9A227);
const kBlack = Color(0xFF111111);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShreejiApp());
}

class ShreejiApp extends StatelessWidget {
  const ShreejiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kGold, brightness: Brightness.light)
        .copyWith(primary: kBlack, onPrimary: Colors.white, secondary: kGold, onSecondary: Colors.black);
    return MaterialApp(
      title: 'Shreeji Autolink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF6F4EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBlack,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: kGold),
          actionsIconTheme: IconThemeData(color: kGold),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withOpacity(.08))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 2)),
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(backgroundColor: kBlack, foregroundColor: kGold),
      ),
      home: const Gate(),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? _locked;

  @override
  void initState() {
    super.initState();
    Db.get('lock_enabled', '0').then((v) {
      if (mounted) setState(() => _locked = v == '1');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_locked == null) {
      return const Scaffold(backgroundColor: kBlack, body: Center(child: CircularProgressIndicator(color: kGold)));
    }
    if (_locked!) return LockScreen(onUnlocked: () => setState(() => _locked = false));
    return const HomeScreen();
  }
}
