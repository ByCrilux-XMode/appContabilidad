import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AsientoContable extends StatefulWidget{
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

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
    _ajustarControladores();
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
      final token = await Config().obtenerDato('access');
      //prueba de fetch de cuentas
      final url = Uri.parse('${Config.baseUrl}/cuenta');
      final responseCuentas = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (responseCuentas.statusCode == 200) {
        print(responseCuentas.body);
        final data = jsonDecode(responseCuentas.body);
        final List<dynamic> results = data['results'];
        setState(() {
          _listaCuentas = List<Map<String, dynamic>>.from(results);
        });
      } else {
      print('Error: ${responseCuentas.statusCode} - ${responseCuentas.body}');
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
        SnackBar(content: Text('La suma de Debe ($totalDebe) debe ser igual a la suma de Haber ($totalHaber)')),
      );
      return;
    }

    for (int i = 0; i < _cantidadAsientos; i++) {
      print('Fila $i: ${_descripcionControllers[i].text} | ${_cuentasSeleccionadas[i]} | Debe: ${_debeControllers[i].text} | Haber: ${_haberControllers[i].text}');
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
        dialogType: DialogType.success,   // success, error, warning, info, etc.
        animType: AnimType.scale,         // animación: scale, bottomSlide, leftSlide, etc.
        title: 'Asiento guardado',
        desc: 'Los datos se guardaron correctamente.',
        btnOkText: 'Aceptar',
        //btnOkOnPress: () {},              // acción al presionar OK
      ).show();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
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
          margin: EdgeInsets.symmetric(vertical: iconoletra * 0.05, horizontal: iconoletra * 0.02),
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
                    validator: (textoDeEntrada){
                      if (textoDeEntrada == null || textoDeEntrada.isEmpty){
                        return 'Ingrese una descripcion';
                      }else{
                        return null;
                      }
                    },
                  ),
                ),

                // Dropdown
                SizedBox(
                  width: iconoletra * 1,
                  height: iconoletra * 0.15,
                  child: DropdownButtonFormField<String>(
                    value: _cuentasSeleccionadas[i],
                    decoration: InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    isExpanded: false, // evita que se expanda al ancho del contenedor
                    items: _listaCuentas.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text('Sin cuentas'))]
                        : _listaCuentas.map((cuenta) {
                      return DropdownMenuItem<String>(
                        value: cuenta['id'],
                        child: Text('${cuenta['codigo']} - ${cuenta['nombre']}',overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _cuentasSeleccionadas[i] = value;
                      });
                    },
                    validator: (cuenta){
                      if (cuenta == null || cuenta.isEmpty){
                        return 'sleccione una cuenta';
                      }else{
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
                      prefixIcon: Icon(Icons.attach_money, size: iconoletra * 0.07),
                      isDense: false,
                    ),
                    style: TextStyle(fontSize: iconoletra * 0.05),
                    validator: (valorDebe){
                      if (valorDebe == null || valorDebe.isEmpty){
                        return 'Ingrese un valor';
                      }else{
                        return null;
                      }
                    },
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                      prefixIcon: Icon(Icons.attach_money, size: iconoletra * 0.07),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: iconoletra * 0.05),
                    validator: (valorHaber){
                      if (valorHaber == null || valorHaber.isEmpty){
                        return 'Ingrese un valor';
                      }else{
                        return null;
                      }
                    },
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
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
    return       Form(
        key: _llaveForm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Crea un Asiento Contable', style: TextStyle(fontSize: iconsLetra * 0.08)),
            SizedBox(height: iconsLetra * 0.05),
            //inicio descripcion general asiento contable
            TextFormField(controller: _descripcionGeneralController,
              decoration: InputDecoration(
                labelText: 'descripcion',hintText: 'ej: Asiento de apertura',
                labelStyle: TextStyle(fontSize: iconsLetra * 0.08),
                prefixIcon: Icon(Icons.description, size: iconsLetra * 0.1,),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)
                ),
              ),
              validator: (textoDeEntrada){
                if (textoDeEntrada == null || textoDeEntrada.isEmpty){
                  return 'Ingrese una descripcion';
                }else{
                  return null;
                }
              },
            ),
            //fin descripcion asiento contable
            SizedBox(height: iconsLetra * 0.05),
            Wrap(
              spacing: iconsLetra * 0.05,
              children:[
                Text('movimientos', style: TextStyle(fontSize: iconsLetra * 0.08)),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed:(){setState(() {
                      _cantidadAsientos ++;
                      _ajustarControladores();
                    });},
                    child: Text('Añadir',style: TextStyle(color: Theme.of(context).colorScheme.surface))
                ),
                _cantidadAsientos > 2 ? ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed:(){setState(() {
                      if(_cantidadAsientos > 2) {
                        _cantidadAsientos --;
                        _ajustarControladores();
                      }
                    });},
                    child: Text('Quitar',style: TextStyle(color: Theme.of(context).colorScheme.surface))
                ): Text(''),
              ],
            ),
            SizedBox(height: iconsLetra * 0.05),
            //inicio widget generador de filas
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column( children: [
                  ..._filaDeMovimientos(iconsLetra),
                ]),
              ),
            ),
            //inicio widget generador de filas
            Padding(
              padding: EdgeInsets.all(iconsLetra * 0.08),
              child: ElevatedButton(
                onPressed:_guardarAsiento,
                child: Text('Guardar Asiento'),
              ),
            )
          ],
        )
    );
  }
}