import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../db.dart';
import '../main.dart';
import '../pdf_gen.dart';
import '../util.dart';

class PdfScreen extends StatefulWidget {
  final int? quotationId;
  final String number;
  final int revision;
  final Map<String, dynamic> data;
  final String template;

  const PdfScreen({
    super.key,
    this.quotationId,
    required this.number,
    required this.revision,
    required this.data,
    required this.template,
  });

  /// From a row of the `quotations` table (latest version).
  factory PdfScreen.fromRow(Rec row) => PdfScreen(
        quotationId: row['id'] as int,
        number: row['number'] as String,
        revision: (row['revision'] as int?) ?? 0,
        data: jsonDecode(row['data'] as String) as Map<String, dynamic>,
        template: (row['template'] as String?) ?? 'A',
      );

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  late String _tpl = widget.template;

  String get _fileName {
    final name = ((widget.data['customer'] as Map?)?['name'] ?? '').toString().trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final r = widget.revision == 0 ? '' : '_R${widget.revision}';
    return '${widget.number}$r${name.isEmpty ? '' : '_$name'}.pdf';
  }

  Future<Uint8List> _bytes() => buildQuotationPdf(widget.data, widget.number, widget.revision, _tpl);

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _setTemplate(String t) async {
    setState(() => _tpl = t);
    if (widget.quotationId != null) await Db.setTemplate(widget.quotationId!, t);
  }

  Future<void> _save() async {
    try {
      final b = await _bytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save quotation PDF',
        fileName: _fileName,
        bytes: b,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (path != null) _snack('PDF saved');
    } catch (e) {
      _snack('Could not save PDF: $e');
    }
  }

  Future<void> _whatsapp() async {
    try {
      final b = await _bytes();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$_fileName');
      await f.writeAsBytes(b, flush: true);
      await Share.shareXFiles(
        [XFile(f.path, mimeType: 'application/pdf', name: _fileName)],
        text: kWaMessage,
        subject: 'Vehicle Quotation ${widget.number}',
      );
    } catch (e) {
      _snack('Could not share PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(revLabel(widget.number, widget.revision), style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(tooltip: 'Save PDF to phone', onPressed: _save, icon: const Icon(Icons.download)),
        ],
      ),
      body: PdfPreview(
        key: ValueKey(_tpl),
        build: (format) => _bytes(),
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: _fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
        maxPageWidth: 700,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: kBlack,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(backgroundColor: Colors.white, selectedBackgroundColor: kGold),
              segments: const [
                ButtonSegment(value: 'A', label: Text('A: Excel Design')),
                ButtonSegment(value: 'B', label: Text('B: Modern Premium')),
              ],
              selected: {_tpl},
              onSelectionChanged: (s) => _setTemplate(s.first),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.share),
                  label: const Text('SHARE PDF (WHATSAPP)'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kGold, side: const BorderSide(color: kGold)),
                onPressed: _save,
                icon: const Icon(Icons.save_alt),
                label: const Text('SAVE'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
