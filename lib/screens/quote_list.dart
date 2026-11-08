import 'dart:convert';
import 'package:flutter/material.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';
import 'pdf_view.dart';
import 'quote_form.dart';

Future<bool> confirmDelete(BuildContext context, String number) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete quotation?'),
      content: Text('$number and all its revisions will be permanently deleted.\nThe number will not be reused.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE')),
      ],
    ),
  );
  return ok == true;
}

// =====================================================================
// ALL QUOTATIONS
// =====================================================================
class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});
  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  List<Rec> list = [];
  String q = '';
  String quick = 'all';
  DateTime? from, to;
  final minC = TextEditingController();
  final maxC = TextEditingController();

  static const quickLabels = {
    'all': 'All Quotations',
    'today': 'Today',
    'week': 'This Week',
    'month': 'This Month',
    'last': 'Last Month',
    'year': 'This Year',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _applyQuick(String k) {
    final n = DateTime.now();
    final t = DateTime(n.year, n.month, n.day);
    quick = k;
    switch (k) {
      case 'today':
        from = t;
        to = t;
        break;
      case 'week':
        from = t.subtract(Duration(days: t.weekday - 1));
        to = t;
        break;
      case 'month':
        from = DateTime(n.year, n.month, 1);
        to = t;
        break;
      case 'last':
        from = DateTime(n.year, n.month - 1, 1);
        to = DateTime(n.year, n.month, 0);
        break;
      case 'year':
        from = DateTime(n.year, 1, 1);
        to = t;
        break;
      default:
        from = null;
        to = null;
    }
    _load();
  }

  Future<void> _load() async {
    final l = await Db.searchQuotations(
      q: q,
      from: from == null ? null : iso(from!),
      to: to == null ? null : iso(to!),
      minAmt: minC.text.trim().isEmpty ? null : numOf(minC.text),
      maxAmt: maxC.text.trim().isEmpty ? null : numOf(maxC.text),
    );
    if (mounted) setState(() => list = l);
  }

  Future<void> _filters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ADVANCED FILTERS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: from ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d != null) setS(() => from = d);
                  },
                  child: Text(from == null ? 'From date' : dmy(iso(from!))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: to ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d != null) setS(() => to = d);
                  },
                  child: Text(to == null ? 'To date' : dmy(iso(to!))),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Tip: pick the same date in both for an exact date.', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: minC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min amount', prefixText: '₹ '))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: maxC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max amount', prefixText: '₹ '))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              TextButton(
                onPressed: () {
                  setS(() {
                    from = null;
                    to = null;
                    minC.clear();
                    maxC.clear();
                  });
                },
                child: const Text('CLEAR'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  quick = 'custom';
                  Navigator.pop(ctx);
                  _load();
                },
                child: const Text('APPLY'),
              ),
            ]),
          ]),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _action(String a, Rec r) async {
    final id = r['id'] as int;
    if (a == 'edit' || a == 'dup') {
      final row = await Db.quotation(id);
      if (row == null || !mounted) return;
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => QuoteFormScreen(editId: a == 'edit' ? id : null, initial: data, duplicate: a == 'dup')));
    } else if (a == 'pdf') {
      final row = await Db.quotation(id);
      if (row == null || !mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PdfScreen.fromRow(row)));
    } else if (a == 'del') {
      if (await confirmDelete(context, r['number'] as String)) {
        await Db.deleteQuotation(id);
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ALL QUOTATIONS'), actions: [
        IconButton(onPressed: _filters, icon: const Icon(Icons.filter_alt)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const QuoteFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('NEW'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Name, mobile, SA-0001, brand, model, variant, amount'),
            onChanged: (t) {
              q = t;
              _load();
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            for (final e in quickLabels.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: quick == e.key,
                  selectedColor: kGold,
                  onSelected: (_) => _applyQuick(e.key),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${list.length} quotation(s)', style: const TextStyle(fontSize: 12, color: Colors.black54))),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No quotations found.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final rev = (r['revision'] as int?) ?? 0;
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteDetailScreen(id: r['id'] as int)));
                          _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('${r['number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  if (rev > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(8)),
                                      child: Text('Rev $rev', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  const Spacer(),
                                  Text(dmy(r['qdate'] as String?), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                ]),
                                const SizedBox(height: 3),
                                Text('${r['cust_name']}  •  ${r['mobile'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${r['brand']} ${r['model']} ${r['variant']}', style: const TextStyle(fontSize: 12.5)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text(inr(numOf(r['total'])), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const Spacer(),
                                  Text('${r['status'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                ]),
                              ]),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (a) => _action(a, r),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'pdf', child: Text('View / Share PDF')),
                                PopupMenuItem(value: 'edit', child: Text('Edit (new revision)')),
                                PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                                PopupMenuItem(value: 'del', child: Text('Delete')),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// =====================================================================
// QUOTATION DETAIL
// =====================================================================
class QuoteDetailScreen extends StatefulWidget {
  final int id;
  const QuoteDetailScreen({super.key, required this.id});
  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  Rec? row;
  Map<String, dynamic> d = {};
  int revCount = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Db.quotation(widget.id);
    if (r == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final revs = await Db.revisions(widget.id);
    if (mounted) setState(() {
      row = r;
      d = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      revCount = revs.length;
    });
  }

  Widget _kv(String k, dynamic v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text('${v ?? ''}'.isEmpty ? '-' : '$v', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _card(String title, List<Widget> kids) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: kGold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ...kids,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (row == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final r = row!;
    final c = Map<String, dynamic>.from(d['customer'] ?? {});
    final v = Map<String, dynamic>.from(d['vehicle'] ?? {});
    final terms = (d['terms'] as List? ?? []);
    final rev = (r['revision'] as int?) ?? 0;
    final lines = priceLines(d).where((l) => l.isEx || l.amount != 0).toList();
    return Scaffold(
      appBar: AppBar(title: Text(revLabel(r['number'] as String, rev), style: const TextStyle(fontSize: 16))),
      body: ListView(padding: const EdgeInsets.all(10), children: [
        _card('QUOTATION', [
          _kv('Number', r['number']),
          _kv('Date', dmy(r['qdate'] as String?)),
          _kv('Pro. Invoice No', (d['proNo'] ?? '').toString().isEmpty ? r['number'] : d['proNo']),
          _kv('PDF Design', r['template'] == 'B' ? 'B – Modern Premium' : 'A – Original Excel'),
          Row(children: [
            const SizedBox(width: 110, child: Text('Status', style: TextStyle(color: Colors.black54, fontSize: 13))),
            DropdownButton<String>(
              value: kStatuses.contains(r['status']) ? r['status'] as String : null,
              hint: Text('${r['status'] ?? ''}'),
              items: [for (final s in kStatuses) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (s) async {
                if (s == null) return;
                await Db.setStatus(widget.id, s);
                _load();
              },
            ),
          ]),
        ]),
        _card('CUSTOMER', [
          _kv('Name', c['name']),
          _kv('Mobile', c['mobile']),
          _kv('Address', c['address']),
          _kv('PAN', c['pan']),
          _kv('KYC', c['kyc']),
        ]),
        _card('VEHICLE', [
          _kv('Brand', v['brand']),
          _kv('Model', v['model']),
          _kv('Year', v['year']),
          _kv('Variant', v['variant']),
          _kv('Fuel', v['fuel']),
          _kv('Transmission', v['trans']),
          _kv('Exterior', v['extColor']),
          _kv('Interior', v['intColor']),
        ]),
        _card('PRICE BREAKDOWN', [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(l.label, style: TextStyle(fontWeight: l.isEx ? FontWeight.bold : FontWeight.normal))),
                Text('${l.minus ? '- ' : ''}${inr(l.amount)}', style: TextStyle(fontWeight: l.isEx ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFFFFF00),
            child: Row(children: [
              const Expanded(child: Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              Text(inr(numOf(r['total'])), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
        ]),
        _card('TERMS & CONDITIONS', [
          for (var i = 0; i < terms.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${i + 1}) ${terms[i]['t']}',
                  style: TextStyle(fontSize: 12.5, color: terms[i]['r'] == true ? Colors.red : null)),
            ),
        ]),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => PdfScreen.fromRow(r)));
            _load();
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: const Padding(padding: EdgeInsets.all(10), child: Text('PREVIEW / DOWNLOAD / SHARE PDF')),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteFormScreen(editId: widget.id, initial: d)));
                _load();
              },
              icon: const Icon(Icons.edit),
              label: const Text('EDIT'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteFormScreen(initial: d, duplicate: true)));
                _load();
              },
              icon: const Icon(Icons.copy),
              label: const Text('DUPLICATE'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => VersionsScreen(id: widget.id)));
            _load();
          },
          icon: const Icon(Icons.history),
          label: Text('VERSION HISTORY ($revCount)'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            if (await confirmDelete(context, r['number'] as String)) {
              await Db.deleteQuotation(widget.id);
              if (mounted) Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('DELETE QUOTATION'),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// =====================================================================
// VERSION HISTORY + COMPARE
// =====================================================================
class VersionsScreen extends StatefulWidget {
  final int id;
  const VersionsScreen({super.key, required this.id});
  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> {
  Rec? q;
  List<Rec> revs = []; // newest first
  int? a, b; // selected revision numbers

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final qq = await Db.quotation(widget.id);
    final rr = await Db.revisions(widget.id);
    if (!mounted) return;
    setState(() {
      q = qq;
      revs = rr;
      if (rr.isNotEmpty) {
        a = rr.last['revision'] as int;
        b = rr.first['revision'] as int;
      }
    });
  }

  Rec? _rev(int? n) {
    for (final r in revs) {
      if (r['revision'] == n) return r;
    }
    return null;
  }

  Map<String, Map<String, dynamic>> _signed(Rec r) {
    final d = jsonDecode(r['data'] as String) as Map<String, dynamic>;
    final out = <String, Map<String, dynamic>>{};
    for (final l in priceLines(d)) {
      if (l.amount == 0) continue;
      out[l.label] = {'v': l.signed};
    }
    return out;
  }

  Widget _compare() {
    final ra = _rev(a), rb = _rev(b);
    if (ra == null || rb == null) return const SizedBox.shrink();
    final sa = _signed(ra), sb = _signed(rb);
    final keys = <String>[...sa.keys, ...sb.keys.where((k) => !sa.containsKey(k))];
    final ta = numOf(ra['total']), tb = numOf(rb['total']);
    Widget cell(String t, {bool bold = false, Color? col, TextAlign al = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Text(t, textAlign: al, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: col)),
        );
    TableRow row(String label, double x, double y, {bool bold = false}) {
      final diff = y - x;
      return TableRow(children: [
        cell(label, bold: bold, al: TextAlign.left),
        cell(x == 0 ? '-' : inr(x), bold: bold),
        cell(y == 0 ? '-' : inr(y), bold: bold),
        cell(diff == 0 ? '' : '${diff > 0 ? '+' : ''}${inr(diff)}',
            bold: bold, col: diff == 0 ? null : (diff > 0 ? Colors.red.shade700 : Colors.green.shade700)),
      ]);
    }

    DropdownButton<int> dd(int? val, void Function(int?) on) => DropdownButton<int>(
          value: val,
          isDense: true,
          items: [
            for (final r in revs)
              DropdownMenuItem(value: r['revision'] as int, child: Text((r['revision'] as int) == 0 ? 'Original' : 'Revision ${r['revision']}')),
          ],
          onChanged: on,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('COMPARE VERSIONS', style: TextStyle(fontWeight: FontWeight.bold, color: kGold, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            dd(a, (v) => setState(() => a = v)),
            const Text('vs'),
            dd(b, (v) => setState(() => b = v)),
          ]),
          const SizedBox(height: 6),
          Table(
            columnWidths: const {0: FlexColumnWidth(3.2), 1: FlexColumnWidth(2.2), 2: FlexColumnWidth(2.2), 3: FlexColumnWidth(2.2)},
            border: TableBorder(horizontalInside: BorderSide(color: Colors.black.withOpacity(.1))),
            children: [
              TableRow(decoration: const BoxDecoration(color: Color(0xFFEEEEEE)), children: [
                cell('Item', bold: true, al: TextAlign.left),
                cell(a == 0 ? 'Original' : 'Rev $a', bold: true),
                cell(b == 0 ? 'Original' : 'Rev $b', bold: true),
                cell('Change', bold: true),
              ]),
              for (final k in keys) row(k, (sa[k]?['v'] as double?) ?? 0, (sb[k]?['v'] as double?) ?? 0),
              row('GRAND TOTAL', ta, tb, bold: true),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HISTORY ${q?['number'] ?? ''}')),
      body: q == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(10), children: [
              if (revs.length > 1) _compare(),
              for (final r in revs) _revCard(r),
            ]),
    );
  }

  Widget _revCard(Rec r) {
    final rev = r['revision'] as int;
    final d = jsonDecode(r['data'] as String) as Map<String, dynamic>;
    final lines = priceLines(d).where((l) => l.isEx || l.amount != 0).toList();
    final latest = rev == revs.first['revision'];
    return Card(
      child: ExpansionTile(
        title: Text(revLabel(q!['number'] as String, rev), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${dmyTime(r['saved_at'] as String?)}${latest ? '  •  CURRENT' : ''}\nTotal: ${inr(numOf(r['total']))}'),
        isThreeLine: true,
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [Expanded(child: Text(l.label, style: const TextStyle(fontSize: 12.5))), Text('${l.minus ? '- ' : ''}${inr(l.amount)}', style: const TextStyle(fontSize: 12.5))]),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfScreen(
                    quotationId: null, // old versions: do not change the stored template
                    number: q!['number'] as String,
                    revision: rev,
                    data: d,
                    template: (r['template'] as String?) ?? 'A',
                  ),
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('VIEW / DOWNLOAD PDF'),
            ),
          ),
        ],
      ),
    );
  }
}
