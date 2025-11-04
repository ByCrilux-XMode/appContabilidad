import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';

class LibroMayor extends StatefulWidget {
  const LibroMayor({super.key});

  @override
  State<LibroMayor> createState() => _LibroMayorState();
}

class _LibroMayorState extends State<LibroMayor> {
  List<Map<String, dynamic>> _cuentas = [];
  Map<String, List<Map<String, dynamic>>> _movimientosPorCuenta = {};
  bool _cargando = true;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _cuentaSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final token = await Config().obtenerDato('access');

      // Cargar cuentas
      print('Cargando cuentas desde: ${Config.baseUrl}/cuenta');
      final responseCuentas = await http.get(
        Uri.parse('${Config.baseUrl}/cuenta'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Cuentas Status Code: ${responseCuentas.statusCode}');

      if (responseCuentas.statusCode == 200) {
        final dataCuentas = jsonDecode(responseCuentas.body);
        _cuentas = List<Map<String, dynamic>>.from(
          dataCuentas['results'] ?? [],
        );
        print('Cuentas cargadas: ${_cuentas.length}');
      } else {
        throw Exception(
          'Error ${responseCuentas.statusCode}: ${responseCuentas.body}',
        );
      }

      // Cargar movimientos
      String urlMovimientos = '${Config.baseUrl}/movimiento';
      if (_fechaInicio != null && _fechaFin != null) {
        final inicio = DateFormat('yyyy-MM-dd').format(_fechaInicio!);
        final fin = DateFormat('yyyy-MM-dd').format(_fechaFin!);
        urlMovimientos += '?fecha_inicio=$inicio&fecha_fin=$fin';
      }

      print('Cargando movimientos desde: $urlMovimientos');
      final responseMovimientos = await http.get(
        Uri.parse(urlMovimientos),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Movimientos Status Code: ${responseMovimientos.statusCode}');

      if (responseMovimientos.statusCode == 200) {
        final dataMovimientos = jsonDecode(responseMovimientos.body);
        final movimientos = List<Map<String, dynamic>>.from(
          dataMovimientos['results'] ?? [],
        );
        print('Movimientos cargados: ${movimientos.length}');

        // Agrupar movimientos por cuenta
        _movimientosPorCuenta.clear();
        for (var movimiento in movimientos) {
          final cuentaId = movimiento['cuenta']?['id']?.toString();
          if (cuentaId != null) {
            if (!_movimientosPorCuenta.containsKey(cuentaId)) {
              _movimientosPorCuenta[cuentaId] = [];
            }
            _movimientosPorCuenta[cuentaId]!.add(movimiento);
          }
        }
        print('Cuentas con movimientos: ${_movimientosPorCuenta.length}');
      } else {
        throw Exception(
          'Error ${responseMovimientos.statusCode}: ${responseMovimientos.body}',
        );
      }

      if (!mounted) return;
      setState(() => _cargando = false);
    } catch (e, stackTrace) {
      print('Error en Libro Mayor: $e');
      print('StackTrace: $stackTrace');
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
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
      _cargarDatos();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _cuentaSeleccionada = null;
    });
    _cargarDatos();
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
                  'Libro Mayor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: _seleccionarRangoFechas,
                tooltip: 'Filtrar por fechas',
              ),
              if (_fechaInicio != null || _cuentaSeleccionada != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _limpiarFiltros,
                  tooltip: 'Limpiar filtros',
                ),
            ],
          ),
        ),
        // Filtros
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              // Selector de cuenta
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Filtrar por cuenta',
                  prefixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _cuentaSeleccionada,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todas las cuentas'),
                  ),
                  ..._cuentas.map((cuenta) {
                    return DropdownMenuItem(
                      value: cuenta['id'].toString(),
                      child: Text(
                        '${cuenta['codigo']} - ${cuenta['nombre']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _cuentaSeleccionada = value;
                  });
                },
              ),
              // Rango de fechas
              if (_fechaInicio != null && _fechaFin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        'Desde: ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} hasta ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}',
                      ),
                      onPressed: _seleccionarRangoFechas,
                      backgroundColor: Colors.blue.shade50,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Lista de cuentas
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: _construirListaCuentas(),
                ),
        ),
      ],
    );
  }

  Widget _construirListaCuentas() {
    final cuentasFiltradas = _cuentaSeleccionada == null
        ? _cuentas
        : _cuentas
              .where((c) => c['id'].toString() == _cuentaSeleccionada)
              .toList();

    if (cuentasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay cuentas disponibles',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cuentasFiltradas.length,
      itemBuilder: (context, index) {
        final cuenta = cuentasFiltradas[index];
        final cuentaId = cuenta['id'].toString();
        final movimientos = _movimientosPorCuenta[cuentaId] ?? [];

        // Calcular saldos
        double totalDebe = 0;
        double totalHaber = 0;
        for (var mov in movimientos) {
          totalDebe += (mov['debe'] ?? 0).toDouble();
          totalHaber += (mov['haber'] ?? 0).toDouble();
        }
        final saldo = totalDebe - totalHaber;

        return _buildCuentaCard(
          cuenta,
          movimientos,
          totalDebe,
          totalHaber,
          saldo,
        );
      },
    );
  }

  Widget _buildCuentaCard(
    Map<String, dynamic> cuenta,
    List<Map<String, dynamic>> movimientos,
    double totalDebe,
    double totalHaber,
    double saldo,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade700,
          child: Text(
            cuenta['codigo']?.toString().substring(0, 1) ?? '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${cuenta['codigo']} - ${cuenta['nombre']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo: ${cuenta['tipo_cuenta'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Saldo: ',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Text(
                  NumberFormat.currency(
                    locale: 'es_BO',
                    symbol: 'Bs.',
                    decimalDigits: 2,
                  ).format(saldo.abs()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: saldo >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                Text(
                  saldo >= 0 ? ' (Deudor)' : ' (Acreedor)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (movimientos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay movimientos para esta cuenta',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            _buildMovimientosTable(movimientos, totalDebe, totalHaber, saldo),
        ],
      ),
    );
  }

  Widget _buildMovimientosTable(
    List<Map<String, dynamic>> movimientos,
    double totalDebe,
    double totalHaber,
    double saldo,
  ) {
    // Ordenar movimientos por fecha
    movimientos.sort((a, b) {
      final fechaA = DateTime.parse(
        a['asiento']?['fecha'] ?? DateTime.now().toIso8601String(),
      );
      final fechaB = DateTime.parse(
        b['asiento']?['fecha'] ?? DateTime.now().toIso8601String(),
      );
      return fechaA.compareTo(fechaB);
    });

    double saldoAcumulado = 0;

    return Container(
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
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Fecha',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Descripción',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Debe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Haber',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Saldo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Movimientos
          ...movimientos.map((mov) {
            final debe = (mov['debe'] ?? 0).toDouble();
            final haber = (mov['haber'] ?? 0).toDouble();
            saldoAcumulado += debe - haber;
            final fecha = DateTime.parse(
              mov['asiento']?['fecha'] ?? DateTime.now().toIso8601String(),
            );

            return Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('dd/MM/yy').format(fecha),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      mov['descripcion']?.toString().isNotEmpty == true
                          ? mov['descripcion']
                          : mov['asiento']?['descripcion'] ?? 'Sin descripción',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      debe > 0
                          ? NumberFormat.currency(
                              locale: 'es_BO',
                              symbol: '',
                              decimalDigits: 2,
                            ).format(debe)
                          : '-',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color: debe > 0 ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      haber > 0
                          ? NumberFormat.currency(
                              locale: 'es_BO',
                              symbol: '',
                              decimalDigits: 2,
                            ).format(haber)
                          : '-',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color: haber > 0 ? Colors.red.shade700 : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      NumberFormat.currency(
                        locale: 'es_BO',
                        symbol: '',
                        decimalDigits: 2,
                      ).format(saldoAcumulado.abs()),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: saldoAcumulado >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
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
                  flex: 5,
                  child: Text(
                    'TOTALES',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                      fontSize: 11,
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
                      fontSize: 11,
                      color: Colors.red.shade700,
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
                    ).format(saldo.abs()),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: saldo >= 0
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
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
