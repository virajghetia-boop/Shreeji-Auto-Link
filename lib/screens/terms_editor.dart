import 'package:flutter/material.dart';

/// Edit / add / delete / reorder terms. Mutates [terms] in place and calls [onChanged].
class TermsEditor extends StatefulWidget {
  final List<Map<String, dynamic>> terms;
  final VoidCallback onChanged;
  const TermsEditor({super.key, required this.terms, required this.onChanged});
  @override
  State<TermsEditor> createState() => _TermsEditorState();
}

class _TermsEditorState extends State<TermsEditor> {
  Future<void> _edit(int? i) async {
    final t = TextEditingController(text: i == null ? '' : '${widget.terms[i]['t']}');
    bool red = i == null ? false : widget.terms[i]['r'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(i == null ? 'Add term' : 'Edit term'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: t, maxLines: 4, autofocus: true, decoration: const InputDecoration(labelText: 'Term text')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Highlight in red'),
              value: red,
              onChanged: (v) => setD(() => red = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SAVE')),
          ],
        ),
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      setState(() {
        final m = {'t': t.text.trim(), 'r': red};
        if (i == null) {
          widget.terms.add(m);
        } else {
          widget.terms[i] = m;
        }
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.terms.length,
        onReorder: (a, b) {
          setState(() {
            if (b > a) b -= 1;
            final x = widget.terms.removeAt(a);
            widget.terms.insert(b, x);
          });
          widget.onChanged();
        },
        itemBuilder: (_, i) {
          final t = widget.terms[i];
          return Card(
            key: ValueKey('term_${i}_${t['t']}'),
            child: ListTile(
              dense: true,
              leading: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text('${t['t']}',
                  style: TextStyle(fontSize: 12.5, color: t['r'] == true ? Colors.red : null)),
              onTap: () => _edit(i),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  setState(() => widget.terms.removeAt(i));
                  widget.onChanged();
                },
              ),
            ),
          );
        },
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('ADD TERM')),
      ),
      const Text('Long-press and drag a term to reorder.', style: TextStyle(fontSize: 11, color: Colors.black54)),
    ]);
  }
}
