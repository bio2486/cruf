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

// -------------------- Usuarios Dashboard -------------------- //
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
        title: const Text("Usuarios"),
        backgroundColor: const Color.fromARGB(255, 11, 158, 244),
        actions: [
          IconButton(
            tooltip: 'Exportar Excel',
            icon: const Icon(Icons.grid_on),
            onPressed: _exportToExcel,
          ),
          IconButton(
            tooltip: 'Exportar PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPdf,
          ),
          // Contador agregado (sin cambiar nada más del código)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection("usuarios").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final count = snapshot.data!.docs.length;
                return CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: _usuariosTab(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(null, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  // -------------------- Tabla de usuarios -------------------- //
  Widget _usuariosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: "Buscar en la tabla",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ""),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection("usuarios").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No hay registros."));

              // Enriquecemos docs con textos de subcolecciones para búsqueda (pero sin cambiar la data original)
              final futures = docs.map((doc) async {
                final data = doc.data() as Map<String, dynamic>;

                // obtener info (subcolección)
                final infoSnap = await db.collection('usuarios').doc(doc.id).collection('info').get();
                final infoText = infoSnap.docs.isEmpty
                    ? ""
                    : infoSnap.docs.map((i) => "${i['campo'] ?? ''}: ${i['valor'] ?? ''}").join(" | ");

                // servicios
                final serviciosSnap = await db.collection('usuarios').doc(doc.id).collection('servicios').get();
                final serviciosText = serviciosSnap.docs.isEmpty
                    ? ""
                    : serviciosSnap.docs.map((s) {
                        final sData = s.data() as Map<String, dynamic>;
                        String fecha = "";
                        if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
                          fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
                        }
                        return "${sData['nombre'] ?? ''} ($fecha)".trim();
                      }).join(" | ");

                // notas
                final notasSnap = await db.collection('usuarios').doc(doc.id).collection('notas').get();
                final notasText = notasSnap.docs.isEmpty ? "" : notasSnap.docs.map((n) => "${n['nota'] ?? ''}").join(" | ");

                return {
                  'doc': doc,
                  'data': data,
                  'infoText': infoText.toLowerCase(),
                  'serviciosText': serviciosText.toLowerCase(),
                  'notasText': notasText.toLowerCase(),
                };
              }).toList();

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait(futures),
                builder: (context, enrichedSnapshot) {
                  if (!enrichedSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final enriched = enrichedSnapshot.data!;
                  final filtered = enriched.where((e) {
                    final data = e['data'] as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? "").toString().toLowerCase();
                    final rol = (data['rol'] ?? "").toString().toLowerCase();
                    final infoText = (e['infoText'] ?? "").toString();
                    final serviciosText = (e['serviciosText'] ?? "").toString();
                    final notasText = (e['notasText'] ?? "").toString();
                    final q = _searchQuery;
                    if (q.isEmpty) return true;
                    return nombre.contains(q) || rol.contains(q) || infoText.contains(q) || serviciosText.contains(q) || notasText.contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text("No hay registros que coincidan con la búsqueda."));
                  }

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
                            DataColumn(label: Text("Info", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Servicios", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Notas", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("Acciones", style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: List.generate(filtered.length, (index) {
                            final item = filtered[index];
                            final doc = item['doc'] as QueryDocumentSnapshot;
                            final data = item['data'] as Map<String, dynamic>;

                            return DataRow(cells: [
                              DataCell(Text("${index + 1}")),
                              DataCell(Text(data['nombre'] ?? "-")),
                              DataCell(Text(data['rol'] ?? "-")),
                              // Info subcolección
                              DataCell(StreamBuilder<QuerySnapshot>(
                                stream: db.collection("usuarios").doc(doc.id).collection('info').snapshots(),
                                builder: (context, infoSnap) {
                                  if (!infoSnap.hasData) return const Text("-");
                                  final infos = infoSnap.data!.docs;
                                  return Text(infos.isEmpty ? "-" : infos.map((i) => "${i['campo'] ?? ''}: ${i['valor'] ?? ''}").join("\n"));
                                },
                              )),
                              // Servicios
                              DataCell(StreamBuilder<QuerySnapshot>(
                                stream: db.collection("usuarios").doc(doc.id).collection('servicios').orderBy('fecha').snapshots(),
                                builder: (context, serviciosSnap) {
                                  if (!serviciosSnap.hasData) return const Text("-");
                                  final servicios = serviciosSnap.data!.docs;
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
                              // Notas
                              DataCell(StreamBuilder<QuerySnapshot>(
                                stream: db.collection("usuarios").doc(doc.id).collection('notas').orderBy('fecha', descending: true).snapshots(),
                                builder: (context, notasSnap) {
                                  if (!notasSnap.hasData) return const Text("-");
                                  final notas = notasSnap.data!.docs;
                                  return Text(notas.isEmpty ? "-" : notas.map((n) => n['nota'] ?? "").join("\n"));
                                },
                              )),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _abrirFormulario(doc.id, data),
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
                                        await db.collection("usuarios").doc(doc.id).delete();
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
    );
  }

  // -------------------- Formulario (crear/editar) -------------------- //
  // Abre diálogo para nuevo usuario o editar uno existente.
  void _abrirFormulario(String? id, Map<String, dynamic>? data) async {
    final nombreController = TextEditingController(text: data?['nombre']);
    final rolController = TextEditingController(text: data?['rol']);

    // Subcolecciones manejadas localmente en el dialog
    List<Map<String, dynamic>> info = [];
    List<Map<String, dynamic>> servicios = [];
    List<Map<String, dynamic>> notas = [];

    if (id != null) {
      // cargar subcolecciones
      final infoSnapshot = await db.collection('usuarios').doc(id).collection('info').get();
      info = infoSnapshot.docs.map((i) => {"id": i.id, "campo": i['campo'] ?? "", "valor": i['valor'] ?? ""}).toList();

      final serviciosSnapshot = await db.collection('usuarios').doc(id).collection('servicios').orderBy('fecha').get();
      servicios = serviciosSnapshot.docs
          .map((s) => {"id": s.id, "nombre": s['nombre'] ?? "", "fecha": (s['fecha'] as Timestamp?)?.toDate() ?? DateTime.now()})
          .toList();

      final notasSnapshot = await db.collection('usuarios').doc(id).collection('notas').orderBy('fecha', descending: true).get();
      notas = notasSnapshot.docs.map((n) => {"id": n.id, "nota": n['nota'] ?? "", "fecha": (n['fecha'] as Timestamp?)?.toDate() ?? DateTime.now()}).toList();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(id == null ? "Nuevo usuario" : "Editar usuario"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Nombre")),
                  TextField(controller: rolController, decoration: const InputDecoration(labelText: "Rol")),
                  const SizedBox(height: 20),

                  // Info (subcolección)
                  const Text("Info", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...info.map((i) {
                    // Use TextFormField with initialValue + onChanged instead of recreating controllers every build.
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: i["campo"],
                            decoration: const InputDecoration(labelText: "Campo"),
                            onChanged: (v) => i["campo"] = v,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: i["valor"],
                            decoration: const InputDecoration(labelText: "Valor"),
                            onChanged: (v) => i["valor"] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Confirmar eliminación"),
                                content: const Text("¿Seguro que deseas eliminar este item de info?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar")),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() => info.remove(i));
                              if (id != null && i["id"] != null) {
                                await db.collection('usuarios').doc(id).collection('info').doc(i["id"]).delete();
                              }
                            }
                          },
                        ),
                      ],
                    );
                  }),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Añadir info"),
                    onPressed: () => setState(() => info.add({"campo": "", "valor": ""})),
                  ),

                  const SizedBox(height: 20),

                  // Servicios (solo nombre + fecha)
                  const Text("Servicios", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...servicios.map((s) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: s["nombre"],
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
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Confirmar eliminación"),
                                content: const Text("¿Seguro que deseas eliminar este servicio?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar")),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() => servicios.remove(s));
                              if (id != null && s["id"] != null) {
                                await db.collection('usuarios').doc(id).collection('servicios').doc(s["id"]).delete();
                              }
                            }
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

                  // Notas (nota + fecha)
                  const Text("Notas", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...notas.map((n) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: n["nota"],
                            decoration: const InputDecoration(labelText: "Nota"),
                            onChanged: (v) => n["nota"] = v,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Confirmar eliminación"),
                                content: const Text("¿Seguro que deseas eliminar esta nota?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar")),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() => notas.remove(n));
                              if (id != null && n["id"] != null) {
                                await db.collection('usuarios').doc(id).collection('notas').doc(n["id"]).delete();
                              }
                            }
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

                  if (id == null) {
                    // crear nuevo usuario (sin infoPersonal dentro del documento)
                    ref = await db.collection('usuarios').add({
                      "nombre": nombreController.text,
                      "rol": rolController.text,
                    });
                  } else {
                    // actualizar nombre/rol
                    ref = db.collection('usuarios').doc(id);
                    await ref.update({
                      "nombre": nombreController.text,
                      "rol": rolController.text,
                    });
                  }

                  // Guardar/actualizar info (subcolección)
                  for (var i in info) {
                    if (i["id"] != null) {
                      await ref.collection('info').doc(i["id"]).set({"campo": i["campo"], "valor": i["valor"]});
                    } else {
                      await ref.collection('info').add({"campo": i["campo"], "valor": i["valor"]});
                    }
                  }

                  // Guardar/actualizar servicios
                  for (var s in servicios) {
                    if (s["id"] != null) {
                      await ref.collection('servicios').doc(s["id"]).set({"nombre": s["nombre"], "fecha": Timestamp.fromDate(s["fecha"])});
                    } else {
                      await ref.collection('servicios').add({"nombre": s["nombre"], "fecha": Timestamp.fromDate(s["fecha"])});
                    }
                  }

                  // Guardar/actualizar notas
                  for (var n in notas) {
                    if (n["id"] != null) {
                      await ref.collection('notas').doc(n["id"]).set({"nota": n["nota"], "fecha": Timestamp.fromDate(n["fecha"])});
                    } else {
                      await ref.collection('notas').add({"nota": n["nota"], "fecha": Timestamp.fromDate(n["fecha"])});
                    }
                  }

                  if (context.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(id == null ? "Usuario creado" : "Usuario actualizado")),
                  );
                },
                child: const Text("Guardar"),
              ),
            ],
          );
        });
      },
    );
  }

  // -------------------- Exportar a Excel -------------------- //
  Future<void> _exportToExcel() async {
    final usuariosSnap = await db.collection('usuarios').get();
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['Usuarios'];
    sheetObject.appendRow(['Nombre', 'Rol', 'Info (campo:valor)', 'Servicios (nombre (dd/MM/yyyy))', 'Notas (nota)']);

    for (var u in usuariosSnap.docs) {
      final data = u.data() as Map<String, dynamic>;

      final infoSnap = await u.reference.collection('info').get();
      final infoText = infoSnap.docs.map((i) => "${i['campo'] ?? ''}: ${i['valor'] ?? ''}").join(' | ');

      final serviciosSnap = await u.reference.collection('servicios').orderBy('fecha').get();
      final serviciosText = serviciosSnap.docs.map((s) {
        final sData = s.data() as Map<String, dynamic>;
        String fecha = "";
        if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
          fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
        }
        return "${sData['nombre'] ?? ''} ($fecha)";
      }).join(' | ');

      final notasSnap = await u.reference.collection('notas').orderBy('fecha', descending: true).get();
      final notasText = notasSnap.docs.map((n) => "${n['nota'] ?? ''}").join(' | ');

      sheetObject.appendRow([data['nombre'] ?? '', data['rol'] ?? '', infoText, serviciosText, notasText]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear Excel')));
      return;
    }
    final content = Uint8List.fromList(bytes);

    if (kIsWeb) {
      final blob = html.Blob([content], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'usuarios.xlsx')
        ..style.display = 'none';
      // Añadir al DOM, click y remover (fix para que funcione la descarga en Web)
      html.document.body!.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/usuarios.xlsx');
      await file.writeAsBytes(content, flush: true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel guardado en ${file.path}')));
    }
  }

  // -------------------- Exportar a PDF -------------------- //
  Future<void> _exportToPdf() async {
    final usuariosSnap = await db.collection('usuarios').get();
    final pdf = pw.Document();

    final rows = <List<String>>[];
    for (var u in usuariosSnap.docs) {
      final data = u.data() as Map<String, dynamic>;

      final infoSnap = await u.reference.collection('info').get();
      final infoText = infoSnap.docs.map((i) => "${i['campo'] ?? ''}: ${i['valor'] ?? ''}").join(' | ');

      final serviciosSnap = await u.reference.collection('servicios').orderBy('fecha').get();
      final serviciosText = serviciosSnap.docs.map((s) {
        final sData = s.data() as Map<String, dynamic>;
        String fecha = "";
        if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
          fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
        }
        return "${sData['nombre'] ?? ''} ($fecha)";
      }).join(' | ');

      final notasSnap = await u.reference.collection('notas').orderBy('fecha', descending: true).get();
      final notasText = notasSnap.docs.map((n) => "${n['nota'] ?? ''}").join(' | ');

      rows.add([data['nombre'] ?? '', data['rol'] ?? '', infoText, serviciosText, notasText]);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Usuarios')),
          pw.Table.fromTextArray(
            headers: ['Nombre', 'Rol', 'Info', 'Servicios', 'Notas'],
            data: rows,
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'usuarios.pdf')
        ..style.display = 'none';
      // Añadir al DOM, click y remover (fix para que funcione la descarga en Web)
      html.document.body!.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.sharePdf(bytes: pdfBytes, filename: 'usuarios.pdf');
    }
  }
}
