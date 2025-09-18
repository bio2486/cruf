import 'dart:io'; 
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:html' as html; // Solo Web

class UsuariosDashboard extends StatefulWidget {
  const UsuariosDashboard({super.key});

  @override
  State<UsuariosDashboard> createState() => _UsuariosDashboardState();
}

class _UsuariosDashboardState extends State<UsuariosDashboard> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: db.collection('usuarios').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("Detalle de Usuarios");
            final total = snapshot.data!.docs.length;
            return Text(
              "Detalle de Usuarios  |  Total: $total",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
        ),
        backgroundColor: const Color.fromARGB(255, 11, 158, 244),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: "Añadir usuario", onPressed: _crearUsuario),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pdf') _exportPdf();
              if (value == 'excel') _exportExcel();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Exportar a PDF')),
              const PopupMenuItem(value: 'excel', child: Text('Exportar a Excel')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Buscar en la tabla",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ""))
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final usuarios = snapshot.data!.docs;
                if (usuarios.isEmpty) return const Center(child: Text("No hay usuarios."));

                // --- Aquí hacemos una lectura (solo para búsqueda) de las subcolecciones servicios y notas
                //     No se modifica ninguna lógica de CRUD ni se toca el resto del código.
                final futures = usuarios.map((usuario) async {
                  final data = usuario.data() as Map<String, dynamic>;

                  // Info personal transformada a texto para búsqueda
                  final infoMap = (data['infoPersonal'] ?? {}) as Map<String, dynamic>;
                  final infoPersonalText = infoMap.isNotEmpty
                      ? infoMap.entries.map((e) {
                          final v = e.value;
                          if (v is Timestamp) {
                            return "${e.key}: ${DateFormat('dd/MM/yyyy').format(v.toDate())}";
                          }
                          return "${e.key}: ${v?.toString() ?? ''}";
                        }).join(" | ")
                      : "";

                  // Obtener servicios (solo para indexar en la búsqueda)
                  final serviciosSnapshot = await db
                      .collection('usuarios')
                      .doc(usuario.id)
                      .collection('servicios')
                      .orderBy('fecha')
                      .get();
                  final serviciosText = serviciosSnapshot.docs.isEmpty
                      ? ""
                      : serviciosSnapshot.docs.map((s) {
                          final sData = s.data() as Map<String, dynamic>;
                          String fecha = "";
                          if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
                            fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
                          }
                          return "${sData['nombre'] ?? ''} $fecha".trim();
                        }).join(" | ");

                  // Obtener notas (solo para indexar en la búsqueda)
                  final notasSnapshot = await db
                      .collection('usuarios')
                      .doc(usuario.id)
                      .collection('notas')
                      .orderBy('fecha', descending: true)
                      .get();
                  final notasText = notasSnapshot.docs.isEmpty
                      ? ""
                      : notasSnapshot.docs.map((n) {
                          final nData = n.data() as Map<String, dynamic>;
                          return nData['nota']?.toString() ?? "";
                        }).join(" | ");

                  return {
                    'doc': usuario,
                    'data': data,
                    'infoPersonalText': infoPersonalText.toLowerCase(),
                    'serviciosText': serviciosText.toLowerCase(),
                    'notasText': notasText.toLowerCase(),
                  };
                }).toList();

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: Future.wait(futures),
                  builder: (context, enrichedSnapshot) {
                    if (!enrichedSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final enriched = enrichedSnapshot.data!;

                    // Filtrar por nombre, rol, infoPersonal, servicios y notas
                    final filtered = enriched.where((e) {
                      final data = e['data'] as Map<String, dynamic>;
                      final nombre = (data['nombre'] ?? "").toString().toLowerCase();
                      final rol = (data['rol'] ?? "").toString().toLowerCase();
                      final infoPersonalText = (e['infoPersonalText'] ?? "").toString();
                      final serviciosText = (e['serviciosText'] ?? "").toString();
                      final notasText = (e['notasText'] ?? "").toString();

                      final q = _searchQuery;
                      if (q.isEmpty) return true;

                      return nombre.contains(q) ||
                          rol.contains(q) ||
                          infoPersonalText.contains(q) ||
                          serviciosText.contains(q) ||
                          notasText.contains(q);
                    }).toList();

                    if (filtered.isEmpty) return const Center(child: Text("No hay usuarios que coincidan con la búsqueda."));

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columnSpacing: 20,
                            dataRowMinHeight: 70,
                            dataRowMaxHeight: 100,
                            columns: const [
                              DataColumn(label: Text("N°", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Nombre", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Rol", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Info Personal", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Servicios", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Notas", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Acciones", style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: List.generate(filtered.length, (index) {
                              final item = filtered[index];
                              final usuario = item['doc'] as QueryDocumentSnapshot;
                              final data = item['data'] as Map<String, dynamic>;
                              final info = (data['infoPersonal'] ?? {}) as Map<String, dynamic>;
                              String infoPersonalText = info.isNotEmpty
                                  ? info.entries.map((e) => e.value is Timestamp
                                      ? "${e.key}: ${DateFormat('dd/MM/yyyy').format((e.value as Timestamp).toDate())}"
                                      : "${e.key}: ${e.value}").join("\n")
                                  : "-";

                              return DataRow(cells: [
                                DataCell(Text("${index + 1}")),
                                DataCell(Text(data['nombre'] ?? "-")),
                                DataCell(Text(data['rol'] ?? "-")),
                                DataCell(Text(infoPersonalText)),
                                DataCell(StreamBuilder<QuerySnapshot>(
                                  stream: db.collection('usuarios').doc(usuario.id).collection('servicios').orderBy('fecha').snapshots(),
                                  builder: (context, serviciosSnapshot) {
                                    if (!serviciosSnapshot.hasData) return const Text("-");
                                    final servicios = serviciosSnapshot.data!.docs;
                                    return Text(servicios.isEmpty
                                        ? "-"
                                        : servicios.map((s) {
                                            final sData = s.data() as Map<String, dynamic>;
                                            String fecha = "";
                                            if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
                                              fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
                                            }
                                            return "${sData['nombre'] ?? ''} ($fecha)";
                                          }).join("\n"));
                                  },
                                )),
                                DataCell(StreamBuilder<QuerySnapshot>(
                                  stream: db.collection('usuarios').doc(usuario.id).collection('notas').orderBy('fecha', descending: true).snapshots(),
                                  builder: (context, notaSnapshot) {
                                    if (!notaSnapshot.hasData) return const Text("-");
                                    final notas = notaSnapshot.data!.docs;
                                    return Text(notas.isEmpty ? "-" : notas.map((n) => n['nota'] ?? "").join("\n"));
                                  },
                                )),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editarUsuario(usuario.id, data),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Confirmar eliminación"),
                                            content: Text("¿Seguro que deseas eliminar a ${data['nombre']}?"),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar")),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await db.collection('usuarios').doc(usuario.id).delete();
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario eliminado")));
                                        }
                                      },
                                    ),
                                  ],
                                )),
                              ]);
                            }),
                          ),
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

  // Crear usuario
  void _crearUsuario() {
    _abrirFormulario();
  }

  // Editar usuario
  void _editarUsuario(String id, Map<String, dynamic> data) {
    _abrirFormulario(id: id, data: data);
  }

  // Formulario crear/editar con CRUD completo de infoPersonal, servicios y notas
  void _abrirFormulario({String? id, Map<String, dynamic>? data}) async {
    final nombreController = TextEditingController(text: data?['nombre']);
    final rolController = TextEditingController(text: data?['rol']);

    // Listas de infoPersonal, servicios y notas
    List<Map<String, dynamic>> infoPersonal = [];
    List<Map<String, dynamic>> servicios = [];
    List<Map<String, dynamic>> notas = [];

    if (id != null) {
      final info = (data?['infoPersonal'] ?? {}) as Map<String, dynamic>;
      infoPersonal = info.entries.map((e) => {"key": e.key, "value": e.value}).toList();

      final serviciosSnapshot = await db.collection('usuarios').doc(id).collection('servicios').orderBy('fecha').get();
      servicios = serviciosSnapshot.docs.map((s) => {"id": s.id, "nombre": s['nombre'], "fecha": (s['fecha'] as Timestamp).toDate()}).toList();

      final notasSnapshot = await db.collection('usuarios').doc(id).collection('notas').orderBy('fecha', descending: true).get();
      notas = notasSnapshot.docs.map((n) => {"id": n.id, "nota": n['nota'], "fecha": (n['fecha'] as Timestamp).toDate()}).toList();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(id == null ? "Nuevo usuario" : "Editar usuario"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
                  TextField(controller: rolController, decoration: const InputDecoration(labelText: "Rol")),
                  const SizedBox(height: 20),
                  const Text("Info Personal", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...infoPersonal.map((info) {
                    final keyCtrl = TextEditingController(text: info['key']);
                    final valueCtrl = TextEditingController(text: info['value']?.toString() ?? "");
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: keyCtrl,
                            decoration: const InputDecoration(labelText: "Campo"),
                            onChanged: (v) => info['key'] = v,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: valueCtrl,
                            decoration: const InputDecoration(labelText: "Valor"),
                            onChanged: (v) => info['value'] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => infoPersonal.remove(info)),
                        ),
                      ],
                    );
                  }),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Añadir info personal"),
                    onPressed: () => setState(() => infoPersonal.add({"key": "", "value": ""})),
                  ),
                  const SizedBox(height: 20),
                  const Text("Servicios", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...servicios.map((s) {
                    final nombreCtrl = TextEditingController(text: s["nombre"]);
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nombreCtrl,
                            decoration: const InputDecoration(labelText: "Servicio"),
                            onChanged: (v) => s["nombre"] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: s["fecha"] ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => s["fecha"] = picked);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => servicios.remove(s));
                            if (id != null && s["id"] != null) db.collection('usuarios').doc(id).collection('servicios').doc(s["id"]).delete();
                          },
                        ),
                      ],
                    );
                  }),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Añadir servicio"),
                    onPressed: () => setState(() => servicios.add({"nombre": "", "fecha": DateTime.now()})),
                  ),
                  const SizedBox(height: 20),
                  const Text("Notas", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...notas.map((n) {
                    final notaCtrl = TextEditingController(text: n["nota"]);
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: notaCtrl,
                            decoration: const InputDecoration(labelText: "Nota"),
                            onChanged: (v) => n["nota"] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => notas.remove(n));
                            if (id != null && n["id"] != null) db.collection('usuarios').doc(id).collection('notas').doc(n["id"]).delete();
                          },
                        ),
                      ],
                    );
                  }),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Añadir nota"),
                    onPressed: () => setState(() => notas.add({"nota": "", "fecha": DateTime.now()})),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  DocumentReference ref;
                  Map<String, dynamic> infoMap = {for (var i in infoPersonal) if (i['key'].toString().isNotEmpty) i['key']: i['value']};

                  if (id == null) {
                    ref = await db.collection('usuarios').add({
                      "nombre": nombreController.text,
                      "rol": rolController.text,
                      "infoPersonal": infoMap,
                    });
                  } else {
                    ref = db.collection('usuarios').doc(id);
                    await ref.update({
                      "nombre": nombreController.text,
                      "rol": rolController.text,
                      "infoPersonal": infoMap,
                    });
                  }

                  // Guardar servicios
                  for (var s in servicios) {
                    if (s["id"] != null) {
                      await ref.collection('servicios').doc(s["id"]).set({
                        "nombre": s["nombre"],
                        "fecha": Timestamp.fromDate(s["fecha"]),
                      });
                    } else {
                      await ref.collection('servicios').add({
                        "nombre": s["nombre"],
                        "fecha": Timestamp.fromDate(s["fecha"]),
                      });
                    }
                  }

                  // Guardar notas
                  for (var n in notas) {
                    if (n["id"] != null) {
                      await ref.collection('notas').doc(n["id"]).set({
                        "nota": n["nota"],
                        "fecha": Timestamp.fromDate(n["fecha"]),
                      });
                    } else {
                      await ref.collection('notas').add({
                        "nota": n["nota"],
                        "fecha": Timestamp.fromDate(n["fecha"]),
                      });
                    }
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(id == null ? "Usuario creado" : "Usuario actualizado")),
                  );
                },
                child: const Text("Guardar"),
              ),
            ],
          ),
        );
      },
    );
  }

  // Exportar PDF
  Future<void> _exportPdf() async {
    final snapshot = await db.collection('usuarios').get();
    final pdf = pw.Document();
    final data = await Future.wait(snapshot.docs.map((usuario) async {
      final d = usuario.data() as Map<String, dynamic>;
      final serviciosSnapshot = await db.collection('usuarios').doc(usuario.id).collection('servicios').orderBy('fecha').get();
      final notasSnapshot = await db.collection('usuarios').doc(usuario.id).collection('notas').orderBy('fecha', descending: true).get();

      final serviciosText = serviciosSnapshot.docs.map((s) {
        final sData = s.data() as Map<String, dynamic>;
        String fecha = "";
        if (sData['fecha'] != null && sData['fecha'] is Timestamp) fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
        return "${sData['nombre'] ?? ''} ($fecha)";
      }).join("\n");

      final notasText = notasSnapshot.docs.map((n) => n['nota'] ?? "").join("\n");

      return {
        'nombre': d['nombre'] ?? '',
        'rol': d['rol'] ?? '',
        'infoPersonal': (d['infoPersonal'] ?? {}).toString(),
        'servicios': serviciosText,
        'notas': notasText,
      };
    }).toList());

    pdf.addPage(pw.Page(
      build: (pw.Context context) => pw.Table.fromTextArray(
        headers: ['Nombre', 'Rol', 'Info Personal', 'Servicios', 'Notas'],
        data: data.map((d) => [d['nombre'], d['rol'], d['infoPersonal'], d['servicios'], d['notas']]).toList(),
      ),
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // Exportar Excel
  Future<void> _exportExcel() async {
    final snapshot = await db.collection('usuarios').get();
    final data = await Future.wait(snapshot.docs.map((usuario) async {
      final d = usuario.data() as Map<String, dynamic>;
      final serviciosSnapshot = await db.collection('usuarios').doc(usuario.id).collection('servicios').orderBy('fecha').get();
      final notasSnapshot = await db.collection('usuarios').doc(usuario.id).collection('notas').orderBy('fecha', descending: true).get();

      final serviciosText = serviciosSnapshot.docs.map((s) {
        final sData = s.data() as Map<String, dynamic>;
        String fecha = "";
        if (sData['fecha'] != null && sData['fecha'] is Timestamp) fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
        return "${sData['nombre'] ?? ''} ($fecha)";
      }).join("\n");

      final notasText = notasSnapshot.docs.map((n) => n['nota'] ?? "").join("\n");

      return {
        'nombre': d['nombre'] ?? '',
        'rol': d['rol'] ?? '',
        'infoPersonal': (d['infoPersonal'] ?? {}).toString(),
        'servicios': serviciosText,
        'notas': notasText,
      };
    }).toList());

    var excel = Excel.createExcel();
    Sheet sheet = excel['Usuarios'];
    sheet.appendRow(['Nombre', 'Rol', 'Info Personal', 'Servicios', 'Notas']);
    for (var d in data) {
      sheet.appendRow([d['nombre'], d['rol'], d['infoPersonal'], d['servicios'], d['notas']]);
    }

    if (kIsWeb) {
      final bytes = excel.encode()!;
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..setAttribute("download", "usuarios.xlsx")..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/usuarios.xlsx");
      await file.writeAsBytes(excel.encode()!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Archivo guardado en ${file.path}")));
    }
  }
}
