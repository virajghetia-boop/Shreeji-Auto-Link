import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db.dart';
import '../main.dart';
import '../util.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<File> files = [];
  String last = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/backups');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> _load() async {
    final d = await _dir();
    final l = d.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final lb = await Db.get('last_backup');
    if (mounted) setState(() {
      files = l;
      last = lb;
    });
  }

  String _stamp() {
    final n = DateTime.now();
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<File> _writeLocal(String prefix) async {
    final json = await Db.exportJson();
    final f = File('${(await _dir()).path}/${prefix}_${_stamp()}.json');
    await f.writeAsString(json, flush: true);
    return f;
  }

  Future<void> _export() async {
    setState(() => busy = true);
    try {
      final f = await _writeLocal('shreeji_backup');
      await Db.set('last_backup', DateTime.now().toIso8601String());
      final bytes = await f.readAsBytes();
      String? saved;
      try {
        saved = await FilePicker.platform.saveFile(
          dialogTitle: 'Save backup to phone storage',
          fileName: f.uri.pathSegments.last,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } catch (_) {}
      await _load();
      _snack(saved != null ? 'Backup saved to phone storage and inside the app.' : 'Backup saved inside the app. Use SHARE to copy it out.');
    } catch (e) {
      _snack('Backup failed: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _share(File f) async {
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')], text: 'Shreeji Autolink backup');
  }

  Future<bool> _confirmRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('Current customers, quotations, vehicles and settings will be REPLACED by the backup.\n\n'
            'A safety backup of the current data is created automatically first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESTORE')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _restoreFromString(String s) async {
    if (!await _confirmRestore()) return;
    setState(() => busy = true);
    try {
      await _writeLocal('before_restore'); // never lose current data
      await Db.importJson(s);
      await _load();
      _snack('Restore completed successfully.');
    } catch (e) {
      _snack('Restore failed: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _import() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty) return;
    final pf = r.files.single;
    List<int>? bytes = pf.bytes;
    if (bytes == null && pf.path != null) bytes = await File(pf.path!).readAsBytes();
    if (bytes == null) {
      _snack('Could not read the selected file');
      return;
    }
    await _restoreFromString(utf8.decode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BACKUP & RESTORE')),
      body: ListView(padding: const EdgeInsets.all(10), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(last.isEmpty ? 'No backup created yet' : 'Last backup: ${dmyTime(last)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Backup contains: customers, quotations (with all revisions), vehicle master, company settings, terms and price master.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _export,
                  icon: const Icon(Icons.backup),
                  label: const Padding(padding: EdgeInsets.all(10), child: Text('CREATE BACKUP NOW')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _import,
                  icon: const Icon(Icons.restore),
                  label: const Padding(padding: EdgeInsets.all(10), child: Text('RESTORE FROM FILE (phone storage)')),
                ),
              ),
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 10, 6, 4),
          child: Text('BACKUPS STORED IN APP (never deleted automatically)',
              style: TextStyle(fontWeight: FontWeight.bold, color: kGold, fontSize: 12, letterSpacing: 1)),
        ),
        if (files.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No backups yet.')),
        for (final f in files)
          Card(
            child: ListTile(
              title: Text(f.uri.pathSegments.last, style: const TextStyle(fontSize: 13)),
              subtitle: Text('${dmyTime(f.lastModifiedSync().toIso8601String())}  •  ${(f.lengthSync() / 1024).toStringAsFixed(1)} KB'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.share), onPressed: () => _share(f)),
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: busy ? null : () async => _restoreFromString(await f.readAsString()),
                ),
              ]),
            ),
          ),
        if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
