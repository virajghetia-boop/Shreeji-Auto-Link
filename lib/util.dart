import 'dart:convert';
import 'package:crypto/crypto.dart';

/// [key, label]
const List<List<String>> kPriceFields = [
  ['ex', 'EX-SHOWROOM PRICE'],
  ['tcs', 'TCS'],
  ['municipal', 'MUNICIPAL TAX'],
  ['rto', 'RTO REGISTRATION CHARGES'],
  ['insurance', 'INSURANCE'],
  ['tempReg', 'TEMPORARY REGISTRATION CHARGES'],
  ['premium', 'PREMIUM'],
  ['transport', 'TRANSPORTATION BY ROAD'],
  ['warranty', 'EXTENDED WARRANTY'],
  ['accessories', 'ACCESSORIES'],
  ['discIns', 'DISCOUNT IN INSURANCE'],
  ['other', 'OTHER ADDITIONAL CHARGES'],
];

const List<String> kStatuses = ['Quoted', 'Sent to Customer', 'Booked', 'Cancelled'];

const String kWaMessage = 'Dear Customer,\n\n'
    'Thank you for choosing Shreeji Autolink.\n\n'
    'Please find your vehicle quotation attached.\n\n'
    'For any assistance, please contact us.\n\n'
    'Regards,\nSHREEJI AUTOLINK.';

const Map<String, String> kDefaults = {
  'company_name': 'SHREEJI AUTOLINK',
  'tagline': 'SALES | USED CAR | INSURANCE | FINANCE',
  'address': '612, R.K. Empire, Near Mavdi Circle, 150 FT Ring Road, Rajkot 360004',
  'acc_name': 'SHREEJI AUTOLINK',
  'acc_no': '112364400000861',
  'ifsc': 'YESB0001123',
  'contact_person': 'RAVI PATEL',
  'contact_no': '9724443421',
  'email': 'shreejiautolink1@gmail.com',
  'tcs_rate': '1',
  'tcs_threshold': '1000000',
  'tcs_mode': 'full', // full = on whole ex-showroom, excess = only above threshold
  'fastag': '600',
  'default_template': 'A',
  'quote_counter': '0',
  'lock_enabled': '0',
  'bio_enabled': '0',
  'last_backup': '',
};

final List<Map<String, dynamic>> kDefaultTerms = [
  {'t': 'Payment to be made in favour of "Shreeji Autolink" only by Cheque / RTGS payable at Rajkot.', 'r': false},
  {'t': 'INSURANCE DIFFERENCE IS NOT REFUNDABLE, DISCOUNT WILL SPLIT INVOICE, RTO AND INSURANCE AMOUNT ALSO.', 'r': true},
  {'t': 'Delivery of the car is subject to realization of Cheque / Demand Draft / RTGS and NEFT.', 'r': false},
  {'t': 'Installation of FASTag is mandatory as per RTO rules and Rs. {FASTAG}/- will be charged.', 'r': false},
  {'t': 'PAN Number and Aadhaar Card to be provided mandatory (RENT AGREEMENT IS NOT VALID).', 'r': false},
  {'t': '{TCS_RATE}% TCS applicable on Ex-Showroom Price above {TCS_LIMIT}.', 'r': false},
  {'t': 'Temporary Registration and Special Number would be charged extra.', 'r': false},
];

double numOf(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
}

String numStr(double v) {
  if (v == 0) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

String trimNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Indian grouping: 3988011 -> 39,88,011
String inr(num v, {bool symbol = true}) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  String res;
  if (s.length <= 3) {
    res = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    res = '${parts.join(',')},$last3';
  }
  return '${neg ? '-' : ''}${symbol ? '₹' : ''}$res';
}

String two(int n) => n.toString().padLeft(2, '0');
String iso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String dmy(String? isoDate) {
  if (isoDate == null || isoDate.length < 10) return isoDate ?? '';
  return '${isoDate.substring(8, 10)}-${isoDate.substring(5, 7)}-${isoDate.substring(0, 4)}';
}

String dmyTime(String? isoDt) {
  if (isoDt == null || isoDt.length < 16) return isoDt ?? '';
  final d = DateTime.tryParse(isoDt);
  if (d == null) return isoDt;
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String revLabel(String number, int rev) => rev == 0 ? '$number – Original' : '$number – Revision $rev';

List<String> splitList(String? s) =>
    (s ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

String hashPin(String pin) => sha256.convert(utf8.encode('shreeji-autolink:$pin')).toString();

double calcTcs(double ex, Map<String, String> s) {
  final rate = double.tryParse(s['tcs_rate'] ?? '1') ?? 0;
  final th = double.tryParse(s['tcs_threshold'] ?? '1000000') ?? 0;
  if (ex <= th || rate <= 0) return 0;
  final base = s['tcs_mode'] == 'excess' ? ex - th : ex;
  return (base * rate / 100).roundToDouble();
}

double calcTotal(Map<String, dynamic> d) {
  final p = Map<String, dynamic>.from(d['prices'] ?? {});
  double t = 0;
  for (final f in kPriceFields) {
    final v = numOf(p[f[0]]);
    t += f[0] == 'discIns' ? -v : v;
  }
  for (final c in (d['custom'] as List? ?? [])) {
    final v = numOf(c['amount']);
    t += (c['minus'] == true) ? -v : v;
  }
  return t;
}

List<Map<String, dynamic>> loadTerms(Map<String, String> st, {bool resolve = true}) {
  List<Map<String, dynamic>> list;
  final raw = st['terms'];
  if (raw == null || raw.isEmpty) {
    list = kDefaultTerms.map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (!resolve) return list;
  final th = double.tryParse(st['tcs_threshold'] ?? '1000000') ?? 1000000;
  final limit = 'Rs. ${(th / 100000).toStringAsFixed(2)} Lakhs';
  final rate = trimNum(double.tryParse(st['tcs_rate'] ?? '1') ?? 1);
  return list
      .map((e) => {
            't': (e['t'] as String)
                .replaceAll('{FASTAG}', st['fastag'] ?? '600')
                .replaceAll('{TCS_RATE}', rate)
                .replaceAll('{TCS_LIMIT}', limit),
            'r': e['r'] == true,
          })
      .toList();
}

class PriceLine {
  final String label;
  final double amount;
  final bool minus;
  final bool isEx;
  PriceLine(this.label, this.amount, this.minus, {this.isEx = false});
  double get signed => minus ? -amount : amount;
}

List<PriceLine> priceLines(Map<String, dynamic> d) {
  final p = Map<String, dynamic>.from(d['prices'] ?? {});
  final out = <PriceLine>[];
  for (final f in kPriceFields) {
    var label = f[1];
    if (f[0] == 'tcs') label = (d['tcsLabel'] as String?) ?? 'TCS';
    out.add(PriceLine(label, numOf(p[f[0]]), f[0] == 'discIns', isEx: f[0] == 'ex'));
  }
  for (final c in (d['custom'] as List? ?? [])) {
    final l = (c['label'] as String?)?.trim() ?? '';
    out.add(PriceLine(l.isEmpty ? 'ADDITIONAL CHARGE' : l.toUpperCase(), numOf(c['amount']), c['minus'] == true));
  }
  return out;
}
