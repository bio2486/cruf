import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // Nota: solo disponible en builds Web
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class FichajesScreen extends StatefulWidget {
  const FichajesScreen({super.key});

  @override
  State<FichajesScreen> createState() => _FichajesScreenState();
}

class _FichajesScreenState extends State<FichajesScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

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
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == "usuarios_excel") {
                  await _exportarUsuariosExcel();
                } else if (value == "usuarios_pdf") {
                  await _previsualizarUsuariosPdf();
                } else if (value == "registros_excel") {
                  await _exportarRegistrosExcel();
                } else if (value == "registros_pdf") {
                  await _previsualizarRegistrosPdf();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "usuarios_excel",
                  child: Text("Exportar Usuarios (Excel)"),
                ),
                const PopupMenuItem(
                  value: "usuarios_pdf",
                  child: Text("Previsualizar Usuarios (PDF)"),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: "registros_excel",
                  child: Text("Exportar Registros (Excel)"),
                ),
                const PopupMenuItem(
                  value: "registros_pdf",
                  child: Text("Previsualizar Registros (PDF)"),
                ),
              ],
              icon: const Icon(Icons.download),
            ),
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

  // --- UI USUARIOS ---
  Widget _buildUsuariosColumn() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: usuarioSearchController,
            decoration: const InputDecoration(
              labelText: "Buscar por nombre o rol",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: db.collection("fichadores").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;

              final query = usuarioSearchController.text.toLowerCase();
              if (query.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final rol = (data['rol'] ?? '').toString().toLowerCase();
                  return nombre.contains(query) || rol.contains(query);
                }).toList();
              }

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.purple.withOpacity(0.2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "USUARIOS (${docs.length})",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.purple),
                            onPressed: _agregarUsuario,
                          ),
                        ],
                      ),
                    ),
                    if (docs.isEmpty)
                      const Expanded(child: Center(child: Text("Sin usuarios")))
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("#")),
                              DataColumn(label: Text("Nombre")),
                              DataColumn(label: Text("Usuario")),
                              DataColumn(label: Text("Rol")),
                              DataColumn(label: Text("Activo")),
                            ],
                            rows: docs.asMap().entries.map((entry) {
                              int index = entry.key + 1;
                              final data = entry.value.data() as Map<String, dynamic>;
                              return DataRow(cells: [
                                DataCell(Text(index.toString())),
                                DataCell(Text(data['nombre'] ?? '-')),
                                DataCell(Text(data['usuario'] ?? '-')),
                                DataCell(Text(data['rol'] ?? '-')),
                                DataCell(Text(data['activo'] == true ? 'Sí' : 'No')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- UI TRABAJADORES ---
  Widget _buildTrabajadoresColumn() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: registroSearchController,
            decoration: const InputDecoration(
              labelText: "Buscar por nombre o tipo",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: db.collection("registros").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;

              final query = registroSearchController.text.toLowerCase();
              if (query.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final tipo = (data['tipo'] ?? '').toString().toLowerCase();
                  return nombre.contains(query) || tipo.contains(query);
                }).toList();
              }

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.green.withOpacity(0.2),
                      child: Center(
                        child: Text(
                          "TRABAJADORES (${docs.length})",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    ),
                    if (docs.isEmpty)
                      const Expanded(child: Center(child: Text("Sin registros")))
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("#")),
                              DataColumn(label: Text("Nombre")),
                              DataColumn(label: Text("Usuario")),
                              DataColumn(label: Text("Tipo")),
                              DataColumn(label: Text("Fecha")),
                              DataColumn(label: Text("Hora")),
                              DataColumn(label: Text("Justificación")),
                              DataColumn(label: Text("Firma URL")),
                            ],
                            rows: docs.asMap().entries.map((entry) {
                              int index = entry.key + 1;
                              final data = entry.value.data() as Map<String, dynamic>;
                              return DataRow(cells: [
                                DataCell(Text(index.toString())),
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
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- PREVISUALIZAR PDF (se mantiene igual) ---
  Future<void> _previsualizarUsuariosPdf() async {
    final snapshot = await db.collection("fichadores").get();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table.fromTextArray(
            headers: ["#", "Nombre", "Usuario", "Rol", "Activo"],
            data: List.generate(snapshot.docs.length, (i) {
              final data = snapshot.docs[i].data();
              return [
                i + 1,
                data["nombre"] ?? "",
                data["usuario"] ?? "",
                data["rol"] ?? "",
                data["activo"] == true ? "Sí" : "No"
              ];
            }),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _previsualizarRegistrosPdf() async {
    final snapshot = await db.collection("registros").get();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          // Omitimos la columna firma en el PDF de registros
          return pw.Table.fromTextArray(
            headers: ["#", "Nombre", "Usuario", "Tipo", "Fecha", "Hora", "Justificación"],
            data: List.generate(snapshot.docs.length, (i) {
              final data = snapshot.docs[i].data();
              return [
                i + 1,
                data["nombre"] ?? "",
                data["usuario"] ?? "",
                data["tipo"] ?? "",
                data["fecha"] ?? "",
                data["hora"] ?? "",
                data["justificacion"] ?? ""
              ];
            }),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // ---------------- EXCEL EXPORT (LOGICA ADAPTADA, SIN CAMPOS EXTRA) ----------------

  // Exportar Excel para "Usuarios" (colección 'fichadores')
  Future<void> _exportarUsuariosExcel() async {
    try {
      final snapshot = await db.collection('fichadores').get();

      // Preparamos los datos (lista de maps) — manteniendo los mismos campos que en la UI
      final rows = snapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return [
          d['nombre'] ?? '',
          d['usuario'] ?? '',
          d['rol'] ?? '',
          d['activo'] == true ? 'Sí' : 'No'
        ];
      }).toList();

      var excel = Excel.createExcel();
      Sheet sheet = excel['Usuarios'];

      // Encabezados (mismos que UI)
      sheet.appendRow(['Nombre', 'Usuario', 'Rol', 'Activo']);

      // Filas
      for (var r in rows) {
        sheet.appendRow([r[0], r[1], r[2], r[3]]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: no se pudo generar el archivo Excel.")));
        return;
      }

      if (kIsWeb) {
        // Web: descarga directa
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "usuarios.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile/Desktop: guardar en Documentos
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/usuarios.xlsx");
        await file.writeAsBytes(bytes, flush: true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Usuarios exportados a ${file.path}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exportando Excel: $e")));
    }
  }

  // Exportar Excel para "Registros" (colección 'registros')
  Future<void> _exportarRegistrosExcel() async {
    try {
      final snapshot = await db.collection('registros').get();

      // Preparamos las filas — mismos campos que UI (sin cambiar)
      final rows = snapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return [
          d['nombre'] ?? '',
          d['usuario'] ?? '',
          d['tipo'] ?? '',
          d['fecha'] ?? '',
          d['hora'] ?? '',
          d['justificacion'] ?? '',
          d['firmaUrl'] ?? ''
        ];
      }).toList();

      var excel = Excel.createExcel();
      Sheet sheet = excel['Registros'];

      // Encabezados (mismos que UI)
      sheet.appendRow(['Nombre', 'Usuario', 'Tipo', 'Fecha', 'Hora', 'Justificación', 'Firma']);

      // Filas
      for (var r in rows) {
        sheet.appendRow([r[0], r[1], r[2], r[3], r[4], r[5], r[6]]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: no se pudo generar el archivo Excel.")));
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "registros.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File("${dir.path}/registros.xlsx");
        await file.writeAsBytes(bytes, flush: true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registros exportados a ${file.path}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exportando Excel: $e")));
    }
  }

  // --- CRUD USUARIOS ---
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
}
