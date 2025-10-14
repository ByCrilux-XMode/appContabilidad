import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import '/dashboard/dashboard.dart';

class ElegirEmpresa extends StatefulWidget {
  const ElegirEmpresa({super.key});
  @override
  State<ElegirEmpresa> createState() => _ElegirEmpresaState();
}

class _ElegirEmpresaState extends State<ElegirEmpresa> {
  List<Map<String, dynamic>>? _empresas;
  String? selectedEmpresaId;
  bool _isEmpresaSelected = false;

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double alto = size.height;
    double ancho = size.width;
    double iconsLetra = (alto + ancho) / 4;

    return Scaffold(
      body: Align(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: Text('Si no Posee una empresa, creela en la Web\no espera a ser añadido'),
              color: Colors.yellow.shade50,
            ),
            SizedBox(height: iconsLetra * 0.1),
            _empresas == null
                ? const CircularProgressIndicator()
                : _empresas!.isEmpty
                ? const Text('No hay empresas')
                : Container(width: ancho * 0.8,
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(40),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: DropdownButton<String>(
                hint: const Text('Selecciona Empresa'),
                value: selectedEmpresaId,
                onChanged: (String? nuevoId) {
                  setState(() {
                    selectedEmpresaId = nuevoId;
                    _isEmpresaSelected = true;
                  });
                },
                items: _empresas!.map<DropdownMenuItem<String>>((empresa) {
                  return DropdownMenuItem<String>(
                    value: empresa['id'],
                    child: Text(empresa['nombre']),
                  );
                }).toList(),
                icon: Icon(Icons.arrow_drop_down),
                iconSize: iconsLetra * 0.1,
                style: TextStyle(
                  fontSize: iconsLetra * 0.08,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                borderRadius: BorderRadius.circular(40),
                isExpanded: true, // Opcional: para que ocupe todo el ancho del container
              ),
            ),
            SizedBox(height: iconsLetra * 0.2),
            // Botón entrar
            _isEmpresaSelected
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(ancho * 0.5, 50),
                foregroundColor: Theme.of(context).colorScheme.surface,
                backgroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () async {
                await Config().GuardarAlgunDato('empresa_id', selectedEmpresaId!);
                await Config().GuardarAlgunDato('empresa_nombre', _getNombrePorId(selectedEmpresaId!));
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DashBoardUsuario()),
                );
              },
              child: Text(
                'Entrar con ${_getNombrePorId(selectedEmpresaId!)}',
                style: TextStyle(
                  fontSize: iconsLetra * 0.08,
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            )
                : const Text('Para entrar elija una opción'),
          ],
        ),
      ),
    );
  }

  // Helper para obtener el nombre desde el ID
  String _getNombrePorId(String id) {
    final empresa = _empresas?.firstWhere((e) => e['id'] == id, orElse: () => {'nombre': 'Desconocida'});
    return empresa?['nombre'] as String? ?? 'Desconocida';
  }

  Future<void> _cargarEmpresas() async {
    try {
      final empresas = await _getEmpresas();
      if (mounted) {
        setState(() {
          _empresas = empresas;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar empresas: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getEmpresas() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access');

    if (token == null) throw Exception('Token no encontrado');

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/empresa/mis_empresas'),
        headers: {
          "Content-Type": "application/json",
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> datosDecodificados = jsonDecode(response.body);
        return datosDecodificados.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}