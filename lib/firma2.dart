import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

class FicharScreen extends StatefulWidget {
  final String usuario;

  const FicharScreen({super.key, required this.usuario});

  @override
  State<FicharScreen> createState() => _FicharScreenState();
}

class _FicharScreenState extends State<FicharScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  bool _loading = false;
  String? _mensaje;
  String? _nombreUsuario;

  Map<String, bool> _yaRegistradoHoy = {
    "entrada": false,
    "salida": false,
    "justificacion": false,
  };

  @override
  void initState() {
    super.initState();
    _cargarNombreDesdeUsuarios();
    _verificarRegistrosHoy();
  }

  Future<void> _cargarNombreDesdeUsuarios() async {
    try {
      final query = await db
          .collection("fichadores")
          .where("activo", isEqualTo: true)
          .where("usuario", isEqualTo: widget.usuario)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _nombreUsuario = data["nombre"];
        });
      } else {
        setState(() {
          _nombreUsuario = widget.usuario;
        });
      }
    } catch (e) {
      setState(() {
        _nombreUsuario = widget.usuario;
      });
    }
  }

  Future<void> _verificarRegistrosHoy() async {
    final fechaHoy = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final snapshot = await db
        .collection("registros")
        .where("usuario", isEqualTo: widget.usuario)
        .where("fecha", isEqualTo: fechaHoy)
        .get();

    for (var doc in snapshot.docs) {
      final tipo = (doc.data()['tipo'] ?? '').toString().toLowerCase();
      if (_yaRegistradoHoy.containsKey(tipo)) {
        _yaRegistradoHoy[tipo] = true;
      }
    }
    setState(() {});
  }

  Future<void> _registrar(String tipo,
      {required String nombre,
      required String fecha,
      required String hora,
      String? justificacion,
      required Uint8List firmaBytes}) async {
    setState(() {
      _loading = true;
      _mensaje = null;
    });

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child(
              "firmas/${widget.usuario}_${DateTime.now().millisecondsSinceEpoch}.png");
      await ref.putData(firmaBytes);
      final firmaUrl = await ref.getDownloadURL();

      await db.collection("registros").add({
        "usuario": widget.usuario,
        "fecha": fecha,
        "hora": hora,
        "nombre": nombre,
        "tipo": tipo,
        "justificacion": justificacion ?? "",
        "firmaUrl": firmaUrl,
      });

      setState(() {
        _mensaje =
            "Registro de $tipo guardado${justificacion != null ? ' con justificación' : ''}";
        _yaRegistradoHoy[tipo] = true;
      });
    } catch (e) {
      setState(() {
        _mensaje = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _mostrarFormularioFinal(
      {required String tipo,
      required String nombre,
      required String fecha,
      required String hora,
      String? justificacion,
      required Uint8List firmaBytes}) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirmar registro de $tipo"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Nombre: $nombre"),
                Text("Fecha: $fecha"),
                Text("Hora: $hora"),
                if (justificacion != null && justificacion.isNotEmpty)
                  Text("Justificación: $justificacion"),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: Image.memory(firmaBytes),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () {
                  _registrar(
                    tipo,
                    nombre: nombre,
                    fecha: fecha,
                    hora: hora,
                    justificacion: justificacion,
                    firmaBytes: firmaBytes,
                  );
                  Navigator.pop(context);
                },
                child: const Text("Guardar")),
          ],
        );
      },
    );
  }

  Future<void> _confirmarRegistro(String tipo,
      {bool pedirJustificacion = false}) async {
    if (_yaRegistradoHoy[tipo] == true) {
      setState(() {
        _mensaje =
            "Ya has registrado $tipo hoy. Solo se permite un registro por día para este tipo.";
      });
      return;
    }

    final ahora = DateTime.now();
    final fecha = DateFormat('dd/MM/yyyy').format(ahora);
    final nombre = _nombreUsuario ?? widget.usuario;

    // Selección de hora
    TimeOfDay? horaSeleccionada = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ahora),
    );
    if (horaSeleccionada == null) return;

    final hora = horaSeleccionada.format(context);

    String? justificacion;
    if (pedirJustificacion) {
      justificacion = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text("Justificación de $tipo"),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: "Escribe la justificación",
                  border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancelar")),
              ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text("Confirmar")),
            ],
          );
        },
      );
      if (justificacion == null || justificacion.isEmpty) return;
    }

    // Captura de firma
    final firmaController = SignatureController(penStrokeWidth: 2);
    Uint8List? firmaBytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Firma digital"),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: Signature(
            controller: firmaController,
            backgroundColor: Colors.grey[200]!,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => firmaController.clear(),
              child: const Text("Borrar")),
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () async {
                if (firmaController.isEmpty) return;
                final ui.Image? img = await firmaController.toImage();
                final data = await img!.toByteData(
                    format: ui.ImageByteFormat.png);
                Navigator.pop(context, data!.buffer.asUint8List());
              },
              child: const Text("Guardar")),
        ],
      ),
    );
    if (firmaBytes == null) return;

    // Mostrar formulario final antes de guardar
    await _mostrarFormularioFinal(
        tipo: tipo,
        nombre: nombre,
        fecha: fecha,
        hora: hora,
        justificacion: justificacion,
        firmaBytes: firmaBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_nombreUsuario == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFa8edea), Color(0xFFfed6e3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school, size: 80, color: Colors.blueAccent),
                    const SizedBox(height: 20),
                    Text(
                      "Buen día, $_nombreUsuario",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    if (_mensaje != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _mensaje!,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_loading) const CircularProgressIndicator(),
                    const SizedBox(height: 30),
                    // Botones
                    SizedBox(
                      width: 250,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: (_loading || _yaRegistradoHoy["entrada"] == true)
                            ? null
                            : () => _confirmarRegistro("entrada"),
                        icon: const Icon(Icons.login),
                        label: const Text("Registrar entrada"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 250,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: (_loading || _yaRegistradoHoy["justificacion"] == true)
                            ? null
                            : () => _confirmarRegistro("justificacion", pedirJustificacion: true),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text("Entrada justificada"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 250,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: (_loading || _yaRegistradoHoy["salida"] == true)
                            ? null
                            : () => _confirmarRegistro("salida"),
                        icon: const Icon(Icons.logout),
                        label: const Text("Registrar salida"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, "/");
                      },
                      icon: const Icon(Icons.logout, color: Colors.blueAccent),
                      label: const Text(
                        "Cerrar sesión",
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
