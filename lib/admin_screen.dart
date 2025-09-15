import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("Administración de Usuarios"),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Agregar Usuario",
            onPressed: _showAddUserDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar en toda la información...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs.where((user) {
            final data = user.data() as Map<String, dynamic>;

            // 🔎 Construir un string con toda la información del usuario
            String fullText = "";
            data.forEach((key, value) {
              if (value is Map) {
                value.forEach((k, v) {
                  fullText += "$k $v ";
                });
              } else {
                fullText += "$value ";
              }
            });

            // Buscamos también en las colecciones anidadas (notas y servicios)
            // 👉 IMPORTANTE: esto es limitado en local, no en el servidor
            // porque las subcolecciones vienen de streams independientes.
            // Aquí solo preparamos para que funcione cuando carguen.
            fullText = fullText.toLowerCase();

            return fullText.contains(_searchQuery);
          }).toList();

          if (users.isEmpty) {
            return const Center(child: Text("No se encontraron usuarios."));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data = user.data() as Map<String, dynamic>;
              final info = data.containsKey('infoPersonal')
                  ? Map<String, dynamic>.from(data['infoPersonal'])
                  : <String, dynamic>{};

              return Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    "${index + 1}. ${data['nombre'] ?? "Sin nombre"}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Rol: ${data['rol'] ?? "N/A"}"),
                  children: [
                    _sectionCard("Información Personal", [
                      ...info.entries.map((entry) {
                        String displayValue = entry.value.toString();
                        if (entry.value is Timestamp) {
                          displayValue = DateFormat('dd/MM/yyyy')
                              .format(entry.value.toDate());
                        }
                        return ListTile(
                          leading: const Icon(Icons.info),
                          title: Text("${entry.key}: $displayValue"),
                        );
                      }),
                    ], Colors.blue[100]!),
                    _buildServiciosSection(user.id),
                    _buildNotasSection(user.id),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------- Helpers ----------------
  Widget _sectionCard(String title, List<Widget> children, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  // ---------------- Subcolecciones ----------------
  Widget _buildServiciosSection(String userId) {
    return _sectionCard("Servicios", [
      StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('usuarios')
            .doc(userId)
            .collection('servicios')
            .snapshots(),
        builder: (context, serviciosSnapshot) {
          if (!serviciosSnapshot.hasData) return const SizedBox();
          final servicios = serviciosSnapshot.data!.docs;
          if (servicios.isEmpty) return const Text("No hay servicios.");

          return Column(
            children: servicios.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.work),
                title: Text(data['nombre'] ?? "Sin nombre"),
                subtitle: Text(data['descripcion'] ?? ""),
              );
            }).toList(),
          );
        },
      ),
    ], Colors.green[100]!);
  }

  Widget _buildNotasSection(String userId) {
    return _sectionCard("Notas", [
      StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('usuarios')
            .doc(userId)
            .collection('notas')
            .snapshots(),
        builder: (context, notasSnapshot) {
          if (!notasSnapshot.hasData) return const SizedBox();
          final notas = notasSnapshot.data!.docs;
          if (notas.isEmpty) return const Text("No hay notas.");

          return Column(
            children: notas.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.note),
                title: Text(data['nota'] ?? ""),
              );
            }).toList(),
          );
        },
      ),
    ], Colors.yellow[100]!);
  }

  // ---------------- Usuarios ----------------
  void _showAddUserDialog() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController rolController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Usuario"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: "Nombre")),
            TextField(
                controller: rolController,
                decoration: const InputDecoration(labelText: "Rol")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('usuarios').add({
                'nombre': nombreController.text,
                'rol': rolController.text,
                'infoPersonal': {},
              });
              Navigator.pop(context);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }
}
