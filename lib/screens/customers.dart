import 'package:flutter/material.dart';
import '../db.dart';
import '../util.dart';
import 'quote_list.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Rec> list = [];
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Db.customers(q);
    if (mounted) setState(() => list = l);
  }

  Future<void> _open([Rec? c]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: c)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CUSTOMER LIST')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(), icon: const Icon(Icons.person_add), label: const Text('ADD CUSTOMER')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name / mobile'),
            onChanged: (t) {
              q = t;
              _load();
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No customers yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: Colors.black,
                            child: Text(((c['name'] as String?) ?? '?').isEmpty ? '?' : (c['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFFC9A227)))),
                        title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${c['mobile'] ?? ''}  ${(c['kyc'] ?? '') == '' ? '' : '• KYC: ${c['kyc']}'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(c),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class CustomerFormScreen extends StatefulWidget {
  final Rec? customer;
  const CustomerFormScreen({super.key, this.customer});
  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _k = ['name', 'mobile', 'address', 'pan', 'kyc', 'brand', 'model', 'notes'];
  late final Map<String, TextEditingController> c;
  List<Rec> quotes = [];

  @override
  void initState() {
    super.initState();
    final v = widget.customer;
    c = {for (final k in _k) k: TextEditingController(text: v == null ? '' : '${v[k] ?? ''}')};
    if (v != null && '${v['mobile'] ?? ''}'.isNotEmpty) {
      Db.quotationsForMobile('${v['mobile']}').then((l) {
        if (mounted) setState(() => quotes = l);
      });
    }
  }

  Widget _tf(String k, String label, {TextInputType? kt, int lines = 1, TextCapitalization cap = TextCapitalization.words}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c[k], keyboardType: kt, maxLines: lines, textCapitalization: cap, decoration: InputDecoration(labelText: label)),
      );

  Future<void> _save() async {
    if (c['name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer name is required')));
      return;
    }
    final m = <String, dynamic>{
      if (widget.customer != null) 'id': widget.customer!['id'],
      for (final k in _k) k: c[k]!.text.trim(),
    };
    await Db.saveCustomer(m);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: const Text('Customer record will be removed. Saved quotations are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok == true) {
      await Db.deleteCustomer(widget.customer!['id'] as int);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'ADD CUSTOMER' : 'CUSTOMER'),
        actions: [if (widget.customer != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('SAVE CUSTOMER'))),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _tf('name', 'Customer Name *'),
        _tf('mobile', 'Mobile Number', kt: TextInputType.phone),
        _tf('address', 'Address', lines: 2),
        _tf('pan', 'PAN Number (optional)', cap: TextCapitalization.characters),
        _tf('kyc', 'KYC Status (e.g. Done / Pending)'),
        _tf('brand', 'Interested Brand'),
        _tf('model', 'Interested Model'),
        _tf('notes', 'Notes', lines: 3, cap: TextCapitalization.sentences),
        if (widget.customer != null) ...[
          const SizedBox(height: 8),
          Text('PREVIOUS QUOTATIONS (${quotes.length})', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (quotes.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No quotations for this customer yet.')),
          for (final q in quotes)
            Card(
              child: ListTile(
                title: Text('${q['number']}  •  ${dmy(q['qdate'] as String?)}'),
                subtitle: Text('${q['brand']} ${q['model']} ${q['variant']}'),
                trailing: Text(inr(numOf(q['total'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => QuoteDetailScreen(id: q['id'] as int))),
              ),
            ),
        ],
      ]),
    );
  }
}
