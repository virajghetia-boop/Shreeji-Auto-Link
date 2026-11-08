import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'util.dart';

typedef Rec = Map<String, dynamic>;

class Db {
  static Database? _db;
  static Future<Database> get db async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'shreeji_autolink.db');
    return openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, mobile TEXT, address TEXT, pan TEXT, kyc TEXT, brand TEXT, model TEXT, notes TEXT, created_at TEXT)');
      await d.execute('CREATE TABLE vehicles(id INTEGER PRIMARY KEY AUTOINCREMENT, brand TEXT, model TEXT, year TEXT, variant TEXT, fuel TEXT, trans TEXT, ext_colors TEXT, int_colors TEXT, price REAL)');
      await d.execute('CREATE TABLE quotations(id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT UNIQUE, qdate TEXT, cust_name TEXT, mobile TEXT, brand TEXT, model TEXT, variant TEXT, total REAL, status TEXT, revision INTEGER, template TEXT, data TEXT, created_at TEXT, updated_at TEXT)');
      await d.execute('CREATE TABLE revisions(id INTEGER PRIMARY KEY AUTOINCREMENT, quotation_id INTEGER, revision INTEGER, total REAL, template TEXT, data TEXT, saved_at TEXT)');
      await d.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
      await d.execute('CREATE INDEX idx_q_date ON quotations(qdate)');
      await d.execute('CREATE INDEX idx_q_mobile ON quotations(mobile)');
      await d.execute('CREATE INDEX idx_rev_q ON revisions(quotation_id)');
    });
  }

  // ---------------- settings ----------------
  static Future<String> get(String k, [String def = '']) async {
    final d = await db;
    final r = await d.query('settings', where: 'k=?', whereArgs: [k]);
    if (r.isEmpty) return kDefaults[k] ?? def;
    return (r.first['v'] as String?) ?? def;
  }

  static Future<void> set(String k, String v) async {
    final d = await db;
    await d.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, String>> settings() async {
    final d = await db;
    final m = Map<String, String>.from(kDefaults);
    for (final r in await d.query('settings')) {
      m[r['k'] as String] = (r['v'] as String?) ?? '';
    }
    return m;
  }

  static Future<void> saveSettings(Map<String, String> m) async {
    final d = await db;
    final b = d.batch();
    m.forEach((k, v) => b.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace));
    await b.commit(noResult: true);
  }

  // ---------------- vehicles ----------------
  static Future<List<Rec>> vehicles([String q = '']) async {
    final d = await db;
    if (q.trim().isEmpty) {
      return d.query('vehicles', orderBy: 'brand COLLATE NOCASE, model COLLATE NOCASE, variant COLLATE NOCASE');
    }
    final l = '%${q.trim()}%';
    return d.query('vehicles',
        where: 'brand LIKE ? OR model LIKE ? OR variant LIKE ? OR year LIKE ?',
        whereArgs: [l, l, l, l],
        orderBy: 'brand COLLATE NOCASE, model COLLATE NOCASE');
  }

  static Future<Rec?> vehicle(int id) async {
    final d = await db;
    final r = await d.query('vehicles', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<void> saveVehicle(Rec v) async {
    final d = await db;
    final id = v['id'];
    final m = Map<String, Object?>.from(v)..remove('id');
    if (id == null) {
      await d.insert('vehicles', m);
    } else {
      await d.update('vehicles', m, where: 'id=?', whereArgs: [id]);
    }
  }

  static Future<void> deleteVehicle(int id) async {
    final d = await db;
    await d.delete('vehicles', where: 'id=?', whereArgs: [id]);
  }

  // ---------------- customers ----------------
  static Future<List<Rec>> customers([String q = '']) async {
    final d = await db;
    if (q.trim().isEmpty) return d.query('customers', orderBy: 'name COLLATE NOCASE');
    final l = '%${q.trim()}%';
    return d.query('customers',
        where: 'name LIKE ? OR mobile LIKE ? OR address LIKE ?', whereArgs: [l, l, l], orderBy: 'name COLLATE NOCASE');
  }

  static Future<Rec?> customerByMobile(String m) async {
    final d = await db;
    final r = await d.query('customers', where: 'mobile=?', whereArgs: [m.trim()]);
    return r.isEmpty ? null : r.first;
  }

  static Future<int> saveCustomer(Rec c) async {
    final d = await db;
    final m = Map<String, Object?>.from(c)..remove('id');
    if (c['id'] != null) {
      await d.update('customers', m, where: 'id=?', whereArgs: [c['id']]);
      return c['id'] as int;
    }
    m['created_at'] = DateTime.now().toIso8601String();
    return d.insert('customers', m);
  }

  static Future<void> deleteCustomer(int id) async {
    final d = await db;
    await d.delete('customers', where: 'id=?', whereArgs: [id]);
  }

  static Future<void> _upsertCustomer(Rec c, Rec v) async {
    final mobile = ((c['mobile'] as String?) ?? '').trim();
    if (mobile.isEmpty) return;
    final ex = await customerByMobile(mobile);
    final row = <String, Object?>{
      'name': c['name'],
      'mobile': mobile,
      'address': c['address'],
      'pan': c['pan'],
      'kyc': c['kyc'],
      'brand': v['brand'],
      'model': v['model'],
    };
    if (ex != null) {
      row['id'] = ex['id'];
      row['notes'] = ex['notes'];
    }
    await saveCustomer(row);
  }

  // ---------------- quotations ----------------
  static Future<String> _nextNumber(Transaction t) async {
    final r = await t.query('settings', where: 'k=?', whereArgs: ['quote_counter']);
    var n = r.isEmpty ? 0 : int.tryParse(r.first['v'] as String? ?? '0') ?? 0;
    // safety: never go below highest number ever stored
    final mx = await t.rawQuery("SELECT MAX(CAST(SUBSTR(number,4) AS INTEGER)) AS m FROM quotations");
    final m = (mx.first['m'] as int?) ?? 0;
    if (m > n) n = m;
    n++;
    await t.insert('settings', {'k': 'quote_counter', 'v': '$n'}, conflictAlgorithm: ConflictAlgorithm.replace);
    return 'SA-${n.toString().padLeft(4, '0')}';
  }

  /// New quotation when [id] is null, otherwise saves a new REVISION (previous version is kept).
  static Future<int> saveQuotation(Map<String, dynamic> data, {int? id}) async {
    final d = await db;
    final now = DateTime.now().toIso8601String();
    final total = calcTotal(data);
    data['total'] = total;
    final c = Map<String, dynamic>.from(data['customer']);
    final v = Map<String, dynamic>.from(data['vehicle']);
    int qid = 0;
    await d.transaction((t) async {
      final base = <String, Object?>{
        'qdate': data['date'],
        'cust_name': c['name'],
        'mobile': c['mobile'],
        'brand': v['brand'],
        'model': v['model'],
        'variant': v['variant'],
        'total': total,
        'status': data['status'] ?? 'Quoted',
        'template': data['template'] ?? 'A',
        'updated_at': now,
      };
      if (id == null) {
        final no = await _nextNumber(t);
        qid = await t.insert('quotations',
            {...base, 'number': no, 'revision': 0, 'data': jsonEncode(data), 'created_at': now});
        await t.insert('revisions', {
          'quotation_id': qid, 'revision': 0, 'total': total,
          'template': base['template'], 'data': jsonEncode(data), 'saved_at': now,
        });
      } else {
        final r = await t.query('quotations', columns: ['revision'], where: 'id=?', whereArgs: [id]);
        final rev = ((r.first['revision'] as int?) ?? 0) + 1;
        qid = id;
        await t.update('quotations', {...base, 'revision': rev, 'data': jsonEncode(data)},
            where: 'id=?', whereArgs: [id]);
        await t.insert('revisions', {
          'quotation_id': id, 'revision': rev, 'total': total,
          'template': base['template'], 'data': jsonEncode(data), 'saved_at': now,
        });
      }
    });
    await _upsertCustomer(c, v);
    return qid;
  }

  static Future<Rec?> quotation(int id) async {
    final d = await db;
    final r = await d.query('quotations', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<List<Rec>> revisions(int qid) async {
    final d = await db;
    return d.query('revisions', where: 'quotation_id=?', whereArgs: [qid], orderBy: 'revision DESC');
  }

  static Future<void> setStatus(int id, String s) async {
    final d = await db;
    await d.update('quotations', {'status': s}, where: 'id=?', whereArgs: [id]);
  }

  static Future<void> setTemplate(int id, String t) async {
    final d = await db;
    await d.update('quotations', {'template': t}, where: 'id=?', whereArgs: [id]);
  }

  /// Quotation numbers are NEVER reused: the counter is not decreased on delete.
  static Future<void> deleteQuotation(int id) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('revisions', where: 'quotation_id=?', whereArgs: [id]);
      await t.delete('quotations', where: 'id=?', whereArgs: [id]);
    });
  }

  static Future<List<Rec>> searchQuotations(
      {String q = '', String? from, String? to, double? minAmt, double? maxAmt}) async {
    final d = await db;
    final w = <String>[];
    final a = <Object?>[];
    if (q.trim().isNotEmpty) {
      final l = '%${q.trim()}%';
      w.add('(number LIKE ? OR cust_name LIKE ? OR mobile LIKE ? OR brand LIKE ? OR model LIKE ? OR variant LIKE ? OR qdate LIKE ? OR CAST(CAST(total AS INTEGER) AS TEXT) LIKE ?)');
      a.addAll(List.filled(8, l));
    }
    if (from != null) {
      w.add('qdate>=?');
      a.add(from);
    }
    if (to != null) {
      w.add('qdate<=?');
      a.add(to);
    }
    if (minAmt != null) {
      w.add('total>=?');
      a.add(minAmt);
    }
    if (maxAmt != null) {
      w.add('total<=?');
      a.add(maxAmt);
    }
    return d.query('quotations',
        where: w.isEmpty ? null : w.join(' AND '), whereArgs: a, orderBy: 'id DESC');
  }

  static Future<List<Rec>> quotationsForMobile(String mobile) async {
    final d = await db;
    return d.query('quotations', where: 'mobile=?', whereArgs: [mobile], orderBy: 'id DESC');
  }

  static Future<Map<String, int>> stats() async {
    final d = await db;
    final today = iso(DateTime.now());
    final month = today.substring(0, 7);
    final total = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM quotations')) ?? 0;
    final td = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM quotations WHERE qdate=?', [today])) ?? 0;
    final mo = Sqflite.firstIntValue(
            await d.rawQuery('SELECT COUNT(*) FROM quotations WHERE qdate LIKE ?', ['$month%'])) ??
        0;
    final cu = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
    return {'quotes': total, 'today': td, 'month': mo, 'customers': cu};
  }

  // ---------------- backup / restore ----------------
  static const _secKeys = ['pin_hash', 'lock_enabled', 'bio_enabled'];
  static const _tables = ['customers', 'vehicles', 'quotations', 'revisions', 'settings'];

  static Future<String> exportJson() async {
    final d = await db;
    final out = <String, dynamic>{
      'app': 'SHREEJI_AUTOLINK',
      'version': 1,
      'created': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };
    for (final t in _tables) {
      var rows = await d.query(t);
      if (t == 'settings') rows = rows.where((r) => !_secKeys.contains(r['k'])).toList();
      out['tables'][t] = rows;
    }
    return jsonEncode(out);
  }

  static Future<void> importJson(String s) async {
    final m = jsonDecode(s);
    if (m is! Map || m['app'] != 'SHREEJI_AUTOLINK' || m['tables'] is! Map) {
      throw Exception('This is not a valid Shreeji Autolink backup file.');
    }
    final d = await db;
    final cur = int.tryParse(await get('quote_counter', '0')) ?? 0;
    final tables = m['tables'] as Map;
    await d.transaction((t) async {
      for (final tb in ['revisions', 'quotations', 'customers', 'vehicles']) {
        await t.delete(tb);
      }
      await t.delete('settings', where: "k NOT IN ('pin_hash','lock_enabled','bio_enabled')");
      for (final tb in _tables) {
        for (final r in (tables[tb] as List? ?? [])) {
          final row = Map<String, Object?>.from(r as Map);
          if (tb == 'settings' && _secKeys.contains(row['k'])) continue;
          await t.insert(tb, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      final mx = await t.rawQuery('SELECT MAX(CAST(SUBSTR(number,4) AS INTEGER)) AS m FROM quotations');
      final restored = int.tryParse(((await t.query('settings', where: "k='quote_counter'")).firstOrNull?['v'] as String?) ?? '0') ?? 0;
      final best = [cur, restored, (mx.first['m'] as int?) ?? 0].reduce((a, b) => a > b ? a : b);
      await t.insert('settings', {'k': 'quote_counter', 'v': '$best'}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
