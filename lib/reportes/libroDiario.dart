import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarAsientos();
  }

  Future<void> _cargarAsientos() async {
    setState(() => _cargando = true);
    try {
      final token = await Config().obtenerDato('access');
      String url = '${Config.baseUrl}/asiento_contable/';

      // Agregar filtros de fecha si existen
      if (_fechaInicio != null && _fechaFin != null) {
        final inicio = DateFormat('yyyy-MM-dd').format(_fechaInicio!);
        final fin = DateFormat('yyyy-MM-dd').format(_fechaFin!);
        url += '?fecha_inicio=$inicio&fecha_fin=$fin';
      }

      print('Cargando asientos desde: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final asientos = List<Map<String, dynamic>>.from(data['results'] ?? []);
        print('Asientos cargados: ${asientos.length}');

        setState(() {
          _asientos = asientos;
          _cargando = false;
        });
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
      totalDebe += (mov['debe'] ?? 0).toDouble();
      totalHaber += (mov['haber'] ?? 0).toDouble();
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
                                ).format(mov['debe'] ?? 0),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: (mov['debe'] ?? 0) > 0
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
                                ).format(mov['haber'] ?? 0),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: (mov['haber'] ?? 0) > 0
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
}
