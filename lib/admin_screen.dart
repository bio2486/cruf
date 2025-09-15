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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs.where((user) {
            final data = user.data() as Map<String, dynamic>;
            String fullText = "";
            data.forEach((key, value) {
              if (value is Map) value.forEach((k, v) => fullText += "$k $v ");
              else fullText += "$value ";
            });
            return fullText.toLowerCase().contains(_searchQuery);
          }).toList();

          if (users.isEmpty) return const Center(child: Text("No se encontraron usuarios."));

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text("${index + 1}. ${data['nombre'] ?? "Sin nombre"}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text("Rol: ${data['rol'] ?? "N/A"}"),
                  children: [
                    _sectionCard("Información Personal", [
                      ...info.entries.map((entry) {
                        String displayValue = entry.value.toString();
                        if (entry.value is Timestamp) displayValue = DateFormat('dd/MM/yyyy').format(entry.value.toDate());
                        return ListTile(
                          leading: const Icon(Icons.info),
                          title: Text("${entry.key}: $displayValue"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _showEditInfoDialog(user.id, entry.key, entry.value)),
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDeletion(
                                      context, "Eliminar campo ${entry.key}?", () {
                                    db.collection('usuarios').doc(user.id).update({
                                      'infoPersonal.${entry.key}': FieldValue.delete()
                                    });
                                  })),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Agregar Información"),
                        onPressed: () => _showAddInfoDialog(user.id),
                      ),
                    ], Colors.blue[100]!),
                    _buildServiciosSection(user.id),
                    _buildNotasSection(user.id),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: "Editar Usuario",
                            onPressed: () => _showEditUserDialog(user)),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: "Eliminar Usuario",
                            onPressed: () => _confirmDeletion(context, "Eliminar este usuario?", () {
                                  db.collection('usuarios').doc(user.id).delete();
                                })),
                      ],
                    ),
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...children,
      ]),
    );
  }

  void _confirmDeletion(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmación"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  // ---------------- CRUD Usuarios ----------------
  void _showAddUserDialog() {
    final nombreController = TextEditingController();
    final rolController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Usuario"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: rolController, decoration: const InputDecoration(labelText: "Rol")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').add({'nombre': nombreController.text, 'rol': rolController.text, 'infoPersonal': {}});
                Navigator.pop(context);
              },
              child: const Text("Agregar")),
        ],
      ),
    );
  }

  void _showEditUserDialog(QueryDocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final nombreController = TextEditingController(text: data['nombre']);
    final rolController = TextEditingController(text: data['rol']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Usuario"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: rolController, decoration: const InputDecoration(labelText: "Rol")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(user.id).update({'nombre': nombreController.text, 'rol': rolController.text});
                Navigator.pop(context);
              },
              child: const Text("Guardar")),
        ],
      ),
    );
  }

  // ---------------- CRUD InfoPersonal ----------------
  void _showAddInfoDialog(String userId) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Información"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: keyController, decoration: const InputDecoration(labelText: "Campo")),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: "Valor")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(userId).update({'infoPersonal.${keyController.text}': valueController.text});
                Navigator.pop(context);
              },
              child: const Text("Agregar")),
        ],
      ),
    );
  }

  void _showEditInfoDialog(String userId, String key, dynamic value) {
    final valueController = TextEditingController(text: value.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar $key"),
        content: TextField(controller: valueController, decoration: const InputDecoration(labelText: "Valor")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(userId).update({'infoPersonal.$key': valueController.text});
                Navigator.pop(context);
              },
              child: const Text("Guardar")),
        ],
      ),
    );
  }

  // ---------------- Subcolecciones Servicios ----------------
  Widget _buildServiciosSection(String userId) {
    return _sectionCard("Servicios", [
      StreamBuilder<QuerySnapshot>(
        stream: db.collection('usuarios').doc(userId).collection('servicios').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final servicios = snapshot.data!.docs;

          return Column(
            children: [
              ...servicios.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fecha = data['fecha'] != null ? DateFormat('dd/MM/yyyy').format((data['fecha'] as Timestamp).toDate()) : "";
                return ListTile(
                  leading: const Icon(Icons.work),
                  title: Text(data['nombre'] ?? "Sin nombre"),
                  subtitle: Text("${data['descripcion'] ?? ""} $fecha"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showEditServiceDialog(userId, doc.id, data)),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeletion(context, "Eliminar este servicio?", () {
                                db.collection('usuarios').doc(userId).collection('servicios').doc(doc.id).delete();
                              })),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar Servicio"),
                  onPressed: () => _showAddServiceDialog(userId)),
            ],
          );
        },
      ),
    ], Colors.green[100]!);
  }

  void _showAddServiceDialog(String userId) {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Servicio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: descripcionController, decoration: const InputDecoration(labelText: "Descripción")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(userId).collection('servicios').add({
                  'nombre': nombreController.text,
                  'descripcion': descripcionController.text,
                  'fecha': Timestamp.now(),
                });
                Navigator.pop(context);
              },
              child: const Text("Agregar")),
        ],
      ),
    );
  }

  void _showEditServiceDialog(String userId, String serviceId, Map<String, dynamic> data) {
    final nombreController = TextEditingController(text: data['nombre']);
    final descripcionController = TextEditingController(text: data['descripcion']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Servicio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: descripcionController, decoration: const InputDecoration(labelText: "Descripción")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(userId).collection('servicios').doc(serviceId).update({
                  'nombre': nombreController.text,
                  'descripcion': descripcionController.text,
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar")),
        ],
      ),
    );
  }

  // ---------------- Subcolecciones Notas ----------------
  Widget _buildNotasSection(String userId) {
    return _sectionCard("Notas", [
      StreamBuilder<QuerySnapshot>(
        stream: db.collection('usuarios').doc(userId).collection('notas').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final notas = snapshot.data!.docs;

          return Column(
            children: [
              ...notas.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fecha = data['fecha'] != null ? DateFormat('dd/MM/yyyy – kk:mm').format((data['fecha'] as Timestamp).toDate()) : "";
                return ListTile(
                  leading: const Icon(Icons.note),
                  title: Text(data['nota'] ?? ""),
                  subtitle: Text(fecha),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showEditNoteDialog(userId, doc.id, data)),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeletion(context, "Eliminar esta nota?", () {
                                db.collection('usuarios').doc(userId).collection('notas').doc(doc.id).delete();
                              })),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar Nota"),
                  onPressed: () => _showAddNoteDialog(userId)),
            ],
          );
        },
      ),
    ], Colors.yellow[100]!);
  }

  void _showAddNoteDialog(String userId) {
    final notaController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Nota"),
        content: TextField(controller: notaController, decoration: const InputDecoration(labelText: "Nota")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(userId).collection('notas').add({
                  'nota': notaController.text,
                  'fecha': Timestamp.now(),
                });
                Navigator.pop(context);
              },
              child: const Text("Agregar")),
        ],
      ),
    );
  }

  void _showEditNoteDialog(String userId, String noteId, Map<String, dynamic> data) {
    final notaController = TextEditingController(text: data['nota']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Nota"),
        content: TextField(controller: notaController, decoration: const InputDecoration(labelText: "Nota")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                db.collection('usuarios').doc(userId).collection('notas').doc(noteId).update({
                  'nota': notaController.text,
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar")),
        ],
      ),
    );
  }
}
