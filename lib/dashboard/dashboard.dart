import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../asientoContable/asientoContable.dart';
import '../movimientoContable/verMovimientos.dart';

class DashBoardUsuario extends StatefulWidget {
  const DashBoardUsuario({super.key});
  @override
  State<DashBoardUsuario> createState() => _DashBoardUsuarioState();
}

class _DashBoardUsuarioState extends State<DashBoardUsuario> {
  String? _nombreEmpresa = null;
  List<String> _menuOpciones = ['Registrar Asiento', 'Ver Cuentas Contables', 'Ver Movimientos'];
  String _queOpcionSelecionada = '';

  @override
  void initState() {
    super.initState();
    _cargarEmpresa();
  }

  //inicio constructor de widgets
  Widget _miOpcion(String opcion){
    return ListTile(
      title: Text(opcion),
      onTap: (){
        setState(() {
          _queOpcionSelecionada = opcion;
        });
      },
    );
  }
  //fin constructor de widgets
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) / 4;
    return Scaffold(
      appBar: AppBar(
        title: Text('TuAppCotable'),
      ), //Kevin a aqui van las diferentes opciones de seleccionado dependiendo de las opciones
      body: _queOpcionSelecionada == '' ? Text('dashboard'): //mostrar dashboard
      _queOpcionSelecionada == 'Registrar Asiento' ?
      AsientoContable()
          :_queOpcionSelecionada == 'Ver Cuentas Contables' ? Text('Cuentas Contables')
          :_queOpcionSelecionada == 'Ver Movimientos'?
      verMovimientos() : Text('dashboard'),
      drawer: Drawer(
        width: ancho * 0.7,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader (
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade100,
              ),
              child: Center(
                child: Text(_nombreEmpresa ?? 'sin Empresa', style: TextStyle(
                  fontSize: iconsLetra * 0.08,
                ),
                ),
              )
            ),
            for (var opcion in _menuOpciones) _miOpcion(opcion),
          ]
        )
      ),
      onDrawerChanged:(open) async {
        if(open){
          final String nombre = await Config().obtenerDato('empresa_nombre');
          setState(() {
            _nombreEmpresa = nombre;
          });
        }
      },
    );
  }

  Future<void> _cargarEmpresa() async {
    final url = Uri.parse('${Config.baseUrl}/auth_empresa/login_empresa/');
    final token = await Config().obtenerDato('access');
    final empresaId = await Config().obtenerDato('empresa_id');
    final responde = await http.post(url,
        headers:
        {
          "Content-Type": "application/json",
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "empresa_id": empresaId.toString(),
        })
    );
    if (responde.statusCode == 200) {
      final Map<String, dynamic> dato = jsonDecode(responde.body);
      Config().GuardarAlgunDato('access', dato['access']);
      Config().GuardarAlgunDato('user_empresa', dato['user_empresa']);
      Config().GuardarAlgunDato('usuarioId', dato['usuario']['id']);
      Config().GuardarAlgunDato('telefono', dato['usuario']['persona']['telefono']);
      Config().GuardarAlgunDato('ci', dato['usuario']['persona']['telefono']);
      //roles y permisos
      Config().GuardarAlgunDato('roles', List<String>.from(dato['roles']));
      //aqui habran permisos
      //roles y permisos
      Config().GuardarAlgunDato('colorPrimario', dato['custom']['color_primario']);
      Config().GuardarAlgunDato('colorSecundario', dato['custom']['color_secundario']);
      Config().GuardarAlgunDato('colorTerciario', dato['custom']['color_terciario']);

    } else {
      print('Error: ${responde.statusCode} - ${responde.body}');
    }
  }
}
