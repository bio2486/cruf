import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TrabajadoresScreen extends StatefulWidget {
  const TrabajadoresScreen({super.key});

  @override
  State<TrabajadoresScreen> createState() => _TrabajadoresScreenState();
}

class _TrabajadoresScreenState extends State<TrabajadoresScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: db.collection('trabajadores').snapshots(),
          builder: (context, snapshot) {
            final total = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text("Administración de Trabajadores ($total)");
          },
        ),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Agregar Trabajador",
            onPressed: _showAddWorkerDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar trabajador por nombre o rol...",
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
        stream: db.collection('trabajadores').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final workers = snapshot.data!.docs.where((worker) {
            final data = worker.data() as Map<String, dynamic>;
            final nombre = (data['nombre'] ?? "").toString().toLowerCase();
            final rol = (data['rol'] ?? "").toString().toLowerCase();
            return nombre.contains(_searchQuery) ||
                rol.contains(_searchQuery);
          }).toList();

          if (workers.isEmpty) {
            return const Center(child: Text("No se encontraron trabajadores."));
          }

          return ListView.builder(
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];
              final data = worker.data() as Map<String, dynamic>;
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
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  title: Text(
                    "${index + 1}. ${data['nombre'] ?? "Sin nombre"}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Rol: ${data['rol'] ?? "N/A"}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  children: [
                    // Info personal
                    _sectionCard("Información Personal", [
                      ...info.entries.map((entry) {
                        final value = entry.value;
                        String displayValue = value.toString();
                        if (value is Timestamp) {
                          displayValue =
                              DateFormat('dd/MM/yyyy').format(value.toDate());
                        } else if (value is bool) {
                          displayValue = value ? "Verdadero" : "Falso";
                        }

                        return ListTile(
                          leading: const Icon(Icons.info),
                          title: Text("${entry.key}: $displayValue"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.orange),
                                onPressed: () => _showEditInfoDialog(
                                    worker.id, entry.key, entry.value),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () => _confirmDeletion(
                                    context,
                                    "Eliminar campo ${entry.key}?",
                                    () {
                                  db
                                      .collection('trabajadores')
                                      .doc(worker.id)
                                      .update({
                                    'infoPersonal.${entry.key}':
                                        FieldValue.delete()
                                  });
                                }),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Agregar Información"),
                        onPressed: () => _showAddInfoDialog(worker.id),
                      ),
                    ], Colors.green[100]!),

                    // Servicios
                    _buildServiciosSection(worker.id),

                    // Notas
                    _buildNotasSection(worker.id),

                    // Editar / Eliminar trabajador
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: "Editar Trabajador",
                          onPressed: () => _showEditWorkerDialog(worker),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Eliminar Trabajador",
                          onPressed: () => _confirmDeletion(
                              context, "Eliminar este trabajador?", () {
                            db.collection('trabajadores').doc(worker.id).delete();
                          }),
                        ),
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

  void _confirmDeletion(
      BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmación"),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
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

  // ---------------- CRUD Trabajadores ----------------
  void _showAddWorkerDialog() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController rolController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Trabajador"),
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
              db.collection('trabajadores').add({
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

  void _showEditWorkerDialog(QueryDocumentSnapshot worker) {
    final data = worker.data() as Map<String, dynamic>;
    final TextEditingController nombreController =
        TextEditingController(text: data['nombre'] ?? "");
    final TextEditingController rolController =
        TextEditingController(text: data['rol'] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Trabajador"),
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
              db.collection('trabajadores').doc(worker.id).update({
                'nombre': nombreController.text,
                'rol': rolController.text,
              });
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ---------------- CRUD InfoPersonal ----------------
  void _showAddInfoDialog(String workerId) {
    final TextEditingController keyController = TextEditingController();
    final TextEditingController valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Información"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: "Campo")),
            TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: "Valor")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('trabajadores').doc(workerId).update({
                'infoPersonal.${keyController.text}': valueController.text
              });
              Navigator.pop(context);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _showEditInfoDialog(String workerId, String key, dynamic value) {
    final TextEditingController valueController =
        TextEditingController(text: value.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar $key"),
        content: TextField(
            controller: valueController,
            decoration: const InputDecoration(labelText: "Valor")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('trabajadores').doc(workerId).update({
                'infoPersonal.$key': valueController.text
              });
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ---------------- CRUD Servicios ----------------
  Widget _buildServiciosSection(String workerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('trabajadores')
          .doc(workerId)
          .collection('servicios')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final servicios = snapshot.data!.docs;

        return _sectionCard("Servicios", [
          ...servicios.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fecha = data['fecha'] != null
                ? DateFormat('dd/MM/yyyy')
                    .format((data['fecha'] as Timestamp).toDate())
                : "";

            return ListTile(
              leading: const Icon(Icons.work),
              title: Text(data['nombre'] ?? "Sin nombre"),
              subtitle: Text("${data['descripcion'] ?? ""} $fecha"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () =>
                          _showEditServiceDialog(workerId, doc.id, data)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeletion(
                          context, "Eliminar este servicio?", () {
                        db
                            .collection('trabajadores')
                            .doc(workerId)
                            .collection('servicios')
                            .doc(doc.id)
                            .delete();
                      })),
                ],
              ),
            );
          }),
          TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Agregar Servicio"),
              onPressed: () => _showAddServiceDialog(workerId)),
        ], Colors.blue[100]!);
      },
    );
  }

  void _showAddServiceDialog(String workerId) {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Servicio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: "Nombre")),
            TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: "Descripción")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db
                  .collection('trabajadores')
                  .doc(workerId)
                  .collection('servicios')
                  .add({
                'nombre': nombreController.text,
                'descripcion': descripcionController.text,
                'fecha': Timestamp.now(),
              });
              Navigator.pop(context);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _showEditServiceDialog(
      String workerId, String servicioId, Map<String, dynamic> data) {
    final TextEditingController nombreController =
        TextEditingController(text: data['nombre'] ?? "");
    final TextEditingController descripcionController =
        TextEditingController(text: data['descripcion'] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Servicio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: "Nombre")),
            TextField(
                controller: descripcionController,
                decoration: const InputDecoration(labelText: "Descripción")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db
                  .collection('trabajadores')
                  .doc(workerId)
                  .collection('servicios')
                  .doc(servicioId)
                  .update({
                'nombre': nombreController.text,
                'descripcion': descripcionController.text,
              });
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ---------------- CRUD Notas ----------------
  Widget _buildNotasSection(String workerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('trabajadores')
          .doc(workerId)
          .collection('notas')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final notas = snapshot.data!.docs;

        return _sectionCard("Notas", [
          ...notas.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fecha = data['fecha'] != null
                ? DateFormat('dd/MM/yyyy – kk:mm')
                    .format((data['fecha'] as Timestamp).toDate())
                : "";

            return ListTile(
              leading: const Icon(Icons.note),
              title: Text(data['nota'] ?? ""),
              subtitle: Text(fecha),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () =>
                          _showEditNoteDialog(workerId, doc.id, data)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeletion(
                          context, "Eliminar esta nota?", () {
                        db
                            .collection('trabajadores')
                            .doc(workerId)
                            .collection('notas')
                            .doc(doc.id)
                            .delete();
                      })),
                ],
              ),
            );
          }),
          TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Agregar Nota"),
              onPressed: () => _showAddNoteDialog(workerId)),
        ], Colors.yellow[100]!);
      },
    );
  }

  void _showAddNoteDialog(String workerId) {
    final TextEditingController notaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Nota"),
        content: TextField(
            controller: notaController,
            decoration: const InputDecoration(labelText: "Nota")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('trabajadores').doc(workerId).collection('notas').add({
                'nota': notaController.text,
                'fecha': Timestamp.now(),
              });
              Navigator.pop(context);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog(
      String workerId, String noteId, Map<String, dynamic> data) {
    final TextEditingController notaController =
        TextEditingController(text: data['nota'] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Nota"),
        content: TextField(
            controller: notaController,
            decoration: const InputDecoration(labelText: "Nota")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('trabajadores')
                  .doc(workerId)
                  .collection('notas')
                  .doc(noteId)
                  .update({'nota': notaController.text});
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}
