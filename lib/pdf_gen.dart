import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'util.dart';

Future<Uint8List> buildQuotationPdf(Map<String, dynamic> d, String number, int rev, String template) async {
  final logo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List());
  final doc = pw.Document(title: revLabel(number, rev), author: 'Shreeji Autolink');
  if (template == 'B') {
    _templateB(doc, d, number, rev, logo);
  } else {
    _templateA(doc, d, number, rev, logo);
  }
  return doc.save();
}

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v as Map?) ?? {});
String _s(dynamic v) => (v ?? '').toString().trim();

String _amt(PriceLine r) => r.amount == 0 ? '' : '${r.minus ? '- ' : ''}${inr(r.amount, symbol: false)}';

String _modelTitle(Map v) => [_s(v['brand']), _s(v['model']), _s(v['year'])].where((e) => e.isNotEmpty).join(' ').toUpperCase();

String _colour(Map v) {
  final ext = _s(v['extColor']).toUpperCase();
  final inn = _s(v['intColor']).toUpperCase();
  if (ext.isEmpty && inn.isEmpty) return '';
  if (inn.isEmpty) return ext;
  if (ext.isEmpty) return '$inn INTERIOR';
  return '$ext WITH $inn INTERIOR';
}

// =====================================================================
// TEMPLATE A  –  original Excel design
// =====================================================================
void _templateA(pw.Document doc, Map<String, dynamic> d, String no, int rev, pw.MemoryImage logo) {
  final co = _m(d['company']);
  final c = _m(d['customer']);
  final v = _m(d['vehicle']);
  final terms = (d['terms'] as List? ?? []).map((e) => _m(e)).toList();
  final lines = priceLines(d);
  final total = calcTotal(d);

  final pink = PdfColor.fromInt(0xFFF2DCDB);
  final pink2 = PdfColor.fromInt(0xFFE6B8B7);
  final yellow = PdfColor.fromInt(0xFFFFFF00);
  final grey = PdfColor.fromInt(0xFFEEEEEE);
  const red = PdfColor.fromInt(0xFFFF0000);
  final tr = pw.Font.times();
  final tb = pw.Font.timesBold();
  final hb = pw.Font.helveticaBold();
  const bw = 0.7;

  pw.TextStyle st(double s, {bool b = false, PdfColor? col}) =>
      pw.TextStyle(font: b ? tb : tr, fontSize: s, color: col ?? PdfColors.black);

  pw.Widget centerRow(String t, {bool sans = false, double size = 12}) => pw.Container(
        width: double.infinity,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: bw)),
        child: pw.Text(t,
            textAlign: pw.TextAlign.center,
            style: sans ? pw.TextStyle(font: hb, fontSize: size) : st(size, b: true)),
      );

  final header = pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    decoration: pw.BoxDecoration(color: pink, border: pw.Border.all(width: bw)),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(width: 92, height: 52, child: pw.Image(logo, fit: pw.BoxFit.contain)),
      pw.Expanded(
        child: pw.Column(children: [
          pw.Text(_s(co['name']).toUpperCase(), style: st(26, b: true)),
          pw.SizedBox(height: 2),
          pw.Text(_s(co['tagline']), style: st(11)),
          pw.SizedBox(height: 2),
          pw.Text(_s(co['address']).toUpperCase(),
              textAlign: pw.TextAlign.center, style: st(10)),
        ]),
      ),
      pw.SizedBox(width: 92),
    ]),
  );

  pw.Widget lbl(String t, {bool bold = true}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(t, style: st(9.5, b: bold)));

  final custTable = pw.Table(
    border: pw.TableBorder.all(width: bw),
    columnWidths: {
      0: const pw.FlexColumnWidth(5.2),
      1: const pw.FlexColumnWidth(1.7),
      2: const pw.FlexColumnWidth(2.5),
    },
    children: [
      pw.TableRow(children: [
        lbl('NAME:-  ${_s(c['name']).toUpperCase()}'),
        lbl('PRO.INV.NO'),
        lbl(_s(d['proNo']).isEmpty ? no : _s(d['proNo']), bold: false),
      ]),
      pw.TableRow(children: [
        lbl('ADD-  ${_s(c['address'])}'),
        lbl('DATE'),
        lbl(dmy(_s(d['date'])), bold: false),
      ]),
      pw.TableRow(children: [
        lbl('PAN NO:-  ${_s(c['pan']).toUpperCase()}'),
        lbl('KYC'),
        lbl(_s(c['kyc']), bold: false),
      ]),
      pw.TableRow(children: [
        lbl(''),
        lbl('MOB'),
        lbl(_s(c['mobile']), bold: false),
      ]),
    ],
  );

  // ---- price block (3 columns of fixed-height rows) ----
  const rh = 19.0;
  pw.Widget cell(String t,
          {bool bold = false, PdfColor? fill, pw.Alignment al = pw.Alignment.centerLeft, double size = 10.5}) =>
      pw.Container(
        height: rh,
        alignment: al,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        decoration: pw.BoxDecoration(color: fill, border: const pw.Border(bottom: pw.BorderSide(width: bw))),
        child: pw.Text(t, maxLines: 1, style: st(size, b: bold)),
      );

  final labels = <pw.Widget>[
    cell('DESCRIPTION OF VEHICLE', bold: true, al: pw.Alignment.center, size: 10),
    ...lines.map((l) => cell(l.label, bold: true)),
    cell('GRAND TOTAL', bold: true),
  ];
  final amounts = <pw.Widget>[
    cell('PRICE (Rs.)', bold: true, al: pw.Alignment.center, size: 10),
    ...lines.map((l) => cell(_amt(l),
        fill: l.isEx ? yellow : null, bold: l.isEx, al: pw.Alignment.centerRight, size: 11)),
    cell(inr(total, symbol: false), fill: yellow, bold: true, al: pw.Alignment.centerRight, size: 11.5),
  ];
  final specs = <String>[
    if (_s(v['year']).isNotEmpty) 'YEAR : ${_s(v['year'])}',
    if (_s(v['fuel']).isNotEmpty) 'FUEL : ${_s(v['fuel']).toUpperCase()}',
    if (_s(v['trans']).isNotEmpty) 'TRANSMISSION : ${_s(v['trans']).toUpperCase()}',
    if (_s(v['extColor']).isNotEmpty) 'EXTERIOR : ${_s(v['extColor']).toUpperCase()}',
    if (_s(v['intColor']).isNotEmpty) 'INTERIOR : ${_s(v['intColor']).toUpperCase()}',
  ];
  final priceBlock = pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(width: bw)),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(flex: 5, child: pw.Column(children: labels)),
      pw.Expanded(
        flex: 4,
        child: pw.Container(
          height: rh * (labels.length),
          padding: const pw.EdgeInsets.all(6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(width: bw), right: pw.BorderSide(width: bw))),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final s in specs) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(s, style: st(9.5, b: true)))]),
        ),
      ),
      pw.Expanded(flex: 3, child: pw.Column(children: amounts)),
    ]),
  );

  final termsTable = pw.Table(
    border: pw.TableBorder.all(width: bw),
    children: [
      for (var i = 0; i < terms.length; i++)
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            child: pw.Text('${i + 1}) ${_s(terms[i]['t'])}',
                style: st(9.5, b: i == 0 || terms[i]['r'] == true, col: terms[i]['r'] == true ? red : PdfColors.black)),
          ),
        ]),
    ],
  );

  final bank = pw.SizedBox(
    height: 100,
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Expanded(
        flex: 5,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
              height: 20,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: bw)),
              child: pw.Text('BANK DETAILS', style: st(10, b: true))),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(color: yellow, border: pw.Border.all(width: bw)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('AC NAME-${_s(co['accName']).toUpperCase()}', style: st(10.5)),
                pw.SizedBox(height: 2),
                pw.Text('AC NO-${_s(co['accNo'])}', style: st(10.5)),
                pw.SizedBox(height: 2),
                pw.Text('IFSC-${_s(co['ifsc']).toUpperCase()}', style: st(10.5)),
              ]),
            ),
          ),
        ]),
      ),
      pw.Expanded(
        flex: 4,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
              height: 20,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: bw)),
              child: pw.Text('FOR CONTACT', style: st(10, b: true))),
          pw.Container(
              height: 20,
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              decoration: pw.BoxDecoration(color: pink2, border: pw.Border.all(width: bw)),
              child: pw.Text('${_s(co['contactPerson']).toUpperCase()} :- ${_s(co['contactNo'])}', style: st(10.5))),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.topCenter,
              padding: const pw.EdgeInsets.only(top: 4),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: bw)),
              child: pw.Text('Authorized Signatory', style: st(10, b: true)),
            ),
          ),
        ]),
      ),
    ]),
  );

  final footer = pw.Container(
    width: double.infinity,
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: bw)),
    child: pw.Text('E-mail : ${_s(co['email'])}', style: st(10.5, b: true)),
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => [
      header,
      centerRow('MODEL : ${_modelTitle(v)}', size: 13),
      centerRow('VARIANT:- ${_s(v['variant']).toUpperCase()}', size: 12.5),
      centerRow('COLOUR: ${_colour(v)}', sans: true, size: 11.5),
      pw.Container(
        height: 14,
        width: double.infinity,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: grey, border: pw.Border.all(width: bw)),
        child: pw.Text('Quotation No: ${revLabel(no, rev)}', style: st(8, col: PdfColors.grey700)),
      ),
      custTable,
      priceBlock,
      termsTable,
      bank,
      footer,
    ],
  ));
}

