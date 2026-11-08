import 'package:flutter/material.dart';
import '../db.dart';
import '../main.dart';
import 'backup.dart';
import 'customers.dart';
import 'price_master.dart';
import 'quote_form.dart';
import 'quote_list.dart';
import 'settings.dart';
import 'vehicles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> s = {'quotes': 0, 'today': 0, 'month': 0, 'customers': 0};
  bool backupDue = false;
  Map<String, String> co = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await Db.stats();
    final set = await Db.settings();
    final lb = set['last_backup'] ?? '';
    bool due;
    if (lb.isEmpty) {
      due = st['quotes']! > 0;
    } else {
      final dt = DateTime.tryParse(lb);
      due = dt == null || DateTime.now().difference(dt).inDays >= 7;
    }
    if (mounted) setState(() {
      s = st;
      co = set;
      backupDue = due;
    });
  }

  Future<void> _go(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    _load();
  }

  Widget _stat(String label, int v, IconData icon) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(children: [
              Icon(icon, color: kGold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _tile(String label, IconData icon, Widget page) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _go(page),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 30, color: kBlack),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: EdgeInsets.zero, children: [
          Container(
            color: kBlack,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 18),
            child: Column(children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 8),
              Text((co['company_name'] ?? 'SHREEJI AUTOLINK').toUpperCase(),
                  style: const TextStyle(color: kGold, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(co['tagline'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
            ]),
          ),
          Container(height: 3, color: kGold),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (backupDue)
                Card(
                  color: const Color(0xFFFFF4D6),
                  child: ListTile(
                    leading: const Icon(Icons.backup, color: Colors.orange),
                    title: const Text('Backup reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Create a backup of your quotations now.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _go(const BackupScreen()),
                  ),
                ),
              Row(children: [
                _stat('Total Quotations', s['quotes']!, Icons.description),
                _stat("Today's Quotations", s['today']!, Icons.today),
              ]),
              Row(children: [
                _stat("This Month's", s['month']!, Icons.calendar_month),
                _stat('Total Customers', s['customers']!, Icons.people),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: kBlack,
                      foregroundColor: kGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _go(const QuoteFormScreen()),
                  icon: const Icon(Icons.add_circle),
                  label: const Text('CREATE NEW QUOTATION',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                mainAxisSpacing: 0,
                crossAxisSpacing: 8,
                children: [
                  _tile('ALL QUOTATIONS', Icons.list_alt, const QuoteListScreen()),
                  _tile('CUSTOMER LIST', Icons.contacts, const CustomerListScreen()),
                  _tile('VEHICLE MASTER', Icons.directions_car, const VehicleListScreen()),
                  _tile('PRICE MASTER', Icons.price_change, const PriceMasterScreen()),
                  _tile('COMPANY SETTINGS', Icons.settings, const SettingsScreen()),
                  _tile('BACKUP & RESTORE', Icons.backup, const BackupScreen()),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
