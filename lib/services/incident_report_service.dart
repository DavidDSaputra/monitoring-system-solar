import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/incident.dart';

class IncidentReportService {
  IncidentReportService._();

  static final _date = DateFormat('dd MMM yyyy HH:mm');

  static Future<void> sharePdf(List<Incident> incidents) async {
    final document = pw.Document(
      title: 'SolarView Incident Report',
      author: 'SolarView',
    );
    final open = incidents.where((item) => item.isOpen).length;
    final breached = incidents.where((item) => item.slaBreached).length;
    final totalDowntime = incidents.fold<int>(
      0,
      (sum, item) => sum + item.durationSeconds,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(
            'SolarView - Laporan Gangguan & SLA',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text('Dibuat: ${_date.format(DateTime.now())}'),
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 18,
            children: [
              pw.Text('Total: ${incidents.length}'),
              pw.Text('Aktif: $open'),
              pw.Text('SLA terlewati: $breached'),
              pw.Text('Total downtime: ${_duration(totalDowntime)}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Prioritas',
              'Provider',
              'Plant',
              'Perangkat',
              'Status',
              'Mulai',
              'Durasi',
              'SLA',
            ],
            data: incidents
                .map(
                  (item) => [
                    item.priority,
                    item.source.toUpperCase(),
                    item.plantName,
                    '${_entityLabel(item.entityType)} - ${item.entityName}',
                    item.isOpen ? 'Aktif' : 'Selesai',
                    _date.format(item.startedAt),
                    item.durationLabel,
                    item.slaBreached ? 'Terlambat' : 'Terpenuhi',
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF97316),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    final name =
        'solarview-incidents-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.pdf';
    await _share(bytes, name, 'application/pdf');
  }

  static Future<void> shareExcel(List<Incident> incidents) async {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Incidents');
    final sheet = workbook['Incidents'];
    sheet.appendRow([
      TextCellValue('Prioritas'),
      TextCellValue('Provider'),
      TextCellValue('Plant'),
      TextCellValue('Tipe Perangkat'),
      TextCellValue('Nama Perangkat'),
      TextCellValue('Status Gangguan'),
      TextCellValue('Mulai'),
      TextCellValue('Selesai'),
      TextCellValue('Durasi Menit'),
      TextCellValue('Target SLA Menit'),
      TextCellValue('SLA Terlewati'),
      TextCellValue('Alamat'),
    ]);
    for (final item in incidents) {
      sheet.appendRow([
        TextCellValue(item.priority),
        TextCellValue(item.source.toUpperCase()),
        TextCellValue(item.plantName),
        TextCellValue(_entityLabel(item.entityType)),
        TextCellValue(item.entityName),
        TextCellValue(item.status.toUpperCase()),
        TextCellValue(_date.format(item.startedAt)),
        TextCellValue(
          item.resolvedAt == null ? '' : _date.format(item.resolvedAt!),
        ),
        IntCellValue((item.durationSeconds / 60).ceil()),
        IntCellValue(item.slaMinutes),
        TextCellValue(item.slaBreached ? 'Ya' : 'Tidak'),
        TextCellValue(item.address),
      ]);
    }
    for (var column = 0; column < 12; column++) {
      sheet.setColumnWidth(column, column == 2 || column == 4 ? 28 : 18);
    }

    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel');
    final name =
        'solarview-incidents-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.xlsx';
    await _share(
      bytes,
      name,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<void> _share(
    List<int> bytes,
    String name,
    String mimeType,
  ) async {
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
      name: name,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [name],
        title: 'Laporan SolarView',
        text: 'Laporan gangguan, downtime, dan performa SLA SolarView.',
      ),
    );
  }

  static String _entityLabel(String value) {
    return switch (value) {
      'inverter' => 'Inverter',
      'battery' => 'Baterai',
      'datalogger' => 'Datalogger',
      _ => 'Plant',
    };
  }

  static String _duration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours} jam ${duration.inMinutes.remainder(60)} menit';
    }
    return '${duration.inMinutes} menit';
  }
}
