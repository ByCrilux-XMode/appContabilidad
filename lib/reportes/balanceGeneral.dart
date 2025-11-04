import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';

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

      // Cargar movimientos hasta la fecha de corte
      String urlMovimientos = '${Config.baseUrl}/movimiento';
      if (_fechaCorte != null) {
        final fecha = DateFormat('yyyy-MM-dd').format(_fechaCorte!);
        urlMovimientos += '?fecha_hasta=$fecha';
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
          saldosPorCuenta[cuentaId] = saldosPorCuenta[cuentaId]! + debe - haber;
        }
      }

      // Clasificar cuentas y calcular totales
      _cuentasPorTipo = {'Activo': [], 'Pasivo': [], 'Patrimonio': []};
      _totalActivo = 0;
      _totalPasivo = 0;
      _totalPatrimonio = 0;

      for (var cuenta in cuentas) {
        final cuentaId = cuenta['id'].toString();
        final saldo = saldosPorCuenta[cuentaId] ?? 0;

        // Solo incluir cuentas con saldo diferente de cero
        if (saldo.abs() > 0.01) {
          final tipoCuenta =
              cuenta['tipo_cuenta']?.toString().toLowerCase() ?? '';
          final cuentaConSaldo = {...cuenta, 'saldo': saldo};

          if (tipoCuenta.contains('activo')) {
            _cuentasPorTipo['Activo']!.add(cuentaConSaldo);
            _totalActivo += saldo.abs();
          } else if (tipoCuenta.contains('pasivo')) {
            _cuentasPorTipo['Pasivo']!.add(cuentaConSaldo);
            _totalPasivo += saldo.abs();
          } else if (tipoCuenta.contains('patrimonio') ||
              tipoCuenta.contains('capital')) {
            _cuentasPorTipo['Patrimonio']!.add(cuentaConSaldo);
            _totalPatrimonio += saldo.abs();
          }
        }
      }

      // Ordenar cuentas por código
      for (var lista in _cuentasPorTipo.values) {
        lista.sort((a, b) {
          final codigoA = a['codigo']?.toString() ?? '';
          final codigoB = b['codigo']?.toString() ?? '';
          return codigoA.compareTo(codigoB);
        });
      }

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
              final saldo = (cuenta['saldo'] ?? 0).toDouble();
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
}
