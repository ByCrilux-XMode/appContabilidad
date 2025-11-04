import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class verMovimientos extends StatefulWidget {
  const verMovimientos({super.key});
  @override
  State<verMovimientos> createState() => _verMovimientosState();
}

class _verMovimientosState extends State<verMovimientos> {
  //variables
  List<Map<String, dynamic>> _listaMovimientos = [];
  int? _cantidadMovimientos;
  //variables
  //pantalla inicio
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) / 4;
    return Scaffold(
      body: Center(
        //mientra _cantidadMovimiento es nulo
        child: _cantidadMovimientos == null
            ? const CircularProgressIndicator()
            : ListView.separated(
                itemBuilder: (context, index) {
                  String fechaOrifgonal =
                      _listaMovimientos[index]['asiento']['fecha'];
                  DateTime fecha = DateTime.parse(fechaOrifgonal);
                  String fechaFormateada = DateFormat(
                    'EEEE dd MMMM, yyyy',
                    'es_ES',
                  ).format(fecha);
                  return ListTile(
                    title: Text(
                      '${_listaMovimientos[index]['referencia']}',
                      style: TextStyle(
                        fontSize: iconsLetra * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: Text(
                      'N° ${_listaMovimientos[index]['asiento']['numero']}',
                      style: TextStyle(fontSize: iconsLetra * 0.05),
                    ),
                    subtitle: Column(
                      spacing: 12,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fecha: ${fechaFormateada}'),
                        Text(
                          'Cuenta: ${_listaMovimientos[index]['cuenta']['nombre']}',
                        ),
                        Wrap(
                          spacing: iconsLetra * 0.1,
                          children: [
                            Text('Debe: ${_listaMovimientos[index]['debe']}'),
                            Text('Haber: ${_listaMovimientos[index]['haber']}'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) {
                  return Divider();
                },
                itemCount: _cantidadMovimientos!,
              ),
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    _cargarMovimientos();
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }
  //pantalla fin

  //funciones inicio
  Future<void> _cargarMovimientos() async {
    final token = await Config().obtenerDato('access');
    final url = Uri.parse('${Config.baseUrl}/movimiento');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print('------------------------------------');
      print('Exito al cargar los movimientos');
      print(response.body);
      final Map<String, dynamic> data = json.decode(response.body);
      Config().GuardarAlgunDato('count', data['count']);

      final List<dynamic> movimientosData = data['results'];
      setState(() {
        _listaMovimientos = List<Map<String, dynamic>>.from(movimientosData);
        _cantidadMovimientos = data['count'];
      });

      print('-----decodificado----------------------');
      if (movimientosData.isNotEmpty) {
        print(movimientosData[0]);
      } else {
        print('No hay movimientos para mostrar');
      }
      print('-----lista movimientos----------------------');
      print(_listaMovimientos);
      print('------------------------------------');
    } else {
      print('------------------------------------');
      print('Error al cargar los movimientos');
      print(response.body);
      print('------------------------------------');
    }
  }

  //funciones fin
}
