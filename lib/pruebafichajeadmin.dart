import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FichajesScreen extends StatefulWidget {
  const FichajesScreen({super.key});

  @override
  State<FichajesScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<FichajesScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // Controladores para los buscadores
  TextEditingController usuarioSearchController = TextEditingController();
  TextEditingController registroSearchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: "Usuarios"),
              Tab(text: "Registros"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsuariosColumn(),
            _buildTrabajadoresColumn(),
          ],
        ),
      ),
    );
  }

  // --- SECCIÓN DE USUARIOS ---
  Widget _buildUsuariosColumn() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Buscador por nombre o rol
          TextField(
            controller: usuarioSearchController,
            decoration: const InputDecoration(
              labelText: "Buscar por nombre o rol",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.purple.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "USUARIOS",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
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
                var docs = snapshot.data!.docs;

                // Filtrar por buscador
                final query = usuarioSearchController.text.toLowerCase();
                if (query.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                    final rol = (data['rol'] ?? '').toString().toLowerCase();
                    return nombre.contains(query) || rol.contains(query);
                  }).toList();
                }

                if (docs.isEmpty) return const Center(child: Text("Sin usuarios"));

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text("Nombre")),
                          DataColumn(label: Text("Usuario")),
                          DataColumn(label: Text("Rol")),
                          DataColumn(label: Text("Activo")),
                          DataColumn(label: Text("Acciones")),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text(data['nombre'] ?? '-')),
                            DataCell(Text(data['usuario'] ?? '-')),
                            DataCell(Text(data['rol'] ?? '-')),
                            DataCell(Text(data['activo'] == true ? 'Sí' : 'No')),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                  onPressed: () => _editarUsuario(doc.id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _eliminarUsuario(doc.id),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN DE TRABAJADORES (Registros) ---
  Widget _buildTrabajadoresColumn() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Buscador por nombre o tipo
          TextField(
            controller: registroSearchController,
            decoration: const InputDecoration(
              labelText: "Buscar por nombre o tipo",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.withOpacity(0.2),
            child: const Center(
              child: Text(
                "TRABAJADORES",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection("registros").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;

                // Filtrar por buscador
                final query = registroSearchController.text.toLowerCase();
                if (query.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                    final tipo = (data['tipo'] ?? '').toString().toLowerCase();
                    return nombre.contains(query) || tipo.contains(query);
                  }).toList();
                }

                if (docs.isEmpty) return const Center(child: Text("Sin registros"));

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text("Nombre")),
                          DataColumn(label: Text("Usuario")),
                          DataColumn(label: Text("Tipo")),
                          DataColumn(label: Text("Fecha")),
                          DataColumn(label: Text("Hora")),
                          DataColumn(label: Text("Justificación")),
                          DataColumn(label: Text("Firma URL")),
                          DataColumn(label: Text("Acciones")),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text(data['nombre'] ?? '-')),
                            DataCell(Text(data['usuario'] ?? '-')),
                            DataCell(Text(data['tipo'] ?? '-')),
                            DataCell(Text(data['fecha'] ?? '-')),
                            DataCell(Text(data['hora'] ?? '-')),
                            DataCell(Text(data['justificacion'] ?? '-')),
                            DataCell(
                              Container(
                                width: 100,
                                child: Text(
                                  data['firmaUrl'] ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                  onPressed: () => _editarRegistro(doc.id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _eliminarRegistro(doc.id),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Funciones de Usuarios ---
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

  // --- Funciones de Registros ---
  void _editarRegistro(String docId, Map<String, dynamic> data) async {
    final fechaController = TextEditingController(text: data['fecha']);
    final horaController = TextEditingController(text: data['hora']);
    final nombreController = TextEditingController(text: data['nombre']);
    final tipoController = TextEditingController(text: data['tipo']);
    final justificacionController = TextEditingController(text: data['justificacion']);
    final firmaController = TextEditingController(text: data['firmaUrl']);

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
                TextField(controller: firmaController, decoration: const InputDecoration(labelText: "Firma URL")),
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
        "firmaUrl": firmaController.text,
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
