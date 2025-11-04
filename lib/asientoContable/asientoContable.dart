import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AsientoContable extends StatefulWidget {
  const AsientoContable({super.key});
  @override
  State<AsientoContable> createState() => _AsientoContableState();
}

class _AsientoContableState extends State<AsientoContable> {
  final _llaveForm = GlobalKey<FormState>();
  TextEditingController _descripcionGeneralController = TextEditingController();
  List<TextEditingController> _descripcionControllers = [];
  List<TextEditingController> _debeControllers = [];
  List<TextEditingController> _haberControllers = [];
  List<String?> _cuentasSeleccionadas = [];
  int _cantidadAsientos = 2;
  List<Map<String, dynamic>> _listaCuentas = [];
  bool _cargandoCuentas = true;

  @override
  void initState() {
    super.initState();
    _ajustarControladores();
    _cargarCuentas();
  }

  @override
  void dispose() {
    for (var controller in _descripcionControllers) controller.dispose();
    for (var controller in _debeControllers) controller.dispose();
    for (var controller in _haberControllers) controller.dispose();
    _descripcionGeneralController.dispose();
    super.dispose();
  }

  Future<void> _cargarCuentas() async {
    try {
      setState(() => _cargandoCuentas = true);

      final token = await Config().obtenerDato('access');
      final url = Uri.parse('${Config.baseUrl}/cuenta');
      final responseCuentas = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (responseCuentas.statusCode == 200) {
        print('Respuesta cuentas: ${responseCuentas.body}');
        final data = jsonDecode(responseCuentas.body);
        final List<dynamic> results = data['results'];

        // Filtrar solo las cuentas ACTIVAS
        final cuentasActivas = results.where((cuenta) {
          final estado = cuenta['estado']?.toString().toUpperCase() ?? '';
          return estado == 'ACTIVO' || estado == 'ACTIVE';
        }).toList();

        print('Total de cuentas: ${results.length}');
        print('Cuentas activas: ${cuentasActivas.length}');

        setState(() {
          _listaCuentas = List<Map<String, dynamic>>.from(cuentasActivas);
          _cargandoCuentas = false;
        });

        if (_listaCuentas.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay cuentas activas. Active o cree cuentas primero.',
              ),
            ),
          );
        } else {
          print(
            'Cuentas activas disponibles: ${_listaCuentas.map((c) => "${c['codigo']} - ${c['nombre']}").join(", ")}',
          );
        }
      } else {
        print('Error: ${responseCuentas.statusCode} - ${responseCuentas.body}');
        setState(() => _cargandoCuentas = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar cuentas: ${responseCuentas.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error cargando cuentas: $e');
      setState(() => _cargandoCuentas = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _ajustarControladores() {
    // Añadir controladores si hay más filas
    while (_descripcionControllers.length < _cantidadAsientos) {
      _descripcionControllers.add(TextEditingController());
      _debeControllers.add(TextEditingController(text: '0.0'));
      _haberControllers.add(TextEditingController(text: '0.0'));
      _cuentasSeleccionadas.add(null);
    }
    // Eliminar y liberar si hay menos filas
    while (_descripcionControllers.length > _cantidadAsientos) {
      _descripcionControllers.removeLast().dispose();
      _debeControllers.removeLast().dispose();
      _haberControllers.removeLast().dispose();
      _cuentasSeleccionadas.removeLast();
    }
  }

  Future<void> _guardarAsiento() async {
    if (!_llaveForm.currentState!.validate()) return;
    double totalDebe = 0.0;
    double totalHaber = 0.0;

    for (int i = 0; i < _cantidadAsientos; i++) {
      final debeStr = _debeControllers[i].text.trim();
      final haberStr = _haberControllers[i].text.trim();

      // Si ambos estan vacios (fila no usada)
      if (debeStr.isEmpty && haberStr.isEmpty) continue;
      final debe = double.tryParse(debeStr) ?? 0.0;
      final haber = double.tryParse(haberStr) ?? 0.0;

      totalDebe += debe;
      totalHaber += haber;
    }

    //validar que Debe = Haber
    if ((totalDebe - totalHaber).abs() > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La suma de Debe ($totalDebe) debe ser igual a la suma de Haber ($totalHaber)',
          ),
        ),
      );
      return;
    }

    for (int i = 0; i < _cantidadAsientos; i++) {
      print(
        'Fila $i: ${_descripcionControllers[i].text} | ${_cuentasSeleccionadas[i]} | Debe: ${_debeControllers[i].text} | Haber: ${_haberControllers[i].text}',
      );
    }
    final token = await Config().obtenerDato('access');
    final url = Uri.parse('${Config.baseUrl}/asiento_contable/');

    final body = jsonEncode({
      "descripcion": _descripcionGeneralController.text, // o un campo general
      "movimientos": List.generate(_cantidadAsientos, (i) {
        final debe = _debeControllers[i].text;
        final haber = _haberControllers[i].text;
        // solo incluir filas con datos
        if (debe == '0.0' && haber == '0.0') return null;
        return {
          "referencia": _descripcionControllers[i].text,
          "cuenta": _cuentasSeleccionadas[i],
          "debe": debe,
          "haber": haber,
        };
      }).whereType<Map<String, dynamic>>().toList(),
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 201) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success, // success, error, warning, info, etc.
        animType:
            AnimType.scale, // animación: scale, bottomSlide, leftSlide, etc.
        title: 'Asiento guardado',
        desc: 'Los datos se guardaron correctamente.',
        btnOkText: 'Aceptar',
        //btnOkOnPress: () {},              // acción al presionar OK
      ).show();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
    }
  }

  //inicio constructor de widgets de filas
  List<Widget> _filaDeMovimientos(double iconoletra) {
    _ajustarControladores();
    List<Widget> filas = [];

    for (int i = 0; i < _cantidadAsientos; i++) {
      filas.add(
        Card(
          elevation: 5,
          margin: EdgeInsets.symmetric(
            vertical: iconoletra * 0.05,
            horizontal: iconoletra * 0.02,
          ),
          child: Padding(
            padding: EdgeInsets.all(iconoletra * 0.08),
            child: Wrap(
              spacing: iconoletra * 0.05, //espaciado entre cajitas
              runSpacing: iconoletra * 0.05, // espaciado sobre cajitas
              children: [
                // Campo 1
                SizedBox(
                  width: iconoletra * 0.8,
                  height: iconoletra * 0.15,
                  child: TextFormField(
                    controller: _descripcionControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Descripcion',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: iconoletra * 0.08),
                    validator: (textoDeEntrada) {
                      if (textoDeEntrada == null || textoDeEntrada.isEmpty) {
                        return 'Ingrese una descripcion';
                      } else {
                        return null;
                      }
                    },
                  ),
                ),

                // Dropdown
                SizedBox(
                  width: iconoletra * 1,
                  height: iconoletra * 0.15,
                  child: _cargandoCuentas
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Cargando cuentas...'),
                            ],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: _cuentasSeleccionadas[i],
                          decoration: const InputDecoration(
                            labelText: 'Cuenta',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          isExpanded:
                              false, // evita que se expanda al ancho del contenedor
                          items: _listaCuentas.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('No hay cuentas'),
                                  ),
                                ]
                              : _listaCuentas.map((cuenta) {
                                  return DropdownMenuItem<String>(
                                    value: cuenta['id'].toString(),
                                    child: Text(
                                      '${cuenta['codigo']} - ${cuenta['nombre']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                          onChanged: _listaCuentas.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _cuentasSeleccionadas[i] = value;
                                  });
                                },
                          validator: (cuenta) {
                            if (cuenta == null || cuenta.isEmpty) {
                              return 'Seleccione una cuenta';
                            } else {
                              return null;
                            }
                          },
                        ),
                ),

                // Campo 2
                SizedBox(
                  width: iconoletra * 0.4,
                  height: iconoletra * 0.15,
                  child: TextFormField(
                    controller: _debeControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Debe',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        size: iconoletra * 0.07,
                      ),
                      isDense: false,
                    ),
                    style: TextStyle(fontSize: iconoletra * 0.05),
                    validator: (valorDebe) {
                      if (valorDebe == null || valorDebe.isEmpty) {
                        return 'Ingrese un valor';
                      } else {
                        return null;
                      }
                    },
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),

                // Campo 3
                SizedBox(
                  width: iconoletra * 0.4,
                  height: iconoletra * 0.15,
                  child: TextFormField(
                    //cursorHeight: 20,
                    controller: _haberControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Haber',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        size: iconoletra * 0.07,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: iconoletra * 0.05),
                    validator: (valorHaber) {
                      if (valorHaber == null || valorHaber.isEmpty) {
                        return 'Ingrese un valor';
                      } else {
                        return null;
                      }
                    },
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) / 4;

    return Form(
      key: _llaveForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Padding(
            padding: EdgeInsets.symmetric(vertical: iconsLetra * 0.02),
            child: Text(
              'Crea un Asiento Contable',
              style: TextStyle(
                fontSize: iconsLetra * 0.08,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[700],
              ),
            ),
          ),
          SizedBox(height: iconsLetra * 0.03),

          // Descripción general
          Padding(
            padding: EdgeInsets.symmetric(horizontal: iconsLetra * 0.03),
            child: TextFormField(
              controller: _descripcionGeneralController,
              decoration: InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej: Asiento de apertura',
                labelStyle: TextStyle(fontSize: iconsLetra * 0.065),
                prefixIcon: Icon(Icons.description, size: iconsLetra * 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              validator: (textoDeEntrada) {
                if (textoDeEntrada == null || textoDeEntrada.isEmpty) {
                  return 'Ingrese una descripción';
                } else {
                  return null;
                }
              },
            ),
          ),
          SizedBox(height: iconsLetra * 0.04),

          // Alerta si no hay cuentas
          if (!_cargandoCuentas && _listaCuentas.isEmpty)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: iconsLetra * 0.03,
                vertical: iconsLetra * 0.02,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No hay cuentas disponibles',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const Text(
                          'Debe crear cuentas en "Ver Cuentas Contables" antes de registrar asientos.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _cargarCuentas,
                    tooltip: 'Recargar cuentas',
                  ),
                ],
              ),
            ),

          // Movimientos con botones Añadir/Quitar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: iconsLetra * 0.03),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Movimientos',
                  style: TextStyle(
                    fontSize: iconsLetra * 0.07,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo[600],
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _cantidadAsientos++;
                          _ajustarControladores();
                        });
                      },
                      icon: Icon(Icons.add, size: iconsLetra * 0.06),
                      label: const Text('Añadir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (_cantidadAsientos > 2)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_cantidadAsientos > 2) {
                              _cantidadAsientos--;
                              _ajustarControladores();
                            }
                          });
                        },
                        icon: Icon(Icons.remove, size: iconsLetra * 0.06),
                        label: Text('Quitar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: iconsLetra * 0.03),

          // Filas de movimientos
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: iconsLetra * 0.03),
              child: Column(
                children: _filaDeMovimientos(iconsLetra).map((fila) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: iconsLetra * 0.02),
                    child: fila,
                  );
                }).toList(),
              ),
            ),
          ),

          // Botón Guardar Asiento
          Padding(
            padding: EdgeInsets.all(iconsLetra * 0.04),
            child: SizedBox(
              width: double.infinity,
              height: iconsLetra * 0.15,
              child: ElevatedButton(
                onPressed: _guardarAsiento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'Guardar Asiento',
                  style: TextStyle(
                    fontSize: iconsLetra * 0.065,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
