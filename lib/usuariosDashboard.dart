import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UsuariosDetalleScreen extends StatefulWidget {
  const UsuariosDetalleScreen({super.key});

  @override
  State<UsuariosDetalleScreen> createState() => _UsuariosDetalleScreenState();
}

class _UsuariosDetalleScreenState extends State<UsuariosDetalleScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _searchQuery = ""; // 🔹 Texto del buscador

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de Usuarios"),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔹 Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Buscar en la tabla",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;

                if (users.isEmpty) {
                  return const Center(child: Text("No hay usuarios."));
                }

                // 🔹 Filtrar según búsqueda
                final filteredUsers = users.where((user) {
                  final data = user.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? "").toString().toLowerCase();
                  final email = (data['email'] ?? "").toString().toLowerCase();
                  final rol = (data['rol'] ?? "").toString().toLowerCase();
                  final infoPersonal = (data['infoPersonal'] ?? {}).toString().toLowerCase();

                  return nombre.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      rol.contains(_searchQuery) ||
                      infoPersonal.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text("No se encontraron usuarios."));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    dataRowMinHeight: 70,   // altura mínima
                    dataRowMaxHeight: 200,  // altura máxima (para info larga)
                    columns: const [
                      DataColumn(label: Text("Nombre", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Rol", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Activo", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Info Personal", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Notas", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Servicios", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredUsers.map((user) {
                      final data = user.data() as Map<String, dynamic>;
                      final info = (data['infoPersonal'] ?? {}) as Map<String, dynamic>;

                      // Convertimos todo el map de infoPersonal en texto legible
                      String infoPersonalText = "-";
                      if (info.isNotEmpty) {
                        infoPersonalText = info.entries.map((e) {
                          if (e.value is Timestamp) {
                            return "${e.key}: ${DateFormat('dd/MM/yyyy').format((e.value as Timestamp).toDate())}";
                          }
                          return "${e.key}: ${e.value}";
                        }).join("\n");
                      }

                      return DataRow(cells: [
                        DataCell(Text(data['nombre'] ?? "-")),
                        DataCell(Text(data['rol'] ?? "-")),
                        DataCell(Text((data['activo'] ?? true) ? "Sí" : "No")),
                        DataCell(Text(data['email']?.toString() ?? "-")),
                        DataCell(Text(infoPersonalText)), // 👈 Mostrar todo el map
                        DataCell(
                          FutureBuilder<QuerySnapshot>(
                            future: db
                                .collection('usuarios')
                                .doc(user.id)
                                .collection('notas')
                                .orderBy('fecha', descending: true)
                                .get(),
                            builder: (context, notaSnapshot) {
                              if (!notaSnapshot.hasData) return const Text("-");
                              final notas = notaSnapshot.data!.docs;
                              return Text(
                                notas.isEmpty
                                    ? "-"
                                    : notas.map((n) => n['nota'] ?? "").join("\n"),
                              );
                            },
                          ),
                        ),
                        DataCell(
                          FutureBuilder<QuerySnapshot>(
                            future: db
                                .collection('usuarios')
                                .doc(user.id)
                                .collection('servicios')
                                .orderBy('fecha')
                                .get(),
                            builder: (context, serviciosSnapshot) {
                              if (!serviciosSnapshot.hasData) return const Text("-");
                              final servicios = serviciosSnapshot.data!.docs;
                              return Text(
                                servicios.isEmpty
                                    ? "-"
                                    : servicios.map((s) {
                                        final sData = s.data() as Map<String, dynamic>;
                                        String fecha = "";
                                        if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
                                          fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
                                        }
                                        return "${sData['nombre'] ?? ''} ($fecha)";
                                      }).join("\n"),
                              );
                            },
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
