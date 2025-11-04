import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';

class EstadoResultados extends StatefulWidget {
  const EstadoResultados({super.key});

  @override
  State<EstadoResultados> createState() => _EstadoResultadosState();
}

class _EstadoResultadosState extends State<EstadoResultados> {
  bool _cargando = true;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  List<Map<String, dynamic>> _ingresos = [];
  List<Map<String, dynamic>> _gastos = [];
  List<Map<String, dynamic>> _costos = [];

  double _totalIngresos = 0;
  double _totalGastos = 0;
  double _totalCostos = 0;
  double _utilidadBruta = 0;
  double _utilidadOperativa = 0;
  double _utilidadNeta = 0;

  @override
  void initState() {
    super.initState();
    // Por defecto, mostrar el mes actual hasta hoy
    final ahora = DateTime.now();
    _fechaInicio = DateTime(ahora.year, ahora.month, 1);
    // La fecha fin no puede ser mayor a hoy
    final finMes = DateTime(ahora.year, ahora.month + 1, 0);
    _fechaFin = finMes.isAfter(ahora) ? ahora : finMes;
    _cargarEstadoResultados();
  }

  Future<void> _cargarEstadoResultados() async {
    setState(() => _cargando = true);

    try {
      final token = await Config().obtenerDato('access');

      // Cargar todas las cuentas
      print('Cargando cuentas desde: ${Config.baseUrl}/cuenta');
      final responseCuentas = await http.get(
        Uri.parse('${Config.baseUrl}/cuenta'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Cuentas Status Code: ${responseCuentas.statusCode}');

      if (responseCuentas.statusCode != 200) {
        throw Exception(
          'Error ${responseCuentas.statusCode}: ${responseCuentas.body}',
        );
      }

      final dataCuentas = jsonDecode(responseCuentas.body);
      final cuentas = List<Map<String, dynamic>>.from(
        dataCuentas['results'] ?? [],
      );
      print('Cuentas cargadas: ${cuentas.length}');

      // Cargar movimientos del período
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

      if (responseMovimientos.statusCode != 200) {
        throw Exception(
          'Error ${responseMovimientos.statusCode}: ${responseMovimientos.body}',
        );
      }

      final dataMovimientos = jsonDecode(responseMovimientos.body);
      final movimientos = List<Map<String, dynamic>>.from(
        dataMovimientos['results'] ?? [],
      );
      print('Movimientos cargados: ${movimientos.length}');

      // Calcular saldos por cuenta
      Map<String, double> saldosPorCuenta = {};
      for (var movimiento in movimientos) {
        final cuentaId = movimiento['cuenta']?['id']?.toString();
        if (cuentaId != null) {
          if (!saldosPorCuenta.containsKey(cuentaId)) {
            saldosPorCuenta[cuentaId] = 0;
          }
          final debe = (movimiento['debe'] ?? 0).toDouble();
          final haber = (movimiento['haber'] ?? 0).toDouble();
          // Para cuentas de resultados, el saldo es la diferencia
          saldosPorCuenta[cuentaId] = saldosPorCuenta[cuentaId]! + debe - haber;
        }
      }

      // Clasificar cuentas
      _ingresos = [];
      _gastos = [];
      _costos = [];
      _totalIngresos = 0;
      _totalGastos = 0;
      _totalCostos = 0;

      for (var cuenta in cuentas) {
        final cuentaId = cuenta['id'].toString();
        final saldo = saldosPorCuenta[cuentaId] ?? 0;

        // Solo incluir cuentas con movimiento en el período
        if (saldo.abs() > 0.01) {
          final tipoCuenta =
              cuenta['tipo_cuenta']?.toString().toLowerCase() ?? '';
          final nombre = cuenta['nombre']?.toString().toLowerCase() ?? '';
          final cuentaConSaldo = {...cuenta, 'saldo': saldo.abs()};

          // Clasificar según tipo de cuenta
          if (tipoCuenta.contains('ingreso') ||
              nombre.contains('ingreso') ||
              nombre.contains('venta') ||
              tipoCuenta.contains('ingreso')) {
            _ingresos.add(cuentaConSaldo);
            // Los ingresos normalmente tienen saldo acreedor (negativo)
            _totalIngresos += saldo.abs();
          } else if (tipoCuenta.contains('gasto') || nombre.contains('gasto')) {
            _gastos.add(cuentaConSaldo);
            _totalGastos += saldo.abs();
          } else if (tipoCuenta.contains('costo') || nombre.contains('costo')) {
            _costos.add(cuentaConSaldo);
            _totalCostos += saldo.abs();
          }
        }
      }

      // Calcular utilidades
      _utilidadBruta = _totalIngresos - _totalCostos;
      _utilidadOperativa = _utilidadBruta - _totalGastos;
      _utilidadNeta =
          _utilidadOperativa; // Aquí se podrían agregar otros ajustes

      // Ordenar por código
      _ingresos.sort(
        (a, b) => (a['codigo'] ?? '').compareTo(b['codigo'] ?? ''),
      );
      _costos.sort((a, b) => (a['codigo'] ?? '').compareTo(b['codigo'] ?? ''));
      _gastos.sort((a, b) => (a['codigo'] ?? '').compareTo(b['codigo'] ?? ''));

      print(
        'Ingresos: ${_ingresos.length}, Costos: ${_costos.length}, Gastos: ${_gastos.length}',
      );
      print('Utilidad Neta: Bs. ${_utilidadNeta.toStringAsFixed(2)}');

      if (!mounted) return;
      setState(() => _cargando = false);
    } catch (e, stackTrace) {
      print('Error en Estado de Resultados: $e');
      print('StackTrace: $stackTrace');
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estado de resultados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _seleccionarRangoFechas() async {
    final ahora = DateTime.now();
    // Asegurar que las fechas iniciales no excedan la fecha actual
    final fechaInicioSegura =
        _fechaInicio ?? DateTime(ahora.year, ahora.month, 1);
    final fechaFinSegura = (_fechaFin != null && _fechaFin!.isAfter(ahora))
        ? ahora
        : (_fechaFin ?? ahora);

    final DateTimeRange? rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: ahora,
      initialDateRange: DateTimeRange(
        start: fechaInicioSegura,
        end: fechaFinSegura,
      ),
      helpText: 'Seleccionar período',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
      _cargarEstadoResultados();
    }
  }

  IconData _getIconForSection(String titulo) {
    if (titulo.contains('INGRESO')) {
      return Icons.trending_up;
    } else if (titulo.contains('COSTO')) {
      return Icons.shopping_cart;
    } else if (titulo.contains('GASTO')) {
      return Icons.money_off;
    }
    return Icons.attach_money;
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
                  'Estado de Resultados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: _seleccionarRangoFechas,
                tooltip: 'Seleccionar período',
              ),
            ],
          ),
        ),
        // Chip interactivo con el período
        if (_fechaInicio != null && _fechaFin != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(
                  'Del ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} al ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}',
                ),
                onPressed: _seleccionarRangoFechas,
                backgroundColor: Colors.blue.shade50,
              ),
            ),
          ),
        // Contenido
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargarEstadoResultados,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Ingresos
                      _buildSeccion(
                        'INGRESOS',
                        _ingresos,
                        _totalIngresos,
                        Colors.blue.shade700,
                        true,
                      ),
                      const SizedBox(height: 16),
                      // Costos
                      _buildSeccion(
                        'COSTOS DE VENTAS',
                        _costos,
                        _totalCostos,
                        Colors.blue.shade600,
                        false,
                      ),
                      const SizedBox(height: 8),
                      // Utilidad Bruta
                      _buildUtilidad(
                        'UTILIDAD BRUTA',
                        _utilidadBruta,
                        Colors.blue.shade700,
                      ),
                      const SizedBox(height: 16),
                      // Gastos
                      _buildSeccion(
                        'GASTOS OPERATIVOS',
                        _gastos,
                        _totalGastos,
                        Colors.blue.shade600,
                        false,
                      ),
                      const SizedBox(height: 8),
                      // Utilidad Operativa
                      _buildUtilidad(
                        'UTILIDAD OPERATIVA',
                        _utilidadOperativa,
                        Colors.blue.shade700,
                      ),
                      const SizedBox(height: 24),
                      // Utilidad Neta (Resultado Final)
                      _buildResultadoFinal(),
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
    bool esPositivo,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              children: [
                Icon(_getIconForSection(titulo), color: color, size: 22),
                const SizedBox(width: 10),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Lista de cuentas
          if (cuentas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay movimientos en este período',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...cuentas.map((cuenta) {
              final saldo = (cuenta['saldo'] ?? 0).toDouble();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cuenta['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Cód: ${cuenta['codigo'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'es_BO',
                        symbol: 'Bs.',
                        decimalDigits: 2,
                      ).format(saldo),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          // Total
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TOTAL $titulo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${esPositivo ? '' : '('}${NumberFormat.currency(locale: 'es_BO', symbol: 'Bs.', decimalDigits: 2).format(total)}${esPositivo ? '' : ')'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: color,
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

  Widget _buildUtilidad(String titulo, double monto, Color color) {
    final esPositivo = monto >= 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                esPositivo ? Icons.trending_up : Icons.trending_down,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Text(
              NumberFormat.currency(
                locale: 'es_BO',
                symbol: 'Bs.',
                decimalDigits: 2,
              ).format(monto.abs()),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadoFinal() {
    final esUtilidad = _utilidadNeta >= 0;
    final porcentajeMargen = _totalIngresos > 0
        ? (_utilidadNeta / _totalIngresos * 100)
        : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    esUtilidad
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esUtilidad ? 'UTILIDAD NETA' : 'PÉRDIDA NETA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.percent, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            'Margen: ${porcentajeMargen.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: Colors.white30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RESULTADO DEL PERÍODO:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  NumberFormat.currency(
                    locale: 'es_BO',
                    symbol: 'Bs.',
                    decimalDigits: 2,
                  ).format(_utilidadNeta.abs()),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
