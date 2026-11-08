import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';
import 'customers.dart';
import 'pdf_view.dart';
import 'terms_editor.dart';
import 'vehicles.dart';

class _Custom {
  final TextEditingController label;
  final TextEditingController amount;
  bool minus;
  _Custom(String l, String a, this.minus)
      : label = TextEditingController(text: l),
        amount = TextEditingController(text: a);
}

class QuoteFormScreen extends StatefulWidget {
  final int? editId; // editing an existing quotation (creates a revision)
  final Map<String, dynamic>? initial; // data to prefill (edit / duplicate)
  final bool duplicate;
  const QuoteFormScreen({super.key, this.editId, this.initial, this.duplicate = false});
  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  static const _ck = ['name', 'address', 'mobile', 'pan', 'kyc', 'proNo', 'brand', 'model', 'year', 'variant', 'fuel', 'trans', 'extColor', 'intColor', 'notes'];
  final Map<String, TextEditingController> _c = {for (final k in _ck) k: TextEditingController()};
  final Map<String, TextEditingController> _p = {for (final f in kPriceFields) f[0]: TextEditingController()};
  final List<_Custom> _customs = [];
  List<Map<String, dynamic>> _terms = [];
  Map<String, String> _st = {};
  DateTime _date = DateTime.now();
  String _template = 'A';
  bool _tcsAuto = true;
  int? _vehicleId;
  bool _loading = true;
  List<String> _extChoices = [];
  List<String> _intChoices = [];
  Rec? _found;
  int _foundCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _st = await Db.settings();
    _template = _st['default_template'] ?? 'A';
    final d = widget.initial;
    if (d == null) {
      for (final f in kPriceFields) {
        final dv = numOf(_st['def_${f[0]}']);
        if (dv != 0 && f[0] != 'ex' && f[0] != 'tcs') _p[f[0]]!.text = numStr(dv);
      }
      _terms = loadTerms(_st);
    } else {
      final cu = Map<String, dynamic>.from(d['customer'] ?? {});
      final v = Map<String, dynamic>.from(d['vehicle'] ?? {});
      cu.forEach((k, val) {
        if (_c.containsKey(k)) _c[k]!.text = '${val ?? ''}';
      });
      v.forEach((k, val) {
        if (_c.containsKey(k)) _c[k]!.text = '${val ?? ''}';
      });
      _c['proNo']!.text = widget.duplicate ? '' : '${d['proNo'] ?? ''}';
      _c['notes']!.text = '${d['notes'] ?? ''}';
      _vehicleId = v['vehicleId'] as int?;
      final pr = Map<String, dynamic>.from(d['prices'] ?? {});
      for (final f in kPriceFields) {
        _p[f[0]]!.text = numStr(numOf(pr[f[0]]));
      }
      for (final cu2 in (d['custom'] as List? ?? [])) {
        _customs.add(_Custom('${cu2['label'] ?? ''}', numStr(numOf(cu2['amount'])), cu2['minus'] == true));
      }
      _terms = (d['terms'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _tcsAuto = d['tcsAuto'] != false;
      _template = '${d['template'] ?? _template}';
      if (!widget.duplicate) {
        _date = DateTime.tryParse('${d['date']}') ?? DateTime.now();
      }
      if (widget.duplicate) {
        // load CURRENT vehicle master price; fresh terms/date
        if (_vehicleId != null) {
          final vm = await Db.vehicle(_vehicleId!);
          if (vm != null) {
            _p['ex']!.text = numStr(numOf(vm['price']));
            _extChoices = splitList(vm['ext_colors'] as String?);
            _intChoices = splitList(vm['int_colors'] as String?);
          }
        }
        _tcsAuto = true;
        _terms = loadTerms(_st);
        _recalcTcs();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _recalcTcs() {
    if (_tcsAuto) _p['tcs']!.text = numStr(calcTcs(numOf(_p['ex']!.text), _st));
  }

  double get _total {
    final d = _collect();
    return calcTotal(d);
  }

  Map<String, dynamic> _collect() {
    String t(String k) => _c[k]!.text.trim();
    final rate = trimNum(double.tryParse(_st['tcs_rate'] ?? '1') ?? 1);
    final oldCo = widget.editId != null ? widget.initial?['company'] : null;
    return {
      'customer': {'name': t('name'), 'address': t('address'), 'mobile': t('mobile'), 'pan': t('pan').toUpperCase(), 'kyc': t('kyc')},
      'vehicle': {
        'brand': t('brand'), 'model': t('model'), 'year': t('year'), 'variant': t('variant'),
        'fuel': t('fuel'), 'trans': t('trans'), 'extColor': t('extColor'), 'intColor': t('intColor'),
        'vehicleId': _vehicleId,
      },
      'prices': {for (final f in kPriceFields) f[0]: numOf(_p[f[0]]!.text)},
      'custom': [
        for (final c in _customs)
          if (c.label.text.trim().isNotEmpty || numOf(c.amount.text) != 0)
            {'label': c.label.text.trim(), 'amount': numOf(c.amount.text), 'minus': c.minus}
      ],
      'tcsAuto': _tcsAuto,
      'tcsLabel': widget.editId != null && widget.initial?['tcsLabel'] != null
          ? widget.initial!['tcsLabel']
          : (_tcsAuto && rate != '0' ? 'TCS $rate%' : 'TCS'),
      'date': iso(_date),
      'proNo': t('proNo'),
      'notes': t('notes'),
      'terms': _terms,
      'template': _template,
      'status': widget.editId != null ? (widget.initial?['status'] ?? 'Quoted') : 'Quoted',
      'company': oldCo ??
          {
            'name': _st['company_name'], 'tagline': _st['tagline'], 'address': _st['address'],
            'accName': _st['acc_name'], 'accNo': _st['acc_no'], 'ifsc': _st['ifsc'],
            'contactPerson': _st['contact_person'], 'contactNo': _st['contact_no'], 'email': _st['email'],
          },
    };
  }

  Future<void> _onMobile(String v) async {
    final m = v.trim();
    if (m.length >= 10) {
      final c = await Db.customerByMobile(m);
      final n = c == null ? 0 : (await Db.quotationsForMobile(m)).length;
      if (mounted) setState(() {
        _found = c;
        _foundCount = n;
      });
    } else if (_found != null) {
      setState(() => _found = null);
    }
  }

  void _useCustomer() {
    final c = _found!;
    setState(() {
      _c['name']!.text = '${c['name'] ?? ''}';
      _c['address']!.text = '${c['address'] ?? ''}';
      _c['pan']!.text = '${c['pan'] ?? ''}';
      _c['kyc']!.text = '${c['kyc'] ?? ''}';
      if (_c['brand']!.text.isEmpty) _c['brand']!.text = '${c['brand'] ?? ''}';
      if (_c['model']!.text.isEmpty) _c['model']!.text = '${c['model'] ?? ''}';
    });
  }

  Future<void> _pickVehicle() async {
    final v = await showVehiclePicker(context);
    if (v == null) return;
    setState(() {
      _vehicleId = v['id'] as int;
      _c['brand']!.text = '${v['brand'] ?? ''}';
      _c['model']!.text = '${v['model'] ?? ''}';
      _c['year']!.text = '${v['year'] ?? ''}';
      _c['variant']!.text = '${v['variant'] ?? ''}';
      _c['fuel']!.text = '${v['fuel'] ?? ''}';
      _c['trans']!.text = '${v['trans'] ?? ''}';
      _extChoices = splitList(v['ext_colors'] as String?);
      _intChoices = splitList(v['int_colors'] as String?);
      _c['extColor']!.text = _extChoices.length == 1 ? _extChoices.first : '';
      _c['intColor']!.text = _intChoices.length == 1 ? _intChoices.first : '';
      _p['ex']!.text = numStr(numOf(v['price']));
      _recalcTcs();
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_c['name']!.text.trim().isEmpty) {
      _snack('Customer name is required');
      return;
    }
    if (numOf(_p['ex']!.text) <= 0) {
      _snack('Enter the Ex-showroom price');
      return;
    }
    final data = _collect();
    final id = await Db.saveQuotation(data, id: widget.editId);
    final row = await Db.quotation(id);
    if (!mounted || row == null) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PdfScreen.fromRow(row)));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---------------- UI helpers ----------------
  Widget _tf(String k, String label,
      {TextInputType? kt, int lines = 1, TextCapitalization cap = TextCapitalization.words, void Function(String)? onCh}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _c[k],
        keyboardType: kt,
        maxLines: lines,
        textCapitalization: cap,
        onChanged: onCh,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: kGold)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _chips(List<String> opts, String key) => opts.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 6, children: [
            for (final o in opts) ChoiceChip(label: Text(o), selected: _c[key]!.text == o, onSelected: (_) => setState(() => _c[key]!.text = o)),
          ]),
        );

  Widget _priceField(String key, String label) {
    final isTcs = key == 'tcs';
    final isEx = key == 'ex';
    final lbl = isTcs ? 'TCS ${_tcsAuto ? '(auto)' : '(manual)'}' : (key == 'discIns' ? '$label  (−)' : label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _p[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: TextStyle(fontWeight: isEx ? FontWeight.bold : FontWeight.normal),
            decoration: InputDecoration(
              labelText: lbl,
              prefixText: '₹ ',
              fillColor: isEx ? const Color(0xFFFFFF99) : Colors.white,
            ),
            onChanged: (_) => setState(() {
              if (isEx) _recalcTcs();
              if (isTcs) _tcsAuto = false;
            }),
          ),
        ),
        if (isTcs)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Column(children: [
              const Text('Auto', style: TextStyle(fontSize: 10)),
              Switch(
                value: _tcsAuto,
                onChanged: (v) => setState(() {
                  _tcsAuto = v;
                  _recalcTcs();
                }),
              ),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing
            ? 'EDIT QUOTATION'
            : widget.duplicate
                ? 'DUPLICATE QUOTATION'
                : 'NEW QUOTATION'),
      ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Container(
                color: kBlack,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      const Text('GRAND TOTAL', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                      Text(inr(_total), style: const TextStyle(color: kGold, fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black),
                    onPressed: _save,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(editing ? 'SAVE REVISION & PDF' : 'SAVE & GENERATE PDF'),
                  ),
                ]),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(10), children: [
              _section('PDF DESIGN', [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'A', label: Text('A: Original Excel'), icon: Icon(Icons.table_chart)),
                    ButtonSegment(value: 'B', label: Text('B: Modern Premium'), icon: Icon(Icons.auto_awesome)),
                  ],
                  selected: {_template},
                  onSelectionChanged: (s) => setState(() => _template = s.first),
                ),
              ]),
              _section('CUSTOMER DETAILS', [
                _tf('mobile', 'Mobile Number', kt: TextInputType.phone, onCh: _onMobile),
                if (_found != null)
                  Card(
                    color: const Color(0xFFEFF7EE),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Existing customer: ${_found!['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_found!['address'] ?? ''}'),
                        Text('Previous quotations: $_foundCount'),
                        Row(children: [
                          TextButton(onPressed: _useCustomer, child: const Text('USE DETAILS')),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: _found))),
                            child: const Text('VIEW PREVIOUS QUOTES'),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                _tf('name', 'Customer Name *'),
                _tf('address', 'Address', lines: 2),
                _tf('pan', 'PAN Number (optional)', cap: TextCapitalization.characters),
                _tf('kyc', 'KYC (e.g. Done / Pending)'),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text('Date: ${dmy(iso(_date))}'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _tf('proNo', 'Proforma Invoice No. (blank = quotation number)', cap: TextCapitalization.characters),
              ]),
              _section('VEHICLE DETAILS', [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _pickVehicle,
                    icon: const Icon(Icons.directions_car),
                    label: const Text('SELECT FROM VEHICLE MASTER'),
                  ),
                ),
                const SizedBox(height: 10),
                _tf('brand', 'Brand'),
                _tf('model', 'Model'),
                _tf('year', 'Year', kt: TextInputType.number),
                _tf('variant', 'Variant'),
                _tf('fuel', 'Fuel Type'),
                _tf('trans', 'Transmission'),
                _tf('extColor', 'Exterior Colour'),
                _chips(_extChoices, 'extColor'),
                _tf('intColor', 'Interior Colour'),
                _chips(_intChoices, 'intColor'),
              ]),
              _section('PRICE BREAKDOWN', [
                for (final f in kPriceFields) _priceField(f[0], f[1]),
                const Divider(),
                const Text('Additional custom charges / discounts', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (var i = 0; i < _customs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(flex: 5, child: TextField(controller: _customs[i].label, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Description'))),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _customs[i].amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add / Subtract',
                        onPressed: () => setState(() => _customs[i].minus = !_customs[i].minus),
                        icon: Icon(_customs[i].minus ? Icons.remove_circle : Icons.add_circle,
                            color: _customs[i].minus ? Colors.red : Colors.green),
                      ),
                      IconButton(onPressed: () => setState(() => _customs.removeAt(i)), icon: const Icon(Icons.close)),
                    ]),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => _customs.add(_Custom('', '', false))),
                  icon: const Icon(Icons.add),
                  label: const Text('ADD CUSTOM CHARGE'),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFFFFF00),
                  child: Row(children: [
                    const Expanded(child: Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                    Text(inr(_total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                ),
              ]),
              _section('NOTES (internal)', [_tf('notes', 'Notes', lines: 2, cap: TextCapitalization.sentences)]),
              Card(
                child: ExpansionTile(
                  title: const Text('TERMS & CONDITIONS (this quotation)', style: TextStyle(fontWeight: FontWeight.bold, color: kGold, letterSpacing: 1.2, fontSize: 14)),
                  childrenPadding: const EdgeInsets.all(10),
                  children: [TermsEditor(terms: _terms, onChanged: () {})],
                ),
              ),
              const SizedBox(height: 20),
            ]),
    );
  }
}
