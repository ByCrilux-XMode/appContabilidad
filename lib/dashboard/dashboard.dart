import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../asientoContable/asientoContable.dart';
import '../movimientoContable/verMovimientos.dart';
import '../cuentascontables/cuentacontable.dart';
import '../reportes/libroDiario.dart';
import '../reportes/libroMayor.dart';
import '../reportes/balanceGeneral.dart';
import '../reportes/estadoResultados.dart';

class DashBoardUsuario extends StatefulWidget {
  const DashBoardUsuario({super.key});
  @override
  State<DashBoardUsuario> createState() => _DashBoardUsuarioState();
}

class _DashBoardUsuarioState extends State<DashBoardUsuario> {
  String? _nombreEmpresa = null;
  List<String> _menuOpciones = [
    'Registrar Asiento',
    'Ver Cuentas Contables',
    'Ver Movimientos',
    'Libro Diario',
    'Libro Mayor',
    'Balance General',
    'Estado de Resultados',
  ];
  String _queOpcionSelecionada = '';

  @override
  void initState() {
    super.initState();
    _cargarEmpresa();
  }

  // Constructor de widgets mejorado con indicadores visuales
  Widget _miOpcion(String opcion) {
    bool estaSeleccionada = _queOpcionSelecionada == opcion;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: estaSeleccionada ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: estaSeleccionada ? Colors.blue.shade300 : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          _obtenerIcono(opcion),
          color: estaSeleccionada ? Colors.blue.shade700 : Colors.grey.shade600,
          size: 24,
        ),
        title: Text(
          opcion,
          style: TextStyle(
            fontSize: 16,
            fontWeight: estaSeleccionada ? FontWeight.bold : FontWeight.normal,
            color: estaSeleccionada
                ? Colors.blue.shade700
                : Colors.grey.shade800,
          ),
        ),
        trailing: estaSeleccionada
            ? Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20)
            : null,
        onTap: () {
          setState(() {
            _queOpcionSelecionada = opcion;
          });
          // Cerrar el drawer automáticamente en dispositivos móviles
          if (MediaQuery.of(context).size.width < 600) {
            Navigator.pop(context);
          }
        },
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Método para obtener iconos según la opción
  IconData _obtenerIcono(String opcion) {
    switch (opcion) {
      case 'Registrar Asiento':
        return Icons.add_circle_outline;
      case 'Ver Cuentas Contables':
        return Icons.account_balance_wallet;
      case 'Ver Movimientos':
        return Icons.list_alt;
      case 'Libro Diario':
        return Icons.book;
      case 'Libro Mayor':
        return Icons.auto_stories;
      case 'Balance General':
        return Icons.assessment;
      case 'Estado de Resultados':
        return Icons.analytics;
      default:
        return Icons.dashboard;
    }
  }

  // Widget para el contenido principal
  Widget _contenidoPrincipal() {
    if (_queOpcionSelecionada.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 80, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              'Bienvenido al Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Selecciona una opción del menú para comenzar',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    switch (_queOpcionSelecionada) {
      case 'Registrar Asiento':
        return AsientoContable();
      case 'Ver Cuentas Contables':
        return Cuentacontable();
      case 'Ver Movimientos':
        return verMovimientos();
      case 'Libro Diario':
        return LibroDiario();
      case 'Libro Mayor':
        return LibroMayor();
      case 'Balance General':
        return BalanceGeneral();
      case 'Estado de Resultados':
        return EstadoResultados();
      default:
        return Center(child: Text('Dashboard'));
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) / 4;

    return Scaffold(
      appBar: AppBar(
        title: Text('TuAppContable'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Indicador de opción seleccionada en el AppBar
          if (_queOpcionSelecionada.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(
                    _obtenerIcono(_queOpcionSelecionada),
                    size: 20,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),
        ],
      ),
      body: _contenidoPrincipal(),
      drawer: Drawer(
        width: ancho * 0.7,
        child: Column(
          children: [
            // Header del Drawer
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance, size: 50, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      _nombreEmpresa ?? 'Sin Empresa',
                      style: TextStyle(
                        fontSize: iconsLetra * 0.06,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dashboard Contable',
                      style: TextStyle(
                        fontSize: iconsLetra * 0.04,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Lista de opciones
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 16),
                children: [for (var opcion in _menuOpciones) _miOpcion(opcion)],
              ),
            ),
            // Footer del Drawer
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text(
                'TuAppContable v1.0',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      onDrawerChanged: (open) async {
        if (open) {
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
    final responde = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"empresa_id": empresaId.toString()}),
    );
    if (responde.statusCode == 200) {
      final Map<String, dynamic> dato = jsonDecode(responde.body);
      Config().GuardarAlgunDato('access', dato['access']);
      Config().GuardarAlgunDato('user_empresa', dato['user_empresa']);
      Config().GuardarAlgunDato('usuarioId', dato['usuario']['id']);
      Config().GuardarAlgunDato(
        'telefono',
        dato['usuario']['persona']['telefono'],
      );
      Config().GuardarAlgunDato('ci', dato['usuario']['persona']['telefono']);
      //roles y permisos
      Config().GuardarAlgunDato('roles', List<String>.from(dato['roles']));
      //aqui habran permisos
      //roles y permisos
      Config().GuardarAlgunDato(
        'colorPrimario',
        dato['custom']['color_primario'],
      );
      Config().GuardarAlgunDato(
        'colorSecundario',
        dato['custom']['color_secundario'],
      );
      Config().GuardarAlgunDato(
        'colorTerciario',
        dato['custom']['color_terciario'],
      );
    } else {
      print('Error: ${responde.statusCode} - ${responde.body}');
    }
  }
}
