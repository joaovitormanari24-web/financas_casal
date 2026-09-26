import 'dart:convert';
import 'dart:html' as html;

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/category.dart';
import '../../models/enums.dart';
import '../../models/household.dart';
import '../../models/transaction.dart';
import 'currency_formatter.dart';

/// Baixa um relatório dos lançamentos informados no formato escolhido —
/// gerado inteiramente no navegador (sem round-trip ao servidor).
class ReportExport {
  ReportExport._();

  static void downloadCsv({
    required List<Transaction> transactions,
    required Map<String, Category> categoriesById,
    required Map<String, HouseholdMember> membersById,
    required String periodLabel,
  }) {
    final rows = <List<String>>[
      ['Data', 'Descrição', 'Categoria', 'Tipo', 'Forma de pagamento', 'Pago por', 'Valor'],
      ...transactions.map((t) => [
            DateFormat('dd/MM/yyyy').format(t.date),
            t.description,
            categoriesById[t.categoryId]?.name ?? 'Sem categoria',
            _typeLabel(t.type.dbValue),
            t.paymentMethod.label,
            membersById[t.paidByMemberId]?.displayName ?? '',
            t.amount.toStringAsFixed(2).replaceAll('.', ','),
          ]),
    ];
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    // BOM pro Excel abrir acentuação em UTF-8 corretamente.
    final bytes = utf8.encode('﻿$csv');
    _download(bytes, 'lancamentos_$periodLabel.csv', 'text/csv;charset=utf-8');
  }

  static Future<void> downloadPdf({
    required List<Transaction> transactions,
    required Map<String, Category> categoriesById,
    required Map<String, HouseholdMember> membersById,
    required String periodLabel,
    required String periodTitle,
    required double income,
    required double expense,
  }) async {
    final doc = pw.Document();
    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Finanças do Casal',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(periodTitle, style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox('Receitas', income, PdfColors.green800),
              _summaryBox('Despesas', expense, PdfColors.red800),
              _summaryBox('Saldo', income - expense, PdfColors.blueGrey800),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(2.6),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Data', bold: true),
                  _cell('Descrição', bold: true),
                  _cell('Categoria', bold: true),
                  _cell('Pago por', bold: true),
                  _cell('Valor', bold: true, alignRight: true),
                ],
              ),
              ...sorted.map((t) {
                final isExpense = t.type.dbValue == 'expense';
                return pw.TableRow(
                  children: [
                    _cell(DateFormat('dd/MM/yy').format(t.date)),
                    _cell(t.description),
                    _cell(categoriesById[t.categoryId]?.name ?? 'Sem categoria'),
                    _cell(membersById[t.paidByMemberId]?.displayName ?? ''),
                    _cell(
                      '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(t.amount)}',
                      alignRight: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    _download(bytes, 'lancamentos_$periodLabel.pdf', 'application/pdf');
  }

  static pw.Widget _summaryBox(String label, double value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.Text(
          CurrencyFormatter.format(value),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static String _typeLabel(String dbValue) => switch (dbValue) {
        'income' => 'Receita',
        'transfer' => 'Transferência',
        _ => 'Despesa',
      };

  static void _download(List<int> bytes, String filename, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
