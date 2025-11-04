import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class Cuentacontable extends StatefulWidget {
  @override
  _CuentacontableState createState() => _CuentacontableState();
}

class _CuentacontableState extends State<Cuentacontable> {
  int currentPage = 1;
  bool showAll = true;
  bool showModal = false;
  bool _cargando = true;

  String? claseSeleccionada;
  List<Map<String, dynamic>> cuentas = [];
  List<Map<String, dynamic>> cuentasFiltradas = [];
  List<String> tiposCuenta = [];

  final TextEditingController codigoCtrl = TextEditingController();
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController tipoCtrl = TextEditingController();
  String estado = "ACTIVO";

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  Future<void> _cargarCuentas() async {
    setState(() => _cargando = true);
    try {
      final token = await Config().obtenerDato('access');
      final url = '${Config.baseUrl}/cuenta';

      print('Cargando cuentas desde: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final listaCuentas = List<Map<String, dynamic>>.from(
          data['results'] ?? [],
        );

        // Extraer tipos de cuenta únicos
        Set<String> tipos = {};
        for (var cuenta in listaCuentas) {
          final tipo = cuenta['tipo_cuenta']?.toString() ?? '';
          if (tipo.isNotEmpty) tipos.add(tipo);
        }

        setState(() {
          cuentas = listaCuentas;
          cuentasFiltradas = listaCuentas;
          tiposCuenta = tipos.toList()..sort();
          _cargando = false;
        });

        print('Cuentas cargadas: ${cuentas.length}');
        print('Tipos de cuenta: ${tiposCuenta.length}');
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error al cargar cuentas: $e');
      print('StackTrace: $stackTrace');
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar cuentas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _filtrarPorTipo(String? tipo) {
    setState(() {
      claseSeleccionada = tipo;
      showAll = tipo == null;

      if (tipo == null) {
        cuentasFiltradas = cuentas;
      } else {
        cuentasFiltradas = cuentas.where((cuenta) {
          final tipoCuenta = cuenta['tipo_cuenta']?.toString() ?? '';
          return tipoCuenta.toLowerCase().contains(tipo.toLowerCase());
        }).toList();
      }
      currentPage = 1;
    });
    print('Filtrado: ${cuentasFiltradas.length} cuentas');
  }

  Future<void> _crearCuenta() async {
    if (codigoCtrl.text.isEmpty ||
        nombreCtrl.text.isEmpty ||
        tipoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final token = await Config().obtenerDato('access');
      final url = '${Config.baseUrl}/cuenta';

      print('Creando cuenta: ${codigoCtrl.text}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'codigo': codigoCtrl.text,
          'nombre': nombreCtrl.text,
          'tipo_cuenta': tipoCtrl.text,
          'estado': estado,
        }),
      );

      print('Crear cuenta Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }

        codigoCtrl.clear();
        nombreCtrl.clear();
        tipoCtrl.clear();
        setState(() => showModal = false);

        // Recargar lista
        _cargarCuentas();
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error al crear cuenta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear cuenta: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _verDetalleCuenta(Map<String, dynamic> cuenta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalle de Cuenta'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Código', cuenta['codigo']?.toString() ?? 'N/A'),
              _buildDetailRow('Nombre', cuenta['nombre']?.toString() ?? 'N/A'),
              _buildDetailRow(
                'Tipo',
                cuenta['tipo_cuenta']?.toString() ?? 'N/A',
              ),
              _buildDetailRow(
                'Estado',
                cuenta['estado']?.toString() ?? 'ACTIVO',
              ),
              if (cuenta['descripcion'] != null)
                _buildDetailRow(
                  'Descripción',
                  cuenta['descripcion'].toString(),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Gestión de Cuentas",
          style: TextStyle(
            color: Colors.white, // Cambia el color aquí
            fontWeight: FontWeight.bold, // opcional: negrita
            fontSize: 20, // opcional: tamaño del texto
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Filtro
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filtrar por Tipo de Cuenta",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _filtrarPorTipo(null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showAll
                                ? Colors.blue
                                : Colors.grey.shade300,
                          ),
                          child: const Text("Todos"),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: tiposCuenta.isEmpty
                              ? const Text(
                                  "Cargando tipos...",
                                  style: TextStyle(color: Colors.grey),
                                )
                              : DropdownButton<String>(
                                  value: claseSeleccionada,
                                  hint: const Text("Seleccionar tipo"),
                                  isExpanded: true,
                                  items: tiposCuenta.map((tipo) {
                                    return DropdownMenuItem(
                                      value: tipo,
                                      child: Text(tipo),
                                    );
                                  }).toList(),
                                  onChanged: _filtrarPorTipo,
                                ),
                        ),
                      ],
                    ),
                    if (claseSeleccionada != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "Mostrando: ${cuentasFiltradas.length} cuenta(s) de tipo '$claseSeleccionada'",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Lista de cuentas
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : cuentasFiltradas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            claseSeleccionada == null
                                ? "No hay cuentas registradas"
                                : "No hay cuentas del tipo '$claseSeleccionada'",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: cuentasFiltradas.length,
                      itemBuilder: (context, index) {
                        final cuenta = cuentasFiltradas[index];
                        final codigo = cuenta['codigo']?.toString() ?? 'S/C';
                        final nombre =
                            cuenta['nombre']?.toString() ?? 'Sin nombre';
                        final tipo =
                            cuenta['tipo_cuenta']?.toString() ?? 'Sin tipo';
                        final estadoCuenta =
                            cuenta['estado']?.toString() ?? 'ACTIVO';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getColorByTipo(tipo),
                              child: Text(
                                codigo.substring(
                                  0,
                                  codigo.length > 2 ? 2 : codigo.length,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              "$codigo – $nombre",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Tipo: $tipo"),
                                Row(
                                  children: [
                                    Icon(
                                      estadoCuenta == 'ACTIVO'
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 14,
                                      color: estadoCuenta == 'ACTIVO'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      estadoCuenta,
                                      style: TextStyle(
                                        color: estadoCuenta == 'ACTIVO'
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.visibility,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () => _verDetalleCuenta(cuenta),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Información de resultados
            if (!_cargando && cuentasFiltradas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "Total: ${cuentasFiltradas.length} cuenta(s)",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
          ],
        ),
      ),

      // Botón flotante para nueva cuenta
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () => setState(() => showModal = true),
      ),

      // Modal (Dialog)
      persistentFooterButtons: showModal
          ? [
              Container(
                width: double.infinity,
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Crear Nueva Cuenta",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: codigoCtrl,
                              decoration: const InputDecoration(
                                labelText: "Código",
                              ),
                            ),
                            TextField(
                              controller: nombreCtrl,
                              decoration: const InputDecoration(
                                labelText: "Nombre",
                              ),
                            ),
                            TextField(
                              controller: tipoCtrl,
                              decoration: const InputDecoration(
                                labelText: "Tipo de Cuenta",
                                hintText: "Ej: Activo, Pasivo, Patrimonio",
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              value: estado,
                              onChanged: (v) => setState(() => estado = v!),
                              decoration: const InputDecoration(
                                labelText: "Estado",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "ACTIVO",
                                  child: Text("ACTIVO"),
                                ),
                                DropdownMenuItem(
                                  value: "INACTIVO",
                                  child: Text("INACTIVO"),
                                ),
                                DropdownMenuItem(
                                  value: "CERRADO",
                                  child: Text("CERRADO"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    codigoCtrl.clear();
                                    nombreCtrl.clear();
                                    tipoCtrl.clear();
                                    setState(() => showModal = false);
                                  },
                                  child: const Text("Cancelar"),
                                ),
                                ElevatedButton(
                                  onPressed: _crearCuenta,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text("Crear"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  Color _getColorByTipo(String tipo) {
    final tipoLower = tipo.toLowerCase();
    if (tipoLower.contains('activo')) return Colors.green.shade700;
    if (tipoLower.contains('pasivo')) return Colors.red.shade700;
    if (tipoLower.contains('patrimonio') || tipoLower.contains('capital')) {
      return Colors.purple.shade700;
    }
    if (tipoLower.contains('ingreso') || tipoLower.contains('venta')) {
      return Colors.blue.shade700;
    }
    if (tipoLower.contains('gasto') || tipoLower.contains('costo')) {
      return Colors.orange.shade700;
    }
    return Colors.grey.shade700;
  }
}
