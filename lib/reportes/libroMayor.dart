import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';
import '../utils/export_helper.dart';

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
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final token = await Config().obtenerDato('access');

      // Usar el endpoint específico del backend: /libro_mayor/
      String urlLibroMayor = '${Config.baseUrl}/libro_mayor/';

      // Agregar filtros (nota: el backend acepta clase_id, no fecha)
      // Para filtrar por fechas, necesitarías verificar si el backend lo soporta
      // Por ahora, obtenemos todas las cuentas con movimientos

      print('🔍 Cargando Libro Mayor desde: $urlLibroMayor');

      // Intentar la petición con reintentos en caso de 5xx (server error)
      http.Response response;
      int attempts = 0;
      const maxAttempts = 3;
      while (true) {
        attempts += 1;
        response = await http.get(
          Uri.parse(urlLibroMayor),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        print(
          '📊 Libro Mayor Status Code (intento $attempts): ${response.statusCode}',
        );
        // Siempre imprimir cuerpo en debug (recortado si es muy largo)
        final bodyPreview = response.body.length > 1000
            ? response.body.substring(0, 1000) + '...(truncated)'
            : response.body;
        print('🔎 Response body preview: $bodyPreview');

        if (response.statusCode >= 500 && attempts < maxAttempts) {
          // Guardar body completo en archivo temporal para facilitar debugging remoto
          try {
            final tmp = await Directory.systemTemp.createTemp(
              'libro_mayor_error_',
            );
            final f = File('${tmp.path}/response_attempt_${attempts}.txt');
            await f.writeAsString(response.body);
            print('⚠️ Response completo guardado en: ${f.path}');
          } catch (e) {
            print('⚠️ No se pudo guardar response body en archivo: $e');
          }
          // Esperar un poco y reintentar
          await Future.delayed(Duration(milliseconds: 400 * attempts));
          continue;
        }
        break;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // El backend puede devolver una lista directa o un objeto que contiene la lista.
        // Normalizamos ambos casos para evitar errores de tipo cuando la API cambia la envoltura.
        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map<String, dynamic>) {
          // Intentar claves comunes donde el backend podría poner la lista
          if (data['results'] is List) {
            rawList = data['results'];
          } else if (data['cuentas'] is List) {
            rawList = data['cuentas'];
          } else if (data['data'] is List) {
            rawList = data['data'];
          } else {
            // Buscar la primera propiedad que sea una lista - heurística defensiva
            final firstListValue = data.values.firstWhere(
              (v) => v is List,
              orElse: () => null,
            );
            if (firstListValue is List) rawList = firstListValue;
          }
        }

        // Convertir a lista de mapas de forma segura
        final cuentas = rawList.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();

        print('✅ Cuentas con movimientos (normalizadas): ${cuentas.length}');

        // Debug: imprimir estructura del primer elemento (si existe)
        if (cuentas.isNotEmpty) {
          try {
            print('🔍 Estructura cuenta ejemplo: ${cuentas.first.keys}');
            final movs = (cuentas.first['movimientos'] is List)
                ? cuentas.first['movimientos'] as List<dynamic>
                : [];
            if (movs.isNotEmpty) {
              print(
                '🔍 Estructura movimiento ejemplo: ${(movs.first as Map).keys}',
              );
            }
          } catch (e) {
            print('⚠️ No se pudo inspeccionar estructura interna: $e');
          }
        }

        _cuentas = [];
        _movimientosPorCuenta.clear();

        for (var cuenta in cuentas) {
          final cuentaId = cuenta['id']?.toString() ?? '';
          final movimientos = cuenta['movimientos'] as List<dynamic>? ?? [];

          // Filtrar por fecha si está seleccionada
          List<Map<String, dynamic>> movimientosFiltrados = [];
          for (var mov in movimientos) {
            final movMap = mov as Map<String, dynamic>;

            // Adaptar estructura: el backend devuelve fecha directamente,
            // pero ExportHelper espera asiento['fecha']
            final movimientoAdaptado = {
              'fecha': movMap['fecha'],
              'referencia': movMap['referencia'],
              'debe': movMap['debe'],
              'haber': movMap['haber'],
              'descripcion': movMap['referencia'] ?? '',
              // Crear objeto asiento para compatibilidad con ExportHelper
              'asiento': {
                'fecha': movMap['fecha'],
                'numero': movMap['numero_asiento'] ?? '',
                'descripcion': movMap['referencia'] ?? '',
              },
            };

            if (_fechaInicio != null && _fechaFin != null) {
              final fechaStr = movMap['fecha']?.toString() ?? '';
              try {
                final fecha = DateTime.parse(fechaStr);
                if (fecha.isAfter(_fechaInicio!.subtract(Duration(days: 1))) &&
                    fecha.isBefore(_fechaFin!.add(Duration(days: 1)))) {
                  movimientosFiltrados.add(movimientoAdaptado);
                }
              } catch (e) {
                // Si no se puede parsear la fecha, incluir el movimiento
                movimientosFiltrados.add(movimientoAdaptado);
              }
            } else {
              movimientosFiltrados.add(movimientoAdaptado);
            }
          }

          // Solo agregar cuentas con movimientos (después del filtro)
          if (movimientosFiltrados.isNotEmpty) {
            _cuentas.add(cuenta);
            _movimientosPorCuenta[cuentaId] = movimientosFiltrados;
          }
        }

        // Ordenar cuentas por código
        _cuentas.sort((a, b) {
          final codigoA = a['codigo']?.toString() ?? '';
          final codigoB = b['codigo']?.toString() ?? '';
          return codigoA.compareTo(codigoB);
        });

        print('✅ Cuentas procesadas (con filtros): ${_cuentas.length}');
      } else {
        // En vez de fallar para la presentación, usamos un fallback rápido con
        // datos de ejemplo para que la pantalla muestre información.
        // Esto permite continuar con la presentación mientras se resuelve el 500
        // en el backend. El comportamiento normal no cambia cuando la API
        // responde 200.
        print(
          '⚠️ Endpoint devolvió ${response.statusCode}, usando datos de ejemplo',
        );

        // Datos de ejemplo mínimos compatibles con la UI.
        final ejemploCuentas = <Map<String, dynamic>>[
          {
            'id': 1,
            'codigo': '1.01',
            'nombre': 'Caja',
            'tipo_cuenta': 'Activo',
            'movimientos': [
              {
                'fecha': DateTime.now()
                    .subtract(Duration(days: 10))
                    .toIso8601String(),
                'referencia': 'Venta #1001',
                'debe': '1500.00',
                'haber': '0.00',
                'numero_asiento': 'A-1001',
              },
              {
                'fecha': DateTime.now()
                    .subtract(Duration(days: 5))
                    .toIso8601String(),
                'referencia': 'Compra #2002',
                'debe': '0.00',
                'haber': '700.00',
                'numero_asiento': 'A-1002',
              },
            ],
          },
          {
            'id': 2,
            'codigo': '2.01',
            'nombre': 'Proveedores',
            'tipo_cuenta': 'Pasivo',
            'movimientos': [
              {
                'fecha': DateTime.now()
                    .subtract(Duration(days: 20))
                    .toIso8601String(),
                'referencia': 'Factura #3003',
                'debe': '0.00',
                'haber': '1200.00',
                'numero_asiento': 'A-1000',
              },
            ],
          },
        ];

        // Procesar ejemplo como si viniera del backend
        _cuentas = [];
        _movimientosPorCuenta.clear();
        for (var cuenta in ejemploCuentas) {
          final cuentaId = cuenta['id']?.toString() ?? '';
          final movimientos = cuenta['movimientos'] as List<dynamic>? ?? [];
          final movimientosAdaptados = <Map<String, dynamic>>[];
          for (var mov in movimientos) {
            final movMap = mov as Map<String, dynamic>;
            movimientosAdaptados.add({
              'fecha': movMap['fecha'],
              'referencia': movMap['referencia'],
              'debe': movMap['debe'],
              'haber': movMap['haber'],
              'descripcion': movMap['referencia'] ?? '',
              'asiento': {
                'fecha': movMap['fecha'],
                'numero': movMap['numero_asiento'] ?? '',
                'descripcion': movMap['referencia'] ?? '',
              },
            });
          }

          if (movimientosAdaptados.isNotEmpty) {
            _cuentas.add(cuenta);
            _movimientosPorCuenta[cuentaId] = movimientosAdaptados;
          }
        }

        if (!mounted) return;
        setState(() => _cargando = false);

        // Informar al usuario que se muestran datos de ejemplo
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mostrando datos de ejemplo por fallo en el servidor',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
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
          totalDebe += _toDouble(mov['debe']);
          totalHaber += _toDouble(mov['haber']);
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
            final debe = _toDouble(mov['debe']);
            final haber = _toDouble(mov['haber']);
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

  Future<void> _exportarPDF() async {
    await ExportHelper.exportLibroMayorPDF(
      context: context,
      cuentas: _cuentas,
      movimientosPorCuenta: _movimientosPorCuenta,
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
      cuentaSeleccionadaId: _cuentaSeleccionada,
    );
  }

  Future<void> _exportarExcel() async {
    await ExportHelper.exportLibroMayorExcel(
      context: context,
      cuentas: _cuentas,
      movimientosPorCuenta: _movimientosPorCuenta,
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
      cuentaSeleccionadaId: _cuentaSeleccionada,
    );
  }
}
