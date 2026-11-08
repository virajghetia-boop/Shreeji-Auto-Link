import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';

/// Configurable tax rules + default charges used for every NEW quotation.
class PriceMasterScreen extends StatefulWidget {
  const PriceMasterScreen({super.key});
  @override
  State<PriceMasterScreen> createState() => _PriceMasterScreenState();
}

class _PriceMasterScreenState extends State<PriceMasterScreen> {
  // default charge keys (Ex-showroom comes from Vehicle Master, TCS from the rule)
  final _defKeys = [for (final f in kPriceFields) if (f[0] != 'ex' && f[0] != 'tcs') f];
  final Map<String, TextEditingController> _d = {};
  final _rate = TextEditingController();
  final _limit = TextEditingController();
  final _fastag = TextEditingController();
  String _mode = 'full';
  String _tpl = 'A';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    for (final f in _defKeys) {
      _d[f[0]] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    final s = await Db.settings();
    for (final f in _defKeys) {
      _d[f[0]]!.text = numStr(numOf(s['def_${f[0]}']));
    }
    _rate.text = s['tcs_rate'] ?? '1';
    _limit.text = numStr(numOf(s['tcs_threshold']));
    _fastag.text = s['fastag'] ?? '600';
    _mode = s['tcs_mode'] ?? 'full';
    _tpl = s['default_template'] ?? 'A';
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await Db.saveSettings({
      'tcs_rate': _rate.text.trim().isEmpty ? '0' : _rate.text.trim(),
      'tcs_threshold': _limit.text.trim().isEmpty ? '0' : _limit.text.trim(),
      'tcs_mode': _mode,
      'fastag': _fastag.text.trim(),
      'default_template': _tpl,
      for (final f in _defKeys) 'def_${f[0]}': _d[f[0]]!.text.trim().isEmpty ? '0' : _d[f[0]]!.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price Master saved. Applies to new quotations.')));
      Navigator.pop(context);
    }
  }

  Widget _num(TextEditingController c, String label, {String? prefix, String? suffix}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: label, prefixText: prefix, suffixText: suffix),
        ),
      );

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: kGold, letterSpacing: 1.2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PRICE MASTER')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('SAVE'))),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              _head('TCS RULE'),
              _num(_rate, 'TCS rate', suffix: '%'),
              _num(_limit, 'TCS applies when Ex-showroom is above', prefix: '₹ '),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'full', label: Text('On full price')),
                  ButtonSegment(value: 'excess', label: Text('On amount above limit')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 6),
              const Text('Example (your Excel): 1% on full Ex-showroom if above ₹10,00,000. '
                  'TCS stays editable in every quotation.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              _head('FASTAG'),
              _num(_fastag, 'FASTag charge (used in terms)', prefix: '₹ '),
              _head('DEFAULT CHARGES FOR NEW QUOTATIONS'),
              for (final f in _defKeys) _num(_d[f[0]]!, f[1], prefix: '₹ '),
              const Text('Leave blank / 0 if you want to type the amount every time. '
                  'Ex-showroom price comes from Vehicle Master.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              _head('DEFAULT PDF DESIGN'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'A', label: Text('A: Excel')),
                  ButtonSegment(value: 'B', label: Text('B: Modern')),
                ],
                selected: {_tpl},
                onSelectionChanged: (s) => setState(() => _tpl = s.first),
              ),
              const SizedBox(height: 20),
            ]),
    );
  }
}
