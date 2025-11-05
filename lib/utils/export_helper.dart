import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ExportHelper {
  // Crea un archivo temporal y lo comparte usando el panel nativo de Android.
  // El usuario puede elegir "Guardar en Archivos" o cualquier otra app para guardar.
  static Future<String?> _saveWithPicker({
    required BuildContext context,
    required Uint8List data,
    required String fileName,
    required List<String> extensions,
    String? label,
    String? mimeType,
  }) async {
    try {
      // Determinar el tipo MIME correcto
      final mime =
          mimeType ??
          (extensions.isNotEmpty && extensions.first == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

      // Crear archivo temporal
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(data);

      // Compartir archivo - Android mostrará opciones incluyendo "Guardar en..."
      final result = await Share.shareXFiles([
        XFile(filePath, name: fileName, mimeType: mime),
      ], subject: 'Guardar $fileName');

      if (context.mounted) {
        if (result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '✓ Usa "Archivos" o "Drive" del panel para guardar donde quieras',
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.blue[700],
            ),
          );
        } else if (result.status == ShareResultStatus.dismissed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardado cancelado'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      return filePath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al preparar archivo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }

  // Exportar Balance General a PDF
  static Future<void> exportBalanceGeneralPDF({
    required BuildContext context,
    required Map<String, List<Map<String, dynamic>>> cuentasPorTipo,
    required double totalActivo,
    required double totalPasivo,
    required double totalPatrimonio,
    required DateTime? fechaCorte,
    bool share = false,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs.',
      decimalDigits: 2,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BALANCE GENERAL',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Fecha de corte: ${fechaCorte != null ? dateFormat.format(fechaCorte) : "Hoy"}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            // ACTIVOS
            pw.Header(
              level: 1,
              child: pw.Text(
                'ACTIVOS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            pw.Table.fromTextArray(
              headers: ['Código', 'Nombre', 'Saldo'],
              data: cuentasPorTipo['Activo']!.map((cuenta) {
                return [
                  cuenta['codigo'] ?? '',
                  cuenta['nombre'] ?? '',
                  currencyFormat.format(cuenta['saldo'] ?? 0),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total Activo: ${currencyFormat.format(totalActivo)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            // PASIVOS
            pw.Header(
              level: 1,
              child: pw.Text(
                'PASIVOS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            pw.Table.fromTextArray(
              headers: ['Código', 'Nombre', 'Saldo'],
              data: cuentasPorTipo['Pasivo']!.map((cuenta) {
                return [
                  cuenta['codigo'] ?? '',
                  cuenta['nombre'] ?? '',
                  currencyFormat.format(cuenta['saldo'] ?? 0),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total Pasivo: ${currencyFormat.format(totalPasivo)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            // PATRIMONIO
            pw.Header(
              level: 1,
              child: pw.Text(
                'PATRIMONIO',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            pw.Table.fromTextArray(
              headers: ['Código', 'Nombre', 'Saldo'],
              data: cuentasPorTipo['Patrimonio']!.map((cuenta) {
                return [
                  cuenta['codigo'] ?? '',
                  cuenta['nombre'] ?? '',
                  currencyFormat.format(cuenta['saldo'] ?? 0),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total Patrimonio: ${currencyFormat.format(totalPatrimonio)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              child: pw.Text(
                'Total Pasivo + Patrimonio: ${currencyFormat.format(totalPasivo + totalPatrimonio)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final name =
        'Balance_General_'
        '${fechaCorte != null ? DateFormat('yyyy-MM-dd').format(fechaCorte) : DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}'
        '.pdf';
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/pdf',
          name: name,
        ),
      ]);
      return;
    }
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['pdf'],
      label: 'PDF',
      mimeType: 'application/pdf',
    );
  }

  // Exportar Balance General a Excel
  static Future<void> exportBalanceGeneralExcel({
    required BuildContext context,
    required Map<String, List<Map<String, dynamic>>> cuentasPorTipo,
    required double totalActivo,
    required double totalPasivo,
    required double totalPatrimonio,
    required DateTime? fechaCorte,
    bool share = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Balance General'];
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    // Título
    sheet.appendRow([TextCellValue('BALANCE GENERAL')]);
    sheet.appendRow([
      TextCellValue(
        'Fecha de corte: ${fechaCorte != null ? dateFormat.format(fechaCorte) : "Hoy"}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // ACTIVOS
    sheet.appendRow([TextCellValue('ACTIVOS')]);
    sheet.appendRow([
      TextCellValue('Código'),
      TextCellValue('Nombre'),
      TextCellValue('Saldo'),
    ]);
    for (var cuenta in cuentasPorTipo['Activo']!) {
      sheet.appendRow([
        TextCellValue(cuenta['codigo'] ?? ''),
        TextCellValue(cuenta['nombre'] ?? ''),
        DoubleCellValue(cuenta['saldo'] ?? 0),
      ]);
    }
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Total Activo:'),
      DoubleCellValue(totalActivo),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // PASIVOS
    sheet.appendRow([TextCellValue('PASIVOS')]);
    sheet.appendRow([
      TextCellValue('Código'),
      TextCellValue('Nombre'),
      TextCellValue('Saldo'),
    ]);
    for (var cuenta in cuentasPorTipo['Pasivo']!) {
      sheet.appendRow([
        TextCellValue(cuenta['codigo'] ?? ''),
        TextCellValue(cuenta['nombre'] ?? ''),
        DoubleCellValue(cuenta['saldo'] ?? 0),
      ]);
    }
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Total Pasivo:'),
      DoubleCellValue(totalPasivo),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // PATRIMONIO
    sheet.appendRow([TextCellValue('PATRIMONIO')]);
    sheet.appendRow([
      TextCellValue('Código'),
      TextCellValue('Nombre'),
      TextCellValue('Saldo'),
    ]);
    for (var cuenta in cuentasPorTipo['Patrimonio']!) {
      sheet.appendRow([
        TextCellValue(cuenta['codigo'] ?? ''),
        TextCellValue(cuenta['nombre'] ?? ''),
        DoubleCellValue(cuenta['saldo'] ?? 0),
      ]);
    }
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Total Patrimonio:'),
      DoubleCellValue(totalPatrimonio),
    ]);

    final name =
        'Balance_General_${fechaCorte != null ? DateFormat('yyyy-MM-dd').format(fechaCorte) : DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
    final bytes = excel.encode()!;
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: name,
        ),
      ]);
      return;
    }
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['xlsx'],
      label: 'Excel',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // Exportar Estado de Resultados a PDF
  static Future<void> exportEstadoResultadosPDF({
    required BuildContext context,
    required List<Map<String, dynamic>> ingresos,
    required List<Map<String, dynamic>> costos,
    required List<Map<String, dynamic>> gastos,
    required double totalIngresos,
    required double totalCostos,
    required double totalGastos,
    required double utilidadBruta,
    required double utilidadOperativa,
    required double utilidadNeta,
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    bool share = false,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs.',
      decimalDigits: 2,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ESTADO DE RESULTADOS',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Período: ${fechaInicio != null ? dateFormat.format(fechaInicio) : ""} - ${fechaFin != null ? dateFormat.format(fechaFin) : ""}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            // INGRESOS
            pw.Header(
              level: 1,
              child: pw.Text(
                'INGRESOS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            if (ingresos.isNotEmpty)
              pw.Table.fromTextArray(
                headers: ['Código', 'Nombre', 'Saldo'],
                data: ingresos.map((cuenta) {
                  return [
                    cuenta['codigo'] ?? '',
                    cuenta['nombre'] ?? '',
                    currencyFormat.format(cuenta['saldo'] ?? 0),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total Ingresos: ${currencyFormat.format(totalIngresos)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            // COSTOS
            pw.Header(
              level: 1,
              child: pw.Text(
                'COSTOS DE VENTAS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            if (costos.isNotEmpty)
              pw.Table.fromTextArray(
                headers: ['Código', 'Nombre', 'Saldo'],
                data: costos.map((cuenta) {
                  return [
                    cuenta['codigo'] ?? '',
                    cuenta['nombre'] ?? '',
                    currencyFormat.format(cuenta['saldo'] ?? 0),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total Costos: ${currencyFormat.format(totalCostos)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              child: pw.Text(
                'Utilidad Bruta: ${currencyFormat.format(utilidadBruta)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            // GASTOS
            pw.Header(
              level: 1,
              child: pw.Text(
                'GASTOS OPERATIVOS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            if (gastos.isNotEmpty)
              pw.Table.fromTextArray(
                headers: ['Código', 'Nombre', 'Saldo'],
                data: gastos.map((cuenta) {
                  return [
                    cuenta['codigo'] ?? '',
                    cuenta['nombre'] ?? '',
                    currencyFormat.format(cuenta['saldo'] ?? 0),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total Gastos: ${currencyFormat.format(totalGastos)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              child: pw.Text(
                'Utilidad Operativa: ${currencyFormat.format(utilidadOperativa)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.blue700, PdfColors.blue800],
                ),
              ),
              child: pw.Text(
                'UTILIDAD NETA: ${currencyFormat.format(utilidadNeta)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final name =
        'Estado_Resultados_'
        '${fechaInicio != null ? DateFormat('yyyy-MM-dd').format(fechaInicio) : 'inicio'}'
        '_a_'
        '${fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin) : 'fin'}'
        '.pdf';
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/pdf',
          name: name,
        ),
      ]);
      return;
    }
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['pdf'],
      label: 'PDF',
      mimeType: 'application/pdf',
    );
  }

  // Exportar Estado de Resultados a Excel
  static Future<void> exportEstadoResultadosExcel({
    required BuildContext context,
    required List<Map<String, dynamic>> ingresos,
    required List<Map<String, dynamic>> costos,
    required List<Map<String, dynamic>> gastos,
    required double totalIngresos,
    required double totalCostos,
    required double totalGastos,
    required double utilidadBruta,
    required double utilidadOperativa,
    required double utilidadNeta,
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    bool share = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Estado de Resultados'];
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    // Título
    sheet.appendRow([TextCellValue('ESTADO DE RESULTADOS')]);
    sheet.appendRow([
      TextCellValue(
        'Período: ${fechaInicio != null ? dateFormat.format(fechaInicio) : ""} - ${fechaFin != null ? dateFormat.format(fechaFin) : ""}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // INGRESOS
    sheet.appendRow([TextCellValue('INGRESOS')]);
    sheet.appendRow([
      TextCellValue('Código'),
      TextCellValue('Nombre'),
      TextCellValue('Saldo'),
    ]);
    for (var cuenta in ingresos) {
      sheet.appendRow([
        TextCellValue(cuenta['codigo'] ?? ''),
        TextCellValue(cuenta['nombre'] ?? ''),
        DoubleCellValue(cuenta['saldo'] ?? 0),
      ]);
    }
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Total Ingresos:'),
      DoubleCellValue(totalIngresos),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // COSTOS
    sheet.appendRow([TextCellValue('COSTOS DE VENTAS')]);
    sheet.appendRow([
      TextCellValue('Código'),
      TextCellValue('Nombre'),
      TextCellValue('Saldo'),
    ]);
    for (var cuenta in costos) {
      sheet.appendRow([
        TextCellValue(cuenta['codigo'] ?? ''),
        TextCellValue(cuenta['nombre'] ?? ''),
        DoubleCellValue(cuenta['saldo'] ?? 0),
      ]);
    }
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Total Costos:'),
      DoubleCellValue(totalCostos),
    ]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Utilidad Bruta:'),
      DoubleCellValue(utilidadBruta),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // GASTOS
    sheet.appendRow([TextCellValue('GASTOS OPERATIVOS')]);
    sheet.appendRow([
      TextCellValue('Código'),
      TextCellValue('Nombre'),
      TextCellValue('Saldo'),
    ]);
    for (var cuenta in gastos) {
      sheet.appendRow([
        TextCellValue(cuenta['codigo'] ?? ''),
        TextCellValue(cuenta['nombre'] ?? ''),
        DoubleCellValue(cuenta['saldo'] ?? 0),
      ]);
    }
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Total Gastos:'),
      DoubleCellValue(totalGastos),
    ]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Utilidad Operativa:'),
      DoubleCellValue(utilidadOperativa),
    ]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('UTILIDAD NETA:'),
      DoubleCellValue(utilidadNeta),
    ]);

    final name =
        'Estado_Resultados_'
        '${fechaInicio != null ? DateFormat('yyyy-MM-dd').format(fechaInicio) : 'inicio'}'
        '_a_'
        '${fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin) : 'fin'}'
        '.xlsx';
    final bytes = excel.encode()!;
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: name,
        ),
      ]);
      return;
    }
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['xlsx'],
      label: 'Excel',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // Exportar Libro Diario a PDF
  static Future<void> exportLibroDiarioPDF({
    required BuildContext context,
    required List<Map<String, dynamic>> asientos,
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    bool share = false,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs.',
      decimalDigits: 2,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LIBRO DIARIO',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Período: '
                    '${fechaInicio != null ? dateFormat.format(fechaInicio) : ""}'
                    ' - '
                    '${fechaFin != null ? dateFormat.format(fechaFin) : ""}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            ...List.generate(asientos.length, (index) {
              final asiento = asientos[index];
              final fechaStr = asiento['fecha'] != null
                  ? dateFormat.format(DateTime.parse(asiento['fecha']))
                  : '';
              final desc = asiento['descripcion']?.toString() ?? '';
              final movimientos = List<Map<String, dynamic>>.from(
                asiento['movimientos'] ?? [],
              );

              double totalDebe = 0;
              double totalHaber = 0;
              for (var mov in movimientos) {
                totalDebe += (mov['debe'] ?? 0).toDouble();
                totalHaber += (mov['haber'] ?? 0).toDouble();
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Asiento ${index + 1} - $fechaStr',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  if (desc.isNotEmpty)
                    pw.Text(desc, style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 6),
                  if (movimientos.isNotEmpty)
                    pw.Table.fromTextArray(
                      headers: const ['Cuenta', 'Debe', 'Haber'],
                      data: movimientos.map((mov) {
                        return [
                          mov['cuenta']?['nombre'] ?? 'Sin cuenta',
                          currencyFormat.format((mov['debe'] ?? 0).toDouble()),
                          currencyFormat.format((mov['haber'] ?? 0).toDouble()),
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      cellAlignment: pw.Alignment.centerLeft,
                    ),
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Totales:  ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(currencyFormat.format(totalDebe)),
                        pw.SizedBox(width: 24),
                        pw.Text(currencyFormat.format(totalHaber)),
                      ],
                    ),
                  ),
                  pw.Divider(),
                ],
              );
            }),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final name =
        'Libro_Diario_'
        '${fechaInicio != null ? DateFormat('yyyy-MM-dd').format(fechaInicio) : 'inicio'}'
        '_a_'
        '${fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin) : 'fin'}'
        '.pdf';
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/pdf',
          name: name,
        ),
      ]);
      return;
    }
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['pdf'],
      label: 'PDF',
      mimeType: 'application/pdf',
    );
  }

  // Exportar Libro Diario a Excel
  static Future<void> exportLibroDiarioExcel({
    required BuildContext context,
    required List<Map<String, dynamic>> asientos,
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    bool share = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Libro Diario'];
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    // Encabezado
    sheet.appendRow([TextCellValue('LIBRO DIARIO')]);
    sheet.appendRow([
      TextCellValue(
        'Período: '
        '${fechaInicio != null ? dateFormat.format(fechaInicio) : ""}'
        ' - '
        '${fechaFin != null ? dateFormat.format(fechaFin) : ""}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    for (var i = 0; i < asientos.length; i++) {
      final asiento = asientos[i];
      final fechaStr = asiento['fecha'] != null
          ? dateFormat.format(DateTime.parse(asiento['fecha']))
          : '';
      final desc = asiento['descripcion']?.toString() ?? '';
      final movimientos = List<Map<String, dynamic>>.from(
        asiento['movimientos'] ?? [],
      );

      double totalDebe = 0;
      double totalHaber = 0;
      for (var mov in movimientos) {
        totalDebe += (mov['debe'] ?? 0).toDouble();
        totalHaber += (mov['haber'] ?? 0).toDouble();
      }

      // Título del asiento
      sheet.appendRow([TextCellValue('Asiento ${i + 1} - $fechaStr')]);
      if (desc.isNotEmpty) {
        sheet.appendRow([TextCellValue(desc)]);
      }
      sheet.appendRow([TextCellValue('')]);

      // Cabecera
      sheet.appendRow([
        TextCellValue('Cuenta'),
        TextCellValue('Debe'),
        TextCellValue('Haber'),
      ]);

      for (var mov in movimientos) {
        sheet.appendRow([
          TextCellValue(mov['cuenta']?['nombre'] ?? 'Sin cuenta'),
          DoubleCellValue((mov['debe'] ?? 0).toDouble()),
          DoubleCellValue((mov['haber'] ?? 0).toDouble()),
        ]);
      }

      // Totales
      sheet.appendRow([
        TextCellValue('Totales'),
        DoubleCellValue(totalDebe),
        DoubleCellValue(totalHaber),
      ]);
      sheet.appendRow([TextCellValue('')]);
    }

    final name =
        'Libro_Diario_'
        '${fechaInicio != null ? DateFormat('yyyy-MM-dd').format(fechaInicio) : 'inicio'}'
        '_a_'
        '${fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin) : 'fin'}'
        '.xlsx';
    final bytes = excel.encode()!;
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: name,
        ),
      ]);
      return;
    }
    // Usar el picker/compartir uniforme para que el usuario pueda elegir dónde guardar
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['xlsx'],
      label: 'Excel',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // Exportar Libro Mayor a PDF
  static Future<void> exportLibroMayorPDF({
    required BuildContext context,
    required List<Map<String, dynamic>> cuentas,
    required Map<String, List<Map<String, dynamic>>> movimientosPorCuenta,
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    required String? cuentaSeleccionadaId,
    bool share = false,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs.',
      decimalDigits: 2,
    );

    // Filtrar cuentas si corresponde
    final cuentasFiltradas = cuentaSeleccionadaId == null
        ? cuentas
        : cuentas
              .where((c) => c['id'].toString() == cuentaSeleccionadaId)
              .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LIBRO MAYOR',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Período: '
                    '${fechaInicio != null ? dateFormat.format(fechaInicio) : ""}'
                    ' - '
                    '${fechaFin != null ? dateFormat.format(fechaFin) : ""}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            ...cuentasFiltradas.map((cuenta) {
              final cuentaId = cuenta['id'].toString();
              final movimientos = List<Map<String, dynamic>>.from(
                movimientosPorCuenta[cuentaId] ?? [],
              );

              movimientos.sort((a, b) {
                final fa = DateTime.parse(
                  a['asiento']?['fecha'] ?? DateTime.now().toString(),
                );
                final fb = DateTime.parse(
                  b['asiento']?['fecha'] ?? DateTime.now().toString(),
                );
                return fa.compareTo(fb);
              });

              double totalDebe = 0;
              double totalHaber = 0;
              for (var mov in movimientos) {
                final debe = (mov['debe'] ?? 0).toDouble();
                final haber = (mov['haber'] ?? 0).toDouble();
                totalDebe += debe;
                totalHaber += haber;
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${cuenta['codigo']} - ${cuenta['nombre']}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  if (movimientos.isNotEmpty)
                    pw.Table.fromTextArray(
                      headers: const [
                        'Fecha',
                        'Descripción',
                        'Debe',
                        'Haber',
                        'Saldo',
                      ],
                      data: movimientos.map((mov) {
                        final fecha = DateTime.parse(
                          mov['asiento']?['fecha'] ?? DateTime.now().toString(),
                        );
                        final debe = (mov['debe'] ?? 0).toDouble();
                        final haber = (mov['haber'] ?? 0).toDouble();
                        return [
                          dateFormat.format(fecha),
                          (mov['descripcion']?.toString().isNotEmpty == true)
                              ? mov['descripcion']
                              : (mov['asiento']?['descripcion'] ?? ''),
                          currencyFormat.format(debe),
                          currencyFormat.format(haber),
                          '', // se llena abajo con fila de totales/saldo final
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      cellAlignment: pw.Alignment.centerLeft,
                    ),
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Totales:  ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(currencyFormat.format(totalDebe)),
                        pw.SizedBox(width: 24),
                        pw.Text(currencyFormat.format(totalHaber)),
                        pw.SizedBox(width: 24),
                        pw.Text(
                          currencyFormat.format((totalDebe - totalHaber).abs()),
                        ),
                      ],
                    ),
                  ),
                  pw.Divider(),
                ],
              );
            }).toList(),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final periodo =
        '${fechaInicio != null ? DateFormat('yyyy-MM-dd').format(fechaInicio) : 'inicio'}'
        '_a_'
        '${fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin) : 'fin'}';
    final sufijoCuenta = cuentaSeleccionadaId == null
        ? 'Todas'
        : 'Cuenta_${cuentaSeleccionadaId}';
    final name = 'Libro_Mayor_${sufijoCuenta}_$periodo.pdf';
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/pdf',
          name: name,
        ),
      ]);
      return;
    }
    // Reemplazamos FileSaver por el picker uniforme (share panel) para permitir elegir ubicación
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['pdf'],
      label: 'PDF',
      mimeType: 'application/pdf',
    );
  }

  // Exportar Libro Mayor a Excel
  static Future<void> exportLibroMayorExcel({
    required BuildContext context,
    required List<Map<String, dynamic>> cuentas,
    required Map<String, List<Map<String, dynamic>>> movimientosPorCuenta,
    required DateTime? fechaInicio,
    required DateTime? fechaFin,
    required String? cuentaSeleccionadaId,
    bool share = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Libro Mayor'];
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    // Encabezado
    sheet.appendRow([TextCellValue('LIBRO MAYOR')]);
    sheet.appendRow([
      TextCellValue(
        'Período: '
        '${fechaInicio != null ? dateFormat.format(fechaInicio) : ""}'
        ' - '
        '${fechaFin != null ? dateFormat.format(fechaFin) : ""}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    final cuentasFiltradas = cuentaSeleccionadaId == null
        ? cuentas
        : cuentas
              .where((c) => c['id'].toString() == cuentaSeleccionadaId)
              .toList();

    for (var cuenta in cuentasFiltradas) {
      final cuentaId = cuenta['id'].toString();
      final movimientos = List<Map<String, dynamic>>.from(
        movimientosPorCuenta[cuentaId] ?? [],
      );

      movimientos.sort((a, b) {
        final fa = DateTime.parse(
          a['asiento']?['fecha'] ?? DateTime.now().toString(),
        );
        final fb = DateTime.parse(
          b['asiento']?['fecha'] ?? DateTime.now().toString(),
        );
        return fa.compareTo(fb);
      });

      double totalDebe = 0;
      double totalHaber = 0;
      double saldoAcum = 0;

      // Título de la cuenta
      sheet.appendRow([
        TextCellValue('${cuenta['codigo']} - ${cuenta['nombre']}'),
      ]);
      sheet.appendRow([TextCellValue('')]);

      // Cabecera
      sheet.appendRow([
        TextCellValue('Fecha'),
        TextCellValue('Descripción'),
        TextCellValue('Debe'),
        TextCellValue('Haber'),
        TextCellValue('Saldo'),
      ]);

      for (var mov in movimientos) {
        final fecha = DateTime.parse(
          mov['asiento']?['fecha'] ?? DateTime.now().toString(),
        );
        final debe = (mov['debe'] ?? 0).toDouble();
        final haber = (mov['haber'] ?? 0).toDouble();
        saldoAcum += debe - haber;
        totalDebe += debe;
        totalHaber += haber;
        sheet.appendRow([
          TextCellValue(dateFormat.format(fecha)),
          TextCellValue(
            (mov['descripcion']?.toString().isNotEmpty == true)
                ? mov['descripcion']
                : (mov['asiento']?['descripcion'] ?? ''),
          ),
          DoubleCellValue(debe),
          DoubleCellValue(haber),
          DoubleCellValue(saldoAcum.abs()),
        ]);
      }

      // Totales
      sheet.appendRow([
        TextCellValue('Totales'),
        TextCellValue(''),
        DoubleCellValue(totalDebe),
        DoubleCellValue(totalHaber),
        DoubleCellValue((totalDebe - totalHaber).abs()),
      ]);
      sheet.appendRow([TextCellValue('')]);
    }

    final periodo =
        '${fechaInicio != null ? DateFormat('yyyy-MM-dd').format(fechaInicio) : 'inicio'}'
        '_a_'
        '${fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin) : 'fin'}';
    final sufijoCuenta = cuentaSeleccionadaId == null
        ? 'Todas'
        : 'Cuenta_${cuentaSeleccionadaId}';
    final name = 'Libro_Mayor_${sufijoCuenta}_$periodo.xlsx';
    final bytes = excel.encode()!;
    if (share) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: name,
        ),
      ]);
      return;
    }
    await _saveWithPicker(
      context: context,
      data: Uint8List.fromList(bytes),
      fileName: name,
      extensions: const ['xlsx'],
      label: 'Excel',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
