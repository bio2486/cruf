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

class TrabajadoresDashboard extends StatefulWidget {
  const TrabajadoresDashboard({super.key});

  @override
  State<TrabajadoresDashboard> createState() => _TrabajadoresDashboardState();
}

class _TrabajadoresDashboardState extends State<TrabajadoresDashboard> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de Trabajadores"),
        backgroundColor: const Color.fromARGB(255, 16, 207, 51),
        actions: [
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
          // Buscador
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
            ),
          ),

          // Tabla con scroll
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('trabajadores').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final trabajadores = snapshot.data!.docs;
                if (trabajadores.isEmpty) return const Center(child: Text("No hay trabajadores."));

                final filteredTrabajadores = trabajadores.where((trabajador) {
                  final data = trabajador.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? "").toString().toLowerCase();
                  final rol = (data['rol'] ?? "").toString().toLowerCase();
                  final infoPersonal = (data['infoPersonal'] ?? {}).toString().toLowerCase();
                  return nombre.contains(_searchQuery) ||
                      rol.contains(_searchQuery) ||
                      infoPersonal.contains(_searchQuery);
                }).toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 20,
                        dataRowMinHeight: 70,
                        dataRowMaxHeight: 200,
                        columns: const [
                          DataColumn(label: Text("Nombre", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Rol", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Info Personal", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Servicios", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Notas", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredTrabajadores.map((trabajador) {
                          final data = trabajador.data() as Map<String, dynamic>;
                          final info = (data['infoPersonal'] ?? {}) as Map<String, dynamic>;
                          String infoPersonalText = info.isNotEmpty
                              ? info.entries.map((e) => e.value is Timestamp
                                  ? "${e.key}: ${DateFormat('dd/MM/yyyy').format((e.value as Timestamp).toDate())}"
                                  : "${e.key}: ${e.value}").join("\n")
                              : "-";

                          return DataRow(cells: [
                            DataCell(Text(data['nombre'] ?? "-")),
                            DataCell(Text(data['rol'] ?? "-")),
                            DataCell(Text(infoPersonalText)),
                            DataCell(FutureBuilder<QuerySnapshot>(
                              future: db
                                  .collection('trabajadores')
                                  .doc(trabajador.id)
                                  .collection('servicios')
                                  .orderBy('fecha')
                                  .get(),
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
                            DataCell(FutureBuilder<QuerySnapshot>(
                              future: db
                                  .collection('trabajadores')
                                  .doc(trabajador.id)
                                  .collection('notas')
                                  .orderBy('fecha', descending: true)
                                  .get(),
                              builder: (context, notaSnapshot) {
                                if (!notaSnapshot.hasData) return const Text("-");
                                final notas = notaSnapshot.data!.docs;
                                return Text(notas.isEmpty ? "-" : notas.map((n) => n['nota'] ?? "").join("\n"));
                              },
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

  // 🔹 Exportar PDF con Servicios y Notas
  Future<void> _exportPdf() async {
    final snapshot = await db.collection('trabajadores').get();
    final pdf = pw.Document();

    final data = await Future.wait(snapshot.docs.map((trabajador) async {
      final d = trabajador.data() as Map<String, dynamic>;

      final serviciosSnapshot = await db
          .collection('trabajadores')
          .doc(trabajador.id)
          .collection('servicios')
          .orderBy('fecha')
          .get();
      final notasSnapshot = await db
          .collection('trabajadores')
          .doc(trabajador.id)
          .collection('notas')
          .orderBy('fecha', descending: true)
          .get();

      final serviciosText = serviciosSnapshot.docs.map((s) {
        final sData = s.data() as Map<String, dynamic>;
        String fecha = "";
        if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
          fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
        }
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
      build: (pw.Context context) {
        return pw.Table.fromTextArray(
          headers: ['Nombre', 'Rol', 'Info Personal', 'Servicios', 'Notas'],
          data: data.map((d) => [d['nombre'], d['rol'], d['infoPersonal'], d['servicios'], d['notas']]).toList(),
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // 🔹 Exportar Excel con Servicios y Notas
  Future<void> _exportExcel() async {
    final snapshot = await db.collection('trabajadores').get();
    final data = await Future.wait(snapshot.docs.map((trabajador) async {
      final d = trabajador.data() as Map<String, dynamic>;

      final serviciosSnapshot = await db
          .collection('trabajadores')
          .doc(trabajador.id)
          .collection('servicios')
          .orderBy('fecha')
          .get();
      final notasSnapshot = await db
          .collection('trabajadores')
          .doc(trabajador.id)
          .collection('notas')
          .orderBy('fecha', descending: true)
          .get();

      final serviciosText = serviciosSnapshot.docs.map((s) {
        final sData = s.data() as Map<String, dynamic>;
        String fecha = "";
        if (sData['fecha'] != null && sData['fecha'] is Timestamp) {
          fecha = DateFormat('dd/MM/yyyy').format((sData['fecha'] as Timestamp).toDate());
        }
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
    Sheet sheet = excel['Trabajadores'];
    sheet.appendRow(['Nombre', 'Rol', 'Info Personal', 'Servicios', 'Notas']);
    for (var d in data) {
      sheet.appendRow([d['nombre'], d['rol'], d['infoPersonal'], d['servicios'], d['notas']]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "trabajadores.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/trabajadores.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel guardado en: $filePath')));
    }
  }
}