// =====================================================================
// TEMPLATE B  –  modern premium (black / white / gold)
// =====================================================================
void _templateB(pw.Document doc, Map<String, dynamic> d, String no, int rev, pw.MemoryImage logo) {
  final co = _m(d['company']);
  final c = _m(d['customer']);
  final v = _m(d['vehicle']);
  final terms = (d['terms'] as List? ?? []).map((e) => _m(e)).toList();
  final lines = priceLines(d);
  final total = calcTotal(d);

  final gold = PdfColor.fromInt(0xFFC9A227);
  final cream = PdfColor.fromInt(0xFFFAF7EE);
  final lineGrey = PdfColor.fromInt(0xFFDDDDDD);
  final black = PdfColor.fromInt(0xFF111111);
  final h = pw.Font.helvetica();
  final hb = pw.Font.helveticaBold();

  pw.TextStyle st(double s, {bool b = false, PdfColor? col, double? ls}) =>
      pw.TextStyle(font: b ? hb : h, fontSize: s, color: col ?? black, letterSpacing: ls);

  pw.Widget sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 11, color: gold),
          pw.SizedBox(width: 6),
          pw.Text(t, style: st(9.5, b: true, col: gold, ls: 1.5)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(height: 0.6, color: lineGrey)),
        ]),
      );

  final band = pw.Container(
    color: black,
    padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 16),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(height: 62, child: pw.Image(logo, fit: pw.BoxFit.contain)),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_s(co['name']).toUpperCase(), style: st(19, b: true, col: PdfColors.white, ls: 2)),
          pw.SizedBox(height: 3),
          pw.Text(_s(co['tagline']), style: st(8, col: gold, ls: 1)),
          pw.SizedBox(height: 3),
          pw.Text(_s(co['address']), style: st(7.5, col: PdfColors.grey400)),
        ]),
      ),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text('QUOTATION', style: st(15, b: true, col: gold, ls: 3)),
        pw.SizedBox(height: 4),
        pw.Text(no, style: st(12, b: true, col: PdfColors.white)),
        if (rev > 0) pw.Text('Revision $rev', style: st(8, col: PdfColors.grey400)),
        pw.SizedBox(height: 2),
        pw.Text(dmy(_s(d['date'])), style: st(9, col: PdfColors.grey400)),
      ]),
    ]),
  );

  final goldLine = pw.Container(height: 3, color: gold);

  pw.Widget chip(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: gold, width: 0.7), borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: st(6.5, col: PdfColors.grey600, ls: 1)),
          pw.SizedBox(height: 1.5),
          pw.Text(value, style: st(9, b: true)),
        ]),
      );

  final chips = <pw.Widget>[
    if (_s(v['year']).isNotEmpty) chip('YEAR', _s(v['year'])),
    if (_s(v['fuel']).isNotEmpty) chip('FUEL', _s(v['fuel'])),
    if (_s(v['trans']).isNotEmpty) chip('TRANSMISSION', _s(v['trans'])),
    if (_s(v['extColor']).isNotEmpty) chip('EXTERIOR', _s(v['extColor'])),
    if (_s(v['intColor']).isNotEmpty) chip('INTERIOR', _s(v['intColor'])),
  ];

  final vehicleCard = pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(color: cream, border: pw.Border.all(color: gold, width: 0.8)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(_s(v['brand']).toUpperCase(), style: st(9, b: true, col: gold, ls: 2.5)),
      pw.SizedBox(height: 3),
      pw.Text([_s(v['model']), _s(v['year'])].where((e) => e.isNotEmpty).join(' ').toUpperCase(),
          style: st(23, b: true)),
      pw.SizedBox(height: 3),
      pw.Text(_s(v['variant']), style: st(12, col: PdfColors.grey800)),
      if (chips.isNotEmpty) pw.SizedBox(height: 10),
      if (chips.isNotEmpty) pw.Wrap(spacing: 8, runSpacing: 6, children: chips),
    ]),
  );

  pw.Widget kv(String k, String val) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 70, child: pw.Text(k, style: st(8, col: PdfColors.grey600))),
          pw.Expanded(child: pw.Text(val.isEmpty ? '-' : val, style: st(9, b: true))),
        ]),
      );

  final customer = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(
      flex: 5,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: lineGrey, width: 0.8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_s(c['name']).toUpperCase(), style: st(12, b: true)),
          pw.SizedBox(height: 4),
          kv('Mobile', _s(c['mobile'])),
          kv('Address', _s(c['address'])),
        ]),
      ),
    ),
    pw.SizedBox(width: 10),
    pw.Expanded(
      flex: 4,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: lineGrey, width: 0.8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          kv('Pro. Inv. No', _s(d['proNo']).isEmpty ? no : _s(d['proNo'])),
          kv('Date', dmy(_s(d['date']))),
          kv('PAN', _s(c['pan']).toUpperCase()),
          kv('KYC', _s(c['kyc'])),
        ]),
      ),
    ),
  ]);

  final shown = lines.where((l) => l.isEx || l.amount != 0).toList();
  final priceTable = pw.Column(children: [
    for (var i = 0; i < shown.length; i++)
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
        decoration: pw.BoxDecoration(
          color: shown[i].isEx ? cream : null,
          border: pw.Border(bottom: pw.BorderSide(color: lineGrey, width: 0.6)),
        ),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(shown[i].label, style: st(9.5, b: shown[i].isEx))),
          pw.Text(shown[i].amount == 0 ? '-' : '${shown[i].minus ? '- ' : ''}Rs. ${inr(shown[i].amount, symbol: false)}',
              style: st(10, b: shown[i].isEx, col: shown[i].minus ? PdfColor.fromInt(0xFF2E7D32) : black)),
        ]),
      ),
  ]);

  final grand = pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    color: black,
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Container(width: 4, height: 26, color: gold),
      pw.SizedBox(width: 10),
      pw.Expanded(child: pw.Text('GRAND TOTAL', style: st(13, b: true, col: gold, ls: 2))),
      pw.Text('Rs. ${inr(total, symbol: false)}', style: st(22, b: true, col: PdfColors.white)),
    ]),
  );

  final termsW = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    for (var i = 0; i < terms.length; i++)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text('${i + 1}.  ${_s(terms[i]['t'])}',
            style: st(8, col: terms[i]['r'] == true ? PdfColor.fromInt(0xFFB71C1C) : PdfColors.grey800,
                b: terms[i]['r'] == true)),
      ),
  ]);

  final bankContact = pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: cream, border: pw.Border.all(color: gold, width: 0.7)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('BANK DETAILS', style: st(8, b: true, col: gold, ls: 1.5)),
          pw.SizedBox(height: 5),
          kv('A/c Name', _s(co['accName'])),
          kv('A/c No.', _s(co['accNo'])),
          kv('IFSC', _s(co['ifsc'])),
        ]),
      ),
    ),
    pw.SizedBox(width: 10),
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: lineGrey, width: 0.8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('FOR CONTACT', style: st(8, b: true, col: gold, ls: 1.5)),
          pw.SizedBox(height: 5),
          kv('Person', _s(co['contactPerson'])),
          kv('Mobile', _s(co['contactNo'])),
          kv('E-mail', _s(co['email'])),
        ]),
      ),
    ),
  ]);

  final signature = pw.Padding(
    padding: const pw.EdgeInsets.only(top: 26),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Column(children: [
        pw.Container(width: 150, height: 0.8, color: black),
        pw.SizedBox(height: 3),
        pw.Text('Authorized Signatory', style: st(8.5, b: true)),
        pw.Text('For ${_s(co['name'])}', style: st(7.5, col: PdfColors.grey600)),
      ]),
    ]),
  );

  pw.Widget pad(pw.Widget w) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28), child: w);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    footer: (ctx) => pw.Container(
      width: double.infinity,
      color: black,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      alignment: pw.Alignment.center,
      child: pw.Text('${_s(co['email'])}   |   ${_s(co['contactNo'])}   |   ${_s(co['name'])}',
          style: st(7.5, col: gold, ls: 0.5)),
    ),
    build: (ctx) => [
      band,
      goldLine,
      pad(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(height: 14),
        vehicleCard,
        sectionTitle('CUSTOMER DETAILS'),
        customer,
        sectionTitle('PRICE BREAKDOWN'),
        priceTable,
        grand,
        sectionTitle('TERMS & CONDITIONS'),
        termsW,
        sectionTitle('BANK & CONTACT'),
        bankContact,
        signature,
        pw.SizedBox(height: 16),
      ])),
    ],
  ));
}
