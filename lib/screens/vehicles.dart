import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});
  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  List<Rec> list = [];
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Db.vehicles(q);
    if (mounted) setState(() => list = l);
  }

  Future<void> _edit([Rec? v]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleEditScreen(vehicle: v)));
    _load();
  }

  Future<void> _delete(Rec v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('${v['brand']} ${v['model']} ${v['variant']}\n\nSaved quotations will NOT be changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok == true) {
      await Db.deleteVehicle(v['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    String? last;
    final items = <Widget>[];
    for (final v in list) {
      final b = (v['brand'] as String?) ?? '';
      if (b != last) {
        last = b;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
          child: Text(b.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: kGold, letterSpacing: 1.5)),
        ));
      }
      items.add(Card(
        child: ListTile(
          title: Text('${v['model']} ${v['variant']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([v['year'], v['fuel'], v['trans']].where((e) => '${e ?? ''}'.isNotEmpty).join(' • ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(inr(numOf(v['price'])), style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(v)),
          ]),
          onTap: () => _edit(v),
        ),
      ));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('VEHICLE MASTER')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('ADD VEHICLE')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search brand / model / variant'),
            onChanged: (t) {
              q = t;
              _load();
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No vehicles yet.\nTap ADD VEHICLE to create your vehicle master.', textAlign: TextAlign.center))
              : ListView(padding: const EdgeInsets.fromLTRB(10, 0, 10, 90), children: items),
        ),
      ]),
    );
  }
}

class VehicleEditScreen extends StatefulWidget {
  final Rec? vehicle;
  const VehicleEditScreen({super.key, this.vehicle});
  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final _k = ['brand', 'model', 'year', 'variant', 'fuel', 'trans', 'ext_colors', 'int_colors', 'price'];
  late final Map<String, TextEditingController> c;
  static const brands = ['Toyota', 'Hyundai', 'Kia', 'Maruti Suzuki', 'Tata', 'Mahindra', 'Honda', 'MG', 'Skoda', 'Volkswagen', 'Renault', 'Nissan', 'Jeep', 'Citroen'];
  static const fuels = ['Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid'];
  static const trans = ['MT', 'AT', 'iMT', 'AMT', 'DCT', 'CVT'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    c = {
      for (final k in _k)
        k: TextEditingController(text: v == null ? '' : (k == 'price' ? numStr(numOf(v[k])) : '${v[k] ?? ''}'))
    };
  }

  Widget _chips(String key, List<String> opts) => Wrap(
        spacing: 6,
        children: [for (final o in opts) ActionChip(label: Text(o), onPressed: () => setState(() => c[key]!.text = o))],
      );

  Widget _tf(String key, String label, {bool num = false, String? hint, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: TextField(
          controller: c[key],
          maxLines: lines,
          keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : null,
          textCapitalization: TextCapitalization.words,
          inputFormatters: num ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          decoration: InputDecoration(labelText: label, hintText: hint, prefixText: num ? '₹ ' : null),
        ),
      );

  Future<void> _save() async {
    if (c['brand']!.text.trim().isEmpty || c['model']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brand and Model are required')));
      return;
    }
    final m = <String, dynamic>{
      if (widget.vehicle != null) 'id': widget.vehicle!['id'],
      for (final k in _k) k: k == 'price' ? numOf(c[k]!.text) : c[k]!.text.trim(),
    };
    await Db.saveVehicle(m);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vehicle == null ? 'ADD VEHICLE' : 'EDIT VEHICLE')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('SAVE VEHICLE'))),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _tf('brand', 'Brand *'),
        _chips('brand', brands),
        _tf('model', 'Model *'),
        _tf('year', 'Model Year', num: false),
        _tf('variant', 'Variant'),
        _tf('fuel', 'Fuel Type'),
        _chips('fuel', fuels),
        _tf('trans', 'Transmission'),
        _chips('trans', trans),
        _tf('ext_colors', 'Exterior Colours (comma separated)', hint: 'Attitude Black, Super White', lines: 2),
        _tf('int_colors', 'Interior Colours (comma separated)', hint: 'Black, Beige', lines: 2),
        _tf('price', 'Ex-showroom Price', num: true),
        const SizedBox(height: 6),
        const Text('Changing the price here never changes quotations that were already saved.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}

/// Bottom-sheet picker used by the quotation form.
Future<Rec?> showVehiclePicker(BuildContext context) {
  return showModalBottomSheet<Rec>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _PickerSheet(),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet();
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  List<Rec> list = [];
  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String q) async {
    final l = await Db.vehicles(q);
    if (mounted) setState(() => list = l);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        const SizedBox(height: 10),
        const Text('SELECT VEHICLE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
            onChanged: _load,
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No vehicles in Vehicle Master.\nAdd vehicles first (or type details manually).', textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final v = list[i];
                    return ListTile(
                      title: Text('${v['brand']} ${v['model']} ${v['variant']}'),
                      subtitle: Text([v['year'], v['fuel'], v['trans']].where((e) => '${e ?? ''}'.isNotEmpty).join(' • ')),
                      trailing: Text(inr(numOf(v['price'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () => Navigator.pop(context, v),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
