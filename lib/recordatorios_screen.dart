import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RecordatoriosScreen extends StatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  State<RecordatoriosScreen> createState() => _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends State<RecordatoriosScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recordatorios"),
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
                labelText: "Buscar recordatorio",
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
              stream: db
                  .collection('recordatorios')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final recordatorios = snapshot.data!.docs;

                // Filtrar por búsqueda (titulo o descripcion)
                final filtered = recordatorios.where((r) {
                  final data = r.data() as Map<String, dynamic>;
                  final titulo = (data['titulo'] ?? "").toString().toLowerCase();
                  final descripcion =
                      (data['descripcion'] ?? "").toString().toLowerCase();
                  return titulo.contains(_searchQuery) ||
                      descripcion.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No se encontraron recordatorios."));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final data = r.data() as Map<String, dynamic>;
                    final titulo = data['titulo'] ?? "Sin título";
                    final descripcion = data['descripcion'] ?? "";
                    final fecha = data['fecha'] != null && data['fecha'] is Timestamp
                        ? DateFormat('dd/MM/yyyy – kk:mm')
                            .format((data['fecha'] as Timestamp).toDate())
                        : "";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Text("${index + 1}",
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(descripcion),
                            const SizedBox(height: 6),
                            Text(fecha,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () =>
                                  _showEditRecordatorioDialog(r.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeletion(r.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _showAddRecordatorioDialog,
      ),
    );
  }

  // ---------------- MÉTODOS ----------------
  void _confirmDeletion(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmación"),
        content: const Text("¿Eliminar este recordatorio?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              db.collection('recordatorios').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  void _showAddRecordatorioDialog() {
    final TextEditingController tituloController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController();
    DateTime fecha = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Recordatorio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tituloController, decoration: const InputDecoration(labelText: "Título")),
            TextField(controller: descripcionController, decoration: const InputDecoration(labelText: "Descripción")),
            const SizedBox(height: 8),
            Row(
              children: [
                Text("Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}"),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setState(() => fecha = picked);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('recordatorios').add({
                'titulo': tituloController.text,
                'descripcion': descripcionController.text,
                'fecha': Timestamp.fromDate(fecha),
              });
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _showEditRecordatorioDialog(String id, Map<String, dynamic> data) {
    final TextEditingController tituloController = TextEditingController(text: data['titulo']);
    final TextEditingController descripcionController = TextEditingController(text: data['descripcion']);
    DateTime fecha = data['fecha'] != null && data['fecha'] is Timestamp
        ? (data['fecha'] as Timestamp).toDate()
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Recordatorio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tituloController, decoration: const InputDecoration(labelText: "Título")),
            TextField(controller: descripcionController, decoration: const InputDecoration(labelText: "Descripción")),
            const SizedBox(height: 8),
            Row(
              children: [
                Text("Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}"),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setState(() => fecha = picked);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              db.collection('recordatorios').doc(id).update({
                'titulo': tituloController.text,
                'descripcion': descripcionController.text,
                'fecha': Timestamp.fromDate(fecha),
              });
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}
