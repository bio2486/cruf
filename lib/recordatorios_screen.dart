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
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('recordatorios').orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        final recordatorios = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        int total = recordatorios.length;

        return Scaffold(
          appBar: AppBar(
            title: Text("Recordatorios ($total)"),
            backgroundColor: Colors.blueAccent,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'pdf') _exportPdf(recordatorios);
                  if (value == 'excel') _exportExcel(recordatorios);
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
              // 🔍 Buscador
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: "Buscar recordatorio",
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

              // 📋 Tabla
              Expanded(
                child: _buildDataTable(recordatorios),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: _showAddRecordatorioDialog,
          ),
        );
      },
    );
  }

  Widget _buildDataTable(List<QueryDocumentSnapshot> recordatorios) {
    final filtered = recordatorios.where((r) {
      final data = r.data() as Map<String, dynamic>;
      final titulo = (data['titulo'] ?? "").toString().toLowerCase();
      final descripcion = (data['descripcion'] ?? "").toString().toLowerCase();
      return titulo.contains(_searchQuery) || descripcion.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No se encontraron recordatorios."));
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
              DataColumn(label: Text("Título", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Descripción", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Fecha", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Acciones", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: List.generate(filtered.length, (index) {
              final r = filtered[index];
              final data = r.data() as Map<String, dynamic>;
              final fecha = data['fecha'] != null && data['fecha'] is Timestamp
                  ? DateFormat('dd/MM/yyyy – kk:mm').format((data['fecha'] as Timestamp).toDate())
                  : "";

              return DataRow(cells: [
                DataCell(Text("${index + 1}")),
                DataCell(Text(data['titulo'] ?? "-")),
                DataCell(Text(data['descripcion'] ?? "-")),
                DataCell(Text(fecha)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _showEditRecordatorioDialog(r.id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeletion(r.id),
                    ),
                  ],
                )),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  // ---------------- CRUD ----------------
  void _confirmDeletion(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmación"),
        content: const Text("¿Eliminar este recordatorio?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
    final tituloController = TextEditingController();
    final descripcionController = TextEditingController();
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
                    final picked = await showDatePicker(
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
    final tituloController = TextEditingController(text: data['titulo']);
    final descripcionController = TextEditingController(text: data['descripcion']);
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
                    final picked = await showDatePicker(
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

  // ---------------- Exportaciones ----------------
  Future<void> _exportPdf(List<QueryDocumentSnapshot> recordatorios) async {
    final pdf = pw.Document();

    final data = recordatorios.map((r) {
      final d = r.data() as Map<String, dynamic>;
      final fecha = d['fecha'] != null && d['fecha'] is Timestamp
          ? DateFormat('dd/MM/yyyy – kk:mm').format((d['fecha'] as Timestamp).toDate())
          : "";
      return [d['titulo'] ?? "", d['descripcion'] ?? "", fecha];
    }).toList();

    pdf.addPage(pw.Page(
      build: (context) => pw.Table.fromTextArray(
        headers: ['Título', 'Descripción', 'Fecha'],
        data: data,
      ),
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportExcel(List<QueryDocumentSnapshot> recordatorios) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Recordatorios'];
    sheet.appendRow(['Título', 'Descripción', 'Fecha']);

    for (var r in recordatorios) {
      final d = r.data() as Map<String, dynamic>;
      final fecha = d['fecha'] != null && d['fecha'] is Timestamp
          ? DateFormat('dd/MM/yyyy – kk:mm').format((d['fecha'] as Timestamp).toDate())
          : "";
      sheet.appendRow([d['titulo'] ?? "", d['descripcion'] ?? "", fecha]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "recordatorios.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/recordatorios.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Excel guardado en: $filePath')));
    }
  }
}
