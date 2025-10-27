import 'package:flutter/material.dart';

class Cuentacontable extends StatefulWidget {
  @override
  _CuentacontableState createState() => _CuentacontableState();
}

class _CuentacontableState extends State<Cuentacontable> {
  int currentPage = 1;
  bool showAll = false;
  bool showModal = false;

  String? claseSeleccionada;
  List<Map<String, dynamic>> cuentas = [
    {"codigo": "1001", "nombre": "Caja", "estado": "ACTIVO"},
    {"codigo": "2001", "nombre": "Banco", "estado": "INACTIVO"},
  ];

  final TextEditingController codigoCtrl = TextEditingController();
  final TextEditingController nombreCtrl = TextEditingController();
  String estado = "ACTIVO";

  void crearCuenta() {
    setState(() {
      cuentas.add({
        "codigo": codigoCtrl.text,
        "nombre": nombreCtrl.text,
        "estado": estado,
      });
      codigoCtrl.clear();
      nombreCtrl.clear();
      showModal = false;
    });
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
                    const Text("Filtrar por Clase de Cuenta",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() {
                            showAll = true;
                            claseSeleccionada = null;
                          }),
                          child: const Text("Todos"),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            claseSeleccionada == null
                                ? "Mostrando todas las clases"
                                : "Clase: $claseSeleccionada",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Lista de cuentas
            Expanded(
              child: cuentas.isEmpty
                  ? const Center(child: Text("No hay cuentas registradas."))
                  : ListView.builder(
                      itemCount: cuentas.length,
                      itemBuilder: (context, index) {
                        final cuenta = cuentas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text("${cuenta["codigo"]} – ${cuenta["nombre"]}"),
                            subtitle: Text("Estado: ${cuenta["estado"]}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility,
                                  color: Colors.blueAccent),
                              onPressed: () {
                                // Navegar a detalle
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Paginación
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: currentPage > 1
                      ? () => setState(() => currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text("$currentPage"),
                IconButton(
                  onPressed: () => setState(() => currentPage++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
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
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Crear Nueva Cuenta",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: codigoCtrl,
                              decoration:
                                  const InputDecoration(labelText: "Código"),
                            ),
                            TextField(
                              controller: nombreCtrl,
                              decoration:
                                  const InputDecoration(labelText: "Nombre"),
                            ),
                            DropdownButtonFormField<String>(
                              value: estado,
                              onChanged: (v) => setState(() => estado = v!),
                              decoration: const InputDecoration(
                                  labelText: "Estado"),
                              items: const [
                                DropdownMenuItem(
                                    value: "ACTIVO", child: Text("ACTIVO")),
                                DropdownMenuItem(
                                    value: "INACTIVO", child: Text("INACTIVO")),
                                DropdownMenuItem(
                                    value: "CERRADO", child: Text("CERRADO")),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => showModal = false),
                                  child: const Text("Cancelar"),
                                ),
                                ElevatedButton(
                                  onPressed: crearCuenta,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text("Crear"),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ]
          : null,
    );
  }
}
