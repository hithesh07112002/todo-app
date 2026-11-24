import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/todo.dart';

class TodoReport {
  static Future<void> printReport(List<Todo> todos) async {
    final document = pw.Document();
    final counts = {
      for (final status in TodoStatus.values)
        status: todos.where((todo) => todo.status == status).length,
    };
    final maxCount = counts.values.fold<int>(0, (max, count) {
      return count > max ? count : max;
    });

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Collaborative Todo Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Generated ${DateTime.now().toLocal()}'),
          pw.SizedBox(height: 18),
          pw.Text(
            'Task status chart',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...TodoStatus.values.map((status) {
            final count = counts[status]!;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 85, child: pw.Text(status.label)),
                  pw.Expanded(
                    child: pw.Container(
                      height: 14,
                      alignment: pw.Alignment.centerLeft,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      child: pw.Container(
                        width: maxCount == 0 ? 0 : 280 * count / maxCount,
                        height: 14,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 32, child: pw.Text('$count')),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 22),
          pw.Text(
            'Tasks (${todos.length})',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (todos.isEmpty)
            pw.Text('No tasks.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Task',
                'Status',
                'Created by',
                'Updated by',
                'Updated',
              ],
              data: todos
                  .map(
                    (todo) => [
                      [
                        todo.title,
                        if (todo.description.isNotEmpty) todo.description,
                      ].join('\n'),
                      todo.status.label,
                      todo.createdBy,
                      todo.updatedBy,
                      todo.updatedAt.toLocal().toString(),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => document.save());
  }

  static PdfColor _statusColor(TodoStatus status) => switch (status) {
    TodoStatus.pending => PdfColors.orange,
    TodoStatus.inProgress => PdfColors.blue,
    TodoStatus.completed => PdfColors.green,
  };
}
