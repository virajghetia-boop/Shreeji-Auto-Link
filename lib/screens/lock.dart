import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';

Future<bool> biometricAvailable() async {
  try {
    final a = LocalAuthentication();
    return await a.isDeviceSupported() && (await a.getAvailableBiometrics()).isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool> biometricAuth(String reason) async {
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}

/// Asks for a 4–6 digit PIN. Returns null if cancelled.
Future<String?> askPin(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(labelText: 'PIN (4–6 digits)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            if (c.text.length >= 4) Navigator.pop(ctx, c.text);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  String? _err;
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final b = await Db.get('bio_enabled', '0') == '1' && await biometricAvailable();
    if (!mounted) return;
    setState(() => _bio = b);
    if (b) _tryBio();
  }

  Future<void> _tryBio() async {
    if (await biometricAuth('Unlock Shreeji Autolink')) widget.onUnlocked();
  }

  Future<void> _check() async {
    final saved = await Db.get('pin_hash');
    if (hashPin(_pin.text) == saved) {
      widget.onUnlocked();
    } else {
      setState(() => _err = 'Wrong PIN');
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/logo.png', height: 130),
              const SizedBox(height: 16),
              const Text('SHREEJI AUTOLINK',
                  style: TextStyle(color: kGold, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 28),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                onSubmitted: (_) => _check(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Enter PIN',
                  hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                  errorText: _err,
                  filled: true,
                  fillColor: Colors.white10,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black),
                  onPressed: _check,
                  child: const Text('UNLOCK'),
                ),
              ),
              if (_bio)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: IconButton(
                    iconSize: 44,
                    color: kGold,
                    onPressed: _tryBio,
                    icon: const Icon(Icons.fingerprint),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
