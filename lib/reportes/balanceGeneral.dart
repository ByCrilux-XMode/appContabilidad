import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';
import '../utils/export_helper.dart';

class BalanceGeneral extends StatefulWidget {
  const BalanceGeneral({super.key});

  @override
  State<BalanceGeneral> createState() => _BalanceGeneralState();
}

class _BalanceGeneralState extends State<BalanceGeneral> {
  bool _cargando = true;
  DateTime? _fechaCorte;

  Map<String, List<Map<String, dynamic>>> _cuentasPorTipo = {
    'Activo': [],
    'Pasivo': [],
    'Patrimonio': [],
  };

  double _totalActivo = 0;
  double _totalPasivo = 0;
  double _totalPatrimonio = 0;

  // Convierte dynamic (num o String) a double de forma segura
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '').trim();
      return double.tryParse(s) ?? 0.0;
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _fechaCorte = DateTime.now();
    _cargarBalance();
  }

  Future<void> _cargarBalance() async {
    setState(() => _cargando = true);

    try {
      final token = await Config().obtenerDato('access');

      // Usar el endpoint específico del backend: /balance_general/
      String urlBalanceGeneral = '${Config.baseUrl}/balance_general/';

      // Agregar parámetros de fecha
      if (_fechaCorte != null) {
        final fechaInicio = '2010-01-01';
        final fechaFin = DateFormat('yyyy-MM-dd').format(_fechaCorte!);
        urlBalanceGeneral += '?fecha_inicio=$fechaInicio&fecha_fin=$fechaFin';
      }

      print('🔍 Cargando Balance General desde: $urlBalanceGeneral');

      final response = await http.get(
        Uri.parse(urlBalanceGeneral),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📊 Balance General Status Code: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }

      // El backend devuelve lista de clases raíz con estructura anidada
      final data = jsonDecode(response.body);
      final clases = List<Map<String, dynamic>>.from(data);

      print('✅ Clases recibidas: ${clases.length}');

      // Separar por tipo y aplanar la estructura
      Map<String, List<Map<String, dynamic>>> cuentasPorTipo = {
        'Activo': [],
        'Pasivo': [],
        'Patrimonio': [],
      };

      double totalActivo = 0;
      double totalPasivo = 0;
      double totalPatrimonio = 0;

      // Función recursiva para aplanar hijos
      void agregarCuentasRecursivo(Map<String, dynamic> nodo, String tipo) {
        final codigo = nodo['codigo']?.toString() ?? '';
        final nombre = nodo['nombre']?.toString() ?? '';
        final saldo = _toDouble(nodo['saldo']);
        final totalDebe = _toDouble(nodo['total_debe']);
        final totalHaber = _toDouble(nodo['total_haber']);

        // Crear cuenta para la lista
        final cuenta = {
          'codigo': codigo,
          'nombre': nombre,
          'saldo': saldo,
          'total_debe': totalDebe,
          'total_haber': totalHaber,
        };

        cuentasPorTipo[tipo]!.add(cuenta);

        // Procesar hijos recursivamente
        final hijos = nodo['hijos'] as List<dynamic>?;
        if (hijos != null) {
          for (var hijo in hijos) {
            agregarCuentasRecursivo(hijo as Map<String, dynamic>, tipo);
          }
        }
      }

      for (var clase in clases) {
        final codigo = clase['codigo']?.toString() ?? '';
        final saldo = _toDouble(clase['saldo']);
        final saldoAbs = saldo.abs();

        // Log diagnóstico: saldo crudo y su magnitud
        print('Clase: $codigo, Saldo crudo: $saldo, Saldo abs: $saldoAbs');

        // Determinar tipo por código (1=Activo, 2=Pasivo, 3=Patrimonio)
        // Para el resumen queremos la magnitud positiva de cada grupo
        if (codigo.startsWith('1')) {
          totalActivo += saldoAbs;
          agregarCuentasRecursivo(clase, 'Activo');
        } else if (codigo.startsWith('2')) {
          totalPasivo += saldoAbs;
          agregarCuentasRecursivo(clase, 'Pasivo');
        } else if (codigo.startsWith('3')) {
          totalPatrimonio += saldoAbs;
          agregarCuentasRecursivo(clase, 'Patrimonio');
        }
      }

      // Actualizar estado
      _cuentasPorTipo = cuentasPorTipo;
      _totalActivo = totalActivo;
      _totalPasivo = totalPasivo;
      _totalPatrimonio = totalPatrimonio;

      print('✅ Total Activo: $_totalActivo');
      print('✅ Total Pasivo: $_totalPasivo');
      print('✅ Total Patrimonio: $_totalPatrimonio');

      if (!mounted) return;
      setState(() => _cargando = false);
    } catch (e, stackTrace) {
      print('Error en Balance General: $e');
      print('StackTrace: $stackTrace');
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar balance: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final fechaInicial = (_fechaCorte != null && _fechaCorte!.isAfter(ahora))
        ? ahora
        : (_fechaCorte ?? ahora);

    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2020),
      lastDate: ahora,
      helpText: 'Seleccionar fecha de corte',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (fecha != null) {
      setState(() {
        _fechaCorte = fecha;
      });
      _cargarBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPasivoPatrimonio = _totalPasivo + _totalPatrimonio;
    final diferencia = _totalActivo - totalPasivoPatrimonio;
    final balanceCuadra = diferencia.abs() < 0.01;

    return Column(
      children: [
        // Barra de herramientas
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Balance General',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.download),
                tooltip: 'Exportar',
                onSelected: (value) {
                  switch (value) {
                    case 'pdf':
                      _exportarPDF();
                      break;
                    case 'excel':
                      _exportarExcel();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 18),
                        SizedBox(width: 8),
                        Text('Guardar PDF'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        Icon(Icons.grid_on, size: 18),
                        SizedBox(width: 8),
                        Text('Guardar Excel'),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _seleccionarFecha,
                tooltip: 'Seleccionar fecha de corte',
              ),
            ],
          ),
        ),
        // Chip interactivo con la fecha de corte
        if (_fechaCorte != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  'Fecha de corte: ${DateFormat('dd/MM/yyyy').format(_fechaCorte!)}',
                ),
                onPressed: _seleccionarFecha,
                backgroundColor: Colors.blue.shade50,
              ),
            ),
          ),
        // Contenido
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargarBalance,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Activos
                      _buildSeccion(
                        'ACTIVOS',
                        _cuentasPorTipo['Activo']!,
                        _totalActivo,
                        Colors.green.shade700,
                      ),
                      const SizedBox(height: 16),
                      // Pasivos
                      _buildSeccion(
                        'PASIVOS',
                        _cuentasPorTipo['Pasivo']!,
                        _totalPasivo,
                        Colors.orange.shade700,
                      ),
                      const SizedBox(height: 16),
                      // Patrimonio
                      _buildSeccion(
                        'PATRIMONIO',
                        _cuentasPorTipo['Patrimonio']!,
                        _totalPatrimonio,
                        Colors.blue.shade700,
                      ),
                      const SizedBox(height: 16),
                      // Resumen
                      _buildResumen(
                        totalPasivoPatrimonio,
                        diferencia,
                        balanceCuadra,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSeccion(
    String titulo,
    List<Map<String, dynamic>> cuentas,
    double total,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: CircleAvatar(
          radius: 10,
          backgroundColor: color.withOpacity(0.9),
        ),
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
        trailing: Text(
          NumberFormat.currency(
            locale: 'es_BO',
            symbol: 'Bs.',
            decimalDigits: 2,
          ).format(total),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: color,
          ),
        ),
        initiallyExpanded: true,
        children: [
          if (cuentas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No hay cuentas con saldo',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            )
          else
            ...cuentas.map((cuenta) {
              final saldo = _toDouble(cuenta['saldo']);
              return ListTile(
                dense: true,
                title: Text(
                  cuenta['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Código: ${cuenta['codigo'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: Text(
                  NumberFormat.currency(
                    locale: 'es_BO',
                    symbol: 'Bs.',
                    decimalDigits: 2,
                  ).format(saldo.abs()),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TOTAL $titulo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  NumberFormat.currency(
                    locale: 'es_BO',
                    symbol: 'Bs.',
                    decimalDigits: 2,
                  ).format(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen(
    double totalPasivoPatrimonio,
    double diferencia,
    bool balanceCuadra,
  ) {
    return Card(
      elevation: 4,
      color: balanceCuadra ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  balanceCuadra ? Icons.check_circle : Icons.warning,
                  color: balanceCuadra
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    balanceCuadra ? 'Balance Cuadrado' : 'Balance Descuadrado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: balanceCuadra
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildLineaResumen(
              'Total Activos:',
              _totalActivo,
              Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            _buildLineaResumen(
              'Total Pasivos + Patrimonio:',
              totalPasivoPatrimonio,
              Colors.blue.shade700,
            ),
            if (!balanceCuadra) ...[
              const SizedBox(height: 8),
              _buildLineaResumen(
                'Diferencia:',
                diferencia,
                Colors.red.shade700,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Ecuación Contable: Activo = Pasivo + Patrimonio',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineaResumen(String label, double valor, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          NumberFormat.currency(
            locale: 'es_BO',
            symbol: 'Bs.',
            decimalDigits: 2,
          ).format(valor.abs()),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _exportarPDF() async {
    await ExportHelper.exportBalanceGeneralPDF(
      context: context,
      cuentasPorTipo: _cuentasPorTipo,
      totalActivo: _totalActivo,
      totalPasivo: _totalPasivo,
      totalPatrimonio: _totalPatrimonio,
      fechaCorte: _fechaCorte,
    );
  }

  Future<void> _exportarExcel() async {
    await ExportHelper.exportBalanceGeneralExcel(
      context: context,
      cuentasPorTipo: _cuentasPorTipo,
      totalActivo: _totalActivo,
      totalPasivo: _totalPasivo,
      totalPatrimonio: _totalPatrimonio,
      fechaCorte: _fechaCorte,
    );
  }
}
