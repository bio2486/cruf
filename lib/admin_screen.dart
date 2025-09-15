import 'dart:async';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value.toLowerCase();
      });
    });
  }

  // -------------------- Búsqueda --------------------
  Future<Map<String, dynamic>> _getUserFullData(QueryDocumentSnapshot user) async {
    final data = user.data() as Map<String, dynamic>;
    final Map<String, dynamic> fullData = Map.from(data);
    fullData['id'] = user.id;

    // Subcolección servicios
    final serviciosSnap = await db
        .collection('usuarios')
        .doc(user.id)
        .collection('servicios')
        .get();
    fullData['servicios'] = serviciosSnap.docs.map((d) => d.data()).toList();

    // Subcolección notas
    final notasSnap = await db
        .collection('usuarios')
        .doc(user.id)
        .collection('notas')
        .get();
    fullData['notas'] = notasSnap.docs.map((d) => d.data()).toList();

    return fullData;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    String fullText = "";

    // infoPersonal
    if (data['infoPersonal'] != null && data['infoPersonal'] is Map) {
      (data['infoPersonal'] as Map).forEach((k, v) {
        fullText += "$k $v ";
      });
    }

    // campos principales
    data.forEach((k, v) {
      if (v is String || v is num) fullText += "$v ";
    });

    // servicios
    if (data['servicios'] != null && data['servicios'] is List) {
      for (var s in data['servicios']) {
        if (s is Map) s.forEach((k, v) => fullText += "$k $v ");
      }
    }

    // notas
    if (data['notas'] != null && data['notas'] is List) {
      for (var n in data['notas']) {
        if (n is Map) n.forEach((k, v) => fullText += "$k $v ");
      }
    }

    return fullText.toLowerCase().contains(_searchQuery);
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: db.collection('usuarios').snapshots(),
          builder: (context, snapshot) {
            final total = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text("Administración de Usuarios ($total)");
          },
        ),
        backgroundColor: Colors.blueAccent,
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
                          _searchController.clear();
                          _onSearchChanged("");
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
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allUsers = snapshot.data!.docs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(allUsers.map(_getUserFullData)),
            builder: (context, snapshotFull) {
              if (!snapshotFull.hasData) return const Center(child: CircularProgressIndicator());

              final usersData = snapshotFull.data!;
              final filteredUsers = usersData.where(_matchesSearch).toList();

              if (filteredUsers.isEmpty) {
                return const Center(child: Text("No se encontraron usuarios."));
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final data = filteredUsers[index];
                  final info = data['infoPersonal'] != null
                      ? Map<String, dynamic>.from(data['infoPersonal'])
                      : <String, dynamic>{};
                  final userId = data['id'];

                  return Card(
                    margin: const EdgeInsets.all(12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        "${index + 1}. ${data['nombre'] ?? "Sin nombre"}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Rol: ${data['rol'] ?? "N/A"}"),
                      children: [
                        _sectionCard("Información Personal", [
                          ...info.entries.map((entry) {
                            String displayValue = entry.value.toString();
                            if (entry.value is Timestamp) {
                              displayValue = DateFormat('dd/MM/yyyy').format(entry.value.toDate());
                            }
                            return ListTile(
                              leading: const Icon(Icons.info),
                              title: Text("${entry.key}: $displayValue"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.orange),
                                      onPressed: () => _showEditInfoDialog(userId, entry.key, entry.value)),
                                  IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _confirmDeletion(
                                          context, "Eliminar campo ${entry.key}?", () {
                                        db.collection('usuarios').doc(userId).update({
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
                            onPressed: () => _showAddInfoDialog(userId),
                          ),
                        ], Colors.blue[100]!),
                        _buildServiciosSection(userId),
                        _buildNotasSection(userId),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: "Editar Usuario",
                                onPressed: () => _showEditUserDialog(userId, data)),
                            IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: "Eliminar Usuario",
                                onPressed: () => _confirmDeletion(context, "Eliminar este usuario?", () {
                                  db.collection('usuarios').doc(userId).delete();
                                })),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // -------------------- Helpers --------------------
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
              child: const Text("Eliminar")),
        ],
      ),
    );
  }

  // -------------------- CRUD Usuarios --------------------
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
                db.collection('usuarios').add({
                  'nombre': nombreController.text,
                  'rol': rolController.text,
                  'infoPersonal': {}
                });
                Navigator.pop(context);
              },
              child: const Text("Agregar")),
        ],
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> data) {
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
                db.collection('usuarios').doc(userId).update({
                  'nombre': nombreController.text,
                  'rol': rolController.text
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar")),
        ],
      ),
    );
  }

  // -------------------- CRUD InfoPersonal --------------------
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
                db.collection('usuarios').doc(userId).update({
                  'infoPersonal.${keyController.text}': valueController.text
                });
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
                db.collection('usuarios').doc(userId).update({
                  'infoPersonal.$key': valueController.text
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar")),
        ],
      ),
    );
  }

  // -------------------- CRUD Servicios --------------------
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
                final sData = doc.data() as Map<String, dynamic>;
                final fecha = sData['fecha'] != null
                    ? DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate())
                    : "";
                return ListTile(
                  leading: const Icon(Icons.work),
                  title: Text(sData['nombre'] ?? "Sin nombre"),
                  subtitle: Text("${sData['descripcion'] ?? ""} $fecha"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showEditServiceDialog(userId, doc.id, sData)),
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
      )
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

  // -------------------- CRUD Notas --------------------
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
                final nData = doc.data() as Map<String, dynamic>;
                final fecha = nData['fecha'] != null
                    ? DateFormat('dd/MM/yyyy – kk:mm').format((nData['fecha'] as Timestamp).toDate())
                    : "";
                return ListTile(
                  leading: const Icon(Icons.note),
                  title: Text(nData['nota'] ?? ""),
                  subtitle: Text(fecha),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showEditNoteDialog(userId, doc.id, nData)),
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
      )
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
