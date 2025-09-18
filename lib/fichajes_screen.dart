import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FichajesScreen extends StatefulWidget {
  const FichajesScreen({super.key});

  @override
  State<FichajesScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<FichajesScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Administración"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
            onPressed: () {
              Navigator.pushReplacementNamed(context, "/");
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen = constraints.maxWidth > 800;

          if (isWideScreen) {
            return Row(
              children: [
                Expanded(child: _buildUsuariosColumn()),
                Expanded(child: _buildRegistrosColumn("entrada", Colors.green, "Entrada")),
                Expanded(child: _buildRegistrosColumn("salida", Colors.blue, "Salida")),
                Expanded(child: _buildRegistrosColumn("justificacion", Colors.orange, "Justificación")),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildUsuariosColumn(height: 300),
                  _buildRegistrosColumn("entrada", Colors.green, "Entrada", height: 300),
                  _buildRegistrosColumn("salida", Colors.blue, "Salida", height: 300),
                  _buildRegistrosColumn("justificacion", Colors.orange, "Justificación", height: 300),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // --- SECCIÓN DE USUARIOS ---
  Widget _buildUsuariosColumn({double? height}) {
    return Container(
      padding: const EdgeInsets.all(8),
      height: height,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.purple.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "USUARIOS",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.purple),
                  onPressed: _agregarUsuario,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection("fichadores").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("Sin usuarios"));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: ListTile(
                        title: Text(data['nombre'] ?? '-'),
                        subtitle: Text(
                          "Usuario: ${data['usuario'] ?? '-'}\n"
                          "Rol: ${data['rol'] ?? '-'}\n"
                          "Activo: ${data['activo'] == true ? 'Sí' : 'No'}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _editarUsuario(docs[index].id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminarUsuario(docs[index].id),
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
    );
  }

  void _agregarUsuario() async {
    final usuarioController = TextEditingController();
    final nombreController = TextEditingController();
    final rolController = TextEditingController();
    bool activo = true;

    final agregado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Agregar usuario"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
                  TextField(controller: usuarioController, decoration: const InputDecoration(labelText: "Usuario")),
                  TextField(controller: rolController, decoration: const InputDecoration(labelText: "Rol")),
                  Row(
                    children: [
                      const Text("Activo:"),
                      Switch(
                        value: activo,
                        onChanged: (value) => setState(() => activo = value),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Agregar")),
          ],
        );
      },
    );

    if (agregado == true) {
      await db.collection("fichadores").add({
        "nombre": nombreController.text,
        "usuario": usuarioController.text,
        "rol": rolController.text,
        "activo": activo,
      });
    }
  }

  void _editarUsuario(String docId, Map<String, dynamic> data) async {
    final nombreController = TextEditingController(text: data['nombre']);
    final usuarioController = TextEditingController(text: data['usuario']);
    final rolController = TextEditingController(text: data['rol']);
    bool activo = data['activo'] == true;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar usuario"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
                    TextField(controller: usuarioController, decoration: const InputDecoration(labelText: "Usuario")),
                    TextField(controller: rolController, decoration: const InputDecoration(labelText: "Rol")),
                    Row(
                      children: [
                        const Text("Activo:"),
                        Switch(
                          value: activo,
                          onChanged: (value) => setState(() => activo = value),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Guardar")),
          ],
        );
      },
    );

    if (guardado == true) {
      await db.collection("fichadores").doc(docId).update({
        "nombre": nombreController.text,
        "usuario": usuarioController.text,
        "rol": rolController.text,
        "activo": activo,
      });
    }
  }

  void _eliminarUsuario(String docId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar usuario"),
        content: const Text("¿Seguro que quieres eliminar este usuario?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirmado == true) {
      await db.collection("fichadores").doc(docId).delete();
    }
  }

  // --- SECCIÓN DE REGISTROS ---
  Widget _buildRegistrosColumn(String tipoFiltro, Color color, String tituloVisual, {double? height}) {
    return Container(
      padding: const EdgeInsets.all(8),
      height: height,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: color.withOpacity(0.2),
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection("registros").where("tipo", isEqualTo: tipoFiltro).snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Center(
                  child: Text(
                    "${tituloVisual.toUpperCase()} ($count)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection("registros").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final tipo = (data['tipo'] ?? '').toString().toLowerCase();
                  return tipo == tipoFiltro.toLowerCase();
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("Sin registros"));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: ListTile(
                        title: Text("${data['nombre'] ?? '-'} (${data['usuario'] ?? '-'})"),
                        subtitle: Text(
                          "Tipo: ${data['tipo'] ?? '-'}\n"
                          "Fecha: ${data['fecha'] ?? '-'}  Hora: ${data['hora'] ?? '-'}\n"
                          "Justificación: ${data['justificacion'] ?? '-'}",
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _editarRegistro(doc.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminarRegistro(doc.id),
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
    );
  }

  void _editarRegistro(String docId, Map<String, dynamic> data) async {
    final fechaController = TextEditingController(text: data['fecha']);
    final horaController = TextEditingController(text: data['hora']);
    final nombreController = TextEditingController(text: data['nombre']);
    final tipoController = TextEditingController(text: data['tipo']);
    final justificacionController = TextEditingController(text: data['justificacion']);

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar registro"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
                TextField(controller: fechaController, decoration: const InputDecoration(labelText: "Fecha")),
                TextField(controller: horaController, decoration: const InputDecoration(labelText: "Hora")),
                TextField(controller: tipoController, decoration: const InputDecoration(labelText: "Tipo")),
                TextField(controller: justificacionController, decoration: const InputDecoration(labelText: "Justificación")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Guardar")),
          ],
        );
      },
    );

    if (guardado == true) {
      await db.collection("registros").doc(docId).update({
        "nombre": nombreController.text,
        "fecha": fechaController.text,
        "hora": horaController.text,
        "tipo": tipoController.text,
        "justificacion": justificacionController.text,
      });
    }
  }

  void _eliminarRegistro(String docId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar registro"),
        content: const Text("¿Seguro que quieres eliminar este registro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirmado == true) {
      await db.collection("registros").doc(docId).delete();
    }
  }
}
