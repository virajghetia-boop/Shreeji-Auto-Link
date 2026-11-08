import 'dart:convert';
import 'package:flutter/material.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';
import 'lock.dart';
import 'terms_editor.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _t(BuildContext c, IconData i, String t, String s, Widget page) => Card(
        child: ListTile(
          leading: Icon(i, color: kBlack),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMPANY SETTINGS')),
      body: ListView(padding: const EdgeInsets.all(10), children: [
        _t(context, Icons.business, 'Company & Bank Details', 'Name, address, bank, contact person, e-mail', const CompanyInfoScreen()),
        _t(context, Icons.gavel, 'Terms & Conditions', 'Add, edit, delete and reorder default terms', const TermsScreen()),
        _t(context, Icons.lock, 'App Lock', 'PIN and fingerprint / face unlock', const SecurityScreen()),
        _t(context, Icons.info, 'About', 'Shreeji Autolink Quotation Maker', const AboutScreen()),
      ]),
    );
  }
}

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});
  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  static const fields = [
    ['company_name', 'Business Name'],
    ['tagline', 'Business Activities (tagline)'],
    ['address', 'Address'],
    ['acc_name', 'Bank Account Name'],
    ['acc_no', 'Account Number'],
    ['ifsc', 'IFSC Code'],
    ['contact_person', 'Contact Person'],
    ['contact_no', 'Contact Number'],
    ['email', 'E-mail'],
  ];
  final Map<String, TextEditingController> c = {for (final f in fields) f[0]: TextEditingController()};

  @override
  void initState() {
    super.initState();
    Db.settings().then((s) {
      if (!mounted) return;
      setState(() {
        for (final f in fields) {
          c[f[0]]!.text = s[f[0]] ?? '';
        }
      });
    });
  }

  Future<void> _save() async {
    await Db.saveSettings({for (final f in fields) f[0]: c[f[0]]!.text.trim()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. New quotations will use these details.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMPANY & BANK')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('SAVE'))),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(controller: c[f[0]], maxLines: f[0] == 'address' ? 2 : 1, decoration: InputDecoration(labelText: f[1])),
          ),
        const Text('The logo is fixed to your original Shreeji Autolink logo.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  List<Map<String, dynamic>> terms = [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Db.settings();
    if (mounted) setState(() {
      terms = loadTerms(s, resolve: false);
      loaded = true;
    });
  }

  Future<void> _persist() => Db.set('terms', jsonEncode(terms));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TERMS & CONDITIONS'), actions: [
        TextButton(
          onPressed: () async {
            await Db.set('terms', '');
            await _load();
          },
          child: const Text('RESET', style: TextStyle(color: kGold)),
        ),
      ]),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(10), children: [
              const Text(
                'Placeholders: {FASTAG} = FASTag charge, {TCS_RATE} = TCS %, {TCS_LIMIT} = TCS limit. '
                'They are filled from Price Master when a new quotation is created. '
                'Changes affect new quotations only.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              TermsEditor(terms: terms, onChanged: _persist),
            ]),
    );
  }
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool lock = false, bio = false, bioAvail = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Db.get('lock_enabled', '0') == '1';
    final b = await Db.get('bio_enabled', '0') == '1';
    final av = await biometricAvailable();
    if (mounted) setState(() {
      lock = l;
      bio = b;
      bioAvail = av;
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<bool> _verify() async {
    final p = await askPin(context, 'Enter current PIN');
    if (p == null) return false;
    if (hashPin(p) == await Db.get('pin_hash')) return true;
    _snack('Wrong PIN');
    return false;
  }

  Future<bool> _setNewPin() async {
    final p1 = await askPin(context, 'Set new PIN');
    if (p1 == null || !mounted) return false;
    final p2 = await askPin(context, 'Confirm PIN');
    if (p2 == null) return false;
    if (p1 != p2) {
      _snack('PINs do not match');
      return false;
    }
    await Db.set('pin_hash', hashPin(p1));
    return true;
  }

  Future<void> _toggleLock(bool v) async {
    if (v) {
      if (await _setNewPin()) {
        await Db.set('lock_enabled', '1');
      }
    } else {
      if (await _verify()) {
        await Db.set('lock_enabled', '0');
        await Db.set('bio_enabled', '0');
      }
    }
    _load();
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      if (await biometricAuth('Confirm to enable biometric unlock')) await Db.set('bio_enabled', '1');
    } else {
      await Db.set('bio_enabled', '0');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APP LOCK')),
      body: ListView(padding: const EdgeInsets.all(10), children: [
        Card(
          child: SwitchListTile(
            title: const Text('Enable PIN lock'),
            subtitle: const Text('Ask for PIN every time the app is opened'),
            value: lock,
            onChanged: _toggleLock,
          ),
        ),
        if (lock)
          Card(
            child: ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Change PIN'),
              onTap: () async {
                if (await _verify()) {
                  if (await _setNewPin()) _snack('PIN changed');
                }
              },
            ),
          ),
        if (lock)
          Card(
            child: SwitchListTile(
              title: const Text('Fingerprint / Face unlock'),
              subtitle: Text(bioAvail ? 'Use phone biometrics instead of typing PIN' : 'Not available on this phone'),
              value: bio,
              onChanged: bioAvail ? _toggleBio : null,
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('All data is stored in the app\'s private storage and is never uploaded anywhere. '
              'If you forget the PIN, restore is not possible without clearing app data, so keep a backup.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(color: Colors.black, padding: const EdgeInsets.all(12), child: Image.asset('assets/logo.png', height: 140)),
            const SizedBox(height: 18),
            const Text('SHREEJI AUTOLINK', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Text('QUOTATION MAKER', style: TextStyle(color: kGold, letterSpacing: 3, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text('Sales | Used Car | Insurance | Finance'),
            const SizedBox(height: 10),
            const Text('612, R.K. Empire, Near Mavdi Circle,\n150 FT Ring Road, Rajkot 360004', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            const Text('Version 1.0.0  •  100% offline', style: TextStyle(color: Colors.black54)),
          ]),
        ),
      ),
    );
  }
}
