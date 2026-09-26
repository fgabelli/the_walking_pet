import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/health_record_model.dart';

class HealthRecordPdfService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  /// Genera il documento PDF A4 del Libretto Sanitario
  static Future<Uint8List> generatePdf(
    DogModel dog,
    List<HealthRecordModel> records, {
    String? ownerName,
  }) async {
    final pdf = pw.Document();

    final vaccines = records.where((r) => r.type == HealthRecordType.vaccine).toList();
    final otherRecords = records.where((r) => r.type != HealthRecordType.vaccine).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ── HEADER ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DOGZN',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#FF6B4A'),
                      ),
                    ),
                    pw.Text(
                      'Libretto Sanitario Digitale',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Data esportazione: ${_dateFormat.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'ID Paziente: ${dog.id.substring(0, dog.id.length > 8 ? 8 : dog.id.length).toUpperCase()}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 12),

            // ── ANAGRAFICA CANE ──
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SCHEDA SEGNALETICA PAZIENTE',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#FF6B4A')),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Nome:', dog.name)),
                      pw.Expanded(child: _buildInfoItem('Specie / Razza:', '${dog.species.displayName} - ${dog.breed}')),
                      pw.Expanded(child: _buildInfoItem('Sesso:', dog.gender.displayName)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Età stimata:', '${dog.age} ${dog.age == 1 ? "anno" : "anni"}')),
                      pw.Expanded(child: _buildInfoItem('Microchip:', dog.microchipNumber?.isNotEmpty == true ? dog.microchipNumber! : 'Non registrato')),
                      pw.Expanded(child: _buildInfoItem('Sterilizzato:', dog.isSterilized ? 'Sì' : 'No')),
                    ],
                  ),
                  if (ownerName != null && ownerName.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildInfoItem('Proprietario:', ownerName)),
                        if (dog.weight != null)
                          pw.Expanded(child: _buildInfoItem('Peso:', '${dog.weight} kg'))
                        else
                          pw.Spacer(),
                        pw.Spacer(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── SEZIONE VACCINAZIONI ──
            pw.Text(
              'REGISTRO VACCINAZIONI',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.SizedBox(height: 8),

            if (vaccines.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text('Nessuna vaccinazione registrata nel libretto.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('Data'),
                      _buildTableHeader('Denominazione Vaccino'),
                      _buildTableHeader('Richiamo Previsto'),
                      _buildTableHeader('Stato'),
                      _buildTableHeader('Veterinario / Clinica'),
                    ],
                  ),
                  // Rows
                  ...vaccines.map((v) {
                    final statusText = v.isCompleted ? 'Eseguito' : 'Programmato';
                    final statusColor = v.isCompleted ? PdfColors.green800 : PdfColors.orange800;
                    final nextDue = v.nextDueDate != null ? _dateFormat.format(v.nextDueDate!) : '-';
                    final vet = v.veterinarianName?.isNotEmpty == true ? v.veterinarianName! : '-';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(_dateFormat.format(v.date)),
                        _buildTableCell(v.specificName?.isNotEmpty == true ? '${v.title}\n(${v.specificName})' : v.title, bold: true),
                        _buildTableCell(nextDue),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            statusText,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: statusColor),
                          ),
                        ),
                        _buildTableCell(vet),
                      ],
                    );
                  }),
                ],
              ),

            pw.SizedBox(height: 20),

            // ── SEZIONE TRATTAMENTI E VISITE ──
            if (otherRecords.isNotEmpty) ...[
              pw.Text(
                'TRATTAMENTI, VISITE E NOTE CLINICHE',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('Data'),
                      _buildTableHeader('Tipo'),
                      _buildTableHeader('Descrizione'),
                      _buildTableHeader('Note'),
                      _buildTableHeader('Veterinario'),
                    ],
                  ),
                  ...otherRecords.map((r) {
                    final vet = r.veterinarianName?.isNotEmpty == true ? r.veterinarianName! : '-';
                    final notes = r.notes?.isNotEmpty == true ? r.notes! : '-';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(_dateFormat.format(r.date)),
                        _buildTableCell(r.type.displayName),
                        _buildTableCell(r.title, bold: true),
                        _buildTableCell(notes),
                        _buildTableCell(vet),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // ── FOOTER / DISCLAIMER ──
            pw.Divider(color: PdfColors.grey300, thickness: 0.8),
            pw.SizedBox(height: 6),
            pw.Text(
              'Nota di validità: Questo riepilogo sanitario digitale è generato ad uso consultativo per il proprietario e il medico veterinario curante. Le date dei richiami raccomandati devono sempre essere confermate e validate dal veterinario abilitato.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Esporta e apre la finestra di condivisione di sistema
  static Future<void> exportAndShare(
    BuildContext context,
    DogModel dog,
    List<HealthRecordModel> records, {
    String? ownerName,
  }) async {
    try {
      final pdfBytes = await generatePdf(dog, records, ownerName: ownerName);
      final filename = 'libretto_${dog.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_dogzn.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore esportazione PDF: $e')),
        );
      }
    }
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }
}
