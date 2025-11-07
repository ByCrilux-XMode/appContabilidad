import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';
import '../utils/export_helper.dart';

class LibroDiario extends StatefulWidget {
  const LibroDiario({super.key});

  @override
  State<LibroDiario> createState() => _LibroDiarioState();
}

class _LibroDiarioState extends State<LibroDiario> {
  List<Map<String, dynamic>> _asientos = [];
  bool _cargando = true;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

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
    _cargarAsientos();
  }

  Future<void> _cargarAsientos() async {
    setState(() => _cargando = true);
    try {
      final token = await Config().obtenerDato('access');

      // Usar el endpoint específico del backend: /libro_diario/
      String url = '${Config.baseUrl}/libro_diario/';

      // Agregar filtros de fecha si existen
      if (_fechaInicio != null && _fechaFin != null) {
        final inicio = DateFormat('yyyy-MM-dd').format(_fechaInicio!);
        final fin = DateFormat('yyyy-MM-dd').format(_fechaFin!);
        url += '?fecha_inicio=$inicio&fecha_fin=$fin';
      }

      print('🔍 Cargando Libro Diario desde: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📊 Libro Diario Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // El backend devuelve: {"results": [...], "totales": {"debe_total": X, "haber_total": Y}}
        final results = data['results'] as List<dynamic>? ?? [];
        final totales = data['totales'] as Map<String, dynamic>? ?? {};

        print('✅ Movimientos recibidos: ${results.length}');
        print('✅ Totales: ${totales}');

        // Agrupar movimientos por asiento
        Map<String, List<Map<String, dynamic>>> movimientosPorAsiento = {};

        for (var movimiento in results) {
          final asientoId = movimiento['asiento']?['id']?.toString() ?? '';

          if (!movimientosPorAsiento.containsKey(asientoId)) {
            movimientosPorAsiento[asientoId] = [];
          }

          // Asegurar que el movimiento tenga la estructura correcta
          // El backend devuelve: {id, referencia, debe, haber, cuenta:{id,codigo,nombre}, asiento:{id,numero,fecha}}
          movimientosPorAsiento[asientoId]!.add({
            'id': movimiento['id'],
            'referencia': movimiento['referencia'],
            'debe': movimiento['debe'],
            'haber': movimiento['haber'],
            'cuenta': movimiento['cuenta'], // {id, codigo, nombre}
            'asiento': movimiento['asiento'], // {id, numero, fecha}
          });
        }

        // Crear estructura de asientos
        List<Map<String, dynamic>> asientos = [];

        for (var entry in movimientosPorAsiento.entries) {
          final movimientos = entry.value;
          if (movimientos.isNotEmpty) {
            final primerMovimiento = movimientos.first;
            final asientoInfo =
                primerMovimiento['asiento'] as Map<String, dynamic>? ?? {};

            asientos.add({
              'id': asientoInfo['id'],
              'numero': asientoInfo['numero'],
              'fecha': asientoInfo['fecha'],
              'descripcion': asientoInfo['descripcion'] ?? '',
              'movimientos': movimientos,
            });
          }
        }

        // Ordenar por fecha
        asientos.sort((a, b) {
          final fechaA = a['fecha']?.toString() ?? '';
          final fechaB = b['fecha']?.toString() ?? '';
          return fechaA.compareTo(fechaB);
        });

        setState(() {
          _asientos = asientos;
          _cargando = false;
        });

        print('✅ Asientos procesados: ${_asientos.length}');
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error al cargar asientos: $e');
      print('StackTrace: $stackTrace');
      setState(() {
        _cargando = false;
        _asientos = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar asientos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _seleccionarRangoFechas() async {
    final ahora = DateTime.now();
    DateTimeRange? rangoInicial;

    // Si ya hay fechas seleccionadas, úsalas como inicial
    if (_fechaInicio != null && _fechaFin != null) {
      final fechaFinSegura = _fechaFin!.isAfter(ahora) ? ahora : _fechaFin!;
      rangoInicial = DateTimeRange(start: _fechaInicio!, end: fechaFinSegura);
    }

    final DateTimeRange? rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: ahora,
      initialDateRange: rangoInicial,
      helpText: 'Seleccionar rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
      _cargarAsientos();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
    });
    _cargarAsientos();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Libro Diario',
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
                icon: const Icon(Icons.date_range),
                onPressed: _seleccionarRangoFechas,
                tooltip: 'Filtrar por fechas',
              ),
              if (_fechaInicio != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _limpiarFiltros,
                  tooltip: 'Limpiar filtros',
                ),
            ],
          ),
        ),
        // Mostrar filtros activos
        if (_fechaInicio != null && _fechaFin != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Desde: ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} hasta ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        // Contenido principal
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _asientos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay asientos registrados',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _asientos.length,
                  itemBuilder: (context, index) {
                    return _buildAsientoCard(_asientos[index], index + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAsientoCard(Map<String, dynamic> asiento, int numero) {
    final fecha = DateTime.parse(asiento['fecha']);
    final movimientos = List<Map<String, dynamic>>.from(
      asiento['movimientos'] ?? [],
    );

    double totalDebe = 0;
    double totalHaber = 0;
    for (var mov in movimientos) {
      totalDebe += _toDouble(mov['debe']);
      totalHaber += _toDouble(mov['haber']);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade700,
          child: Text(
            '$numero',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          asiento['descripcion'] ?? 'Sin descripción',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('dd/MM/yyyy', 'es_ES').format(fecha),
          style: TextStyle(color: Colors.grey.shade600),
        ),
        children: [
          // Tabla de movimientos
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Cuenta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Debe',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Haber',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                // Movimientos
                ...movimientos.map(
                  (mov) => Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mov['cuenta']?['nombre'] ?? 'Sin cuenta',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (mov['descripcion'] != null &&
                                      mov['descripcion'].toString().isNotEmpty)
                                    Text(
                                      mov['descripcion'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                NumberFormat.currency(
                                  locale: 'es_BO',
                                  symbol: 'Bs.',
                                  decimalDigits: 2,
                                ).format(_toDouble(mov['debe'])),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: _toDouble(mov['debe']) > 0
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                NumberFormat.currency(
                                  locale: 'es_BO',
                                  symbol: 'Bs.',
                                  decimalDigits: 2,
                                ).format(_toDouble(mov['haber'])),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: _toDouble(mov['haber']) > 0
                                      ? Colors.red.shade700
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Totales
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'TOTALES',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          NumberFormat.currency(
                            locale: 'es_BO',
                            symbol: 'Bs.',
                            decimalDigits: 2,
                          ).format(totalDebe),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          NumberFormat.currency(
                            locale: 'es_BO',
                            symbol: 'Bs.',
                            decimalDigits: 2,
                          ).format(totalHaber),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarPDF() async {
    await ExportHelper.exportLibroDiarioPDF(
      context: context,
      asientos: _asientos,
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
    );
  }

  Future<void> _exportarExcel() async {
    await ExportHelper.exportLibroDiarioExcel(
      context: context,
      asientos: _asientos,
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
    );
  }
}
