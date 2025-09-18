import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';


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

  // Map para controlar si cada tipo ya fue registrado hoy
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

    // Marcar cada tipo de registro que ya existe hoy
    for (var doc in snapshot.docs) {
      final tipo = (doc.data()['tipo'] ?? '').toString().toLowerCase();
      if (_yaRegistradoHoy.containsKey(tipo)) {
        _yaRegistradoHoy[tipo] = true;
      }
    }
    setState(() {});
  }

  Future<void> _registrar(String tipo,
      {String? justificacion, String? fecha, String? hora, String? nombre}) async {
    setState(() {
      _loading = true;
      _mensaje = null;
    });

    try {
      final registroFecha =
          fecha ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
      final registroHora = hora ?? DateFormat('HH:mm').format(DateTime.now());
      final registroNombre = nombre ?? _nombreUsuario ?? widget.usuario;

      await db.collection("registros").add({
        "usuario": widget.usuario,
        "fecha": registroFecha,
        "hora": registroHora,
        "nombre": registroNombre,
        "tipo": tipo,
        "justificacion": justificacion ?? "",
      });

      setState(() {
        _mensaje =
            "Registro de $tipo guardado${justificacion != null ? ' con justificación' : ''}";
        _yaRegistradoHoy[tipo] = true; // Marcar tipo registrado
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

  Future<void> _confirmarRegistro(String tipo,
      {bool pedirJustificacion = false}) async {
    if (_yaRegistradoHoy[tipo] == true) {
      setState(() {
        _mensaje = "Ya has registrado $tipo hoy. Solo se permite un registro por día para este tipo.";
      });
      return;
    }

    final ahora = DateTime.now();
    final fecha = DateFormat('dd/MM/yyyy').format(ahora);
    final hora = DateFormat('HH:mm').format(ahora);
    final nombre = _nombreUsuario ?? widget.usuario;

    String? justificacion;

    if (pedirJustificacion) {
      justificacion = await showDialog<String>(
        context: context,
        builder: (context) {
          String texto = "";
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Justificación de $tipo"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Nombre: $nombre"),
                Text("Fecha: $fecha"),
                Text("Hora: $hora"),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => texto = value,
                  decoration: const InputDecoration(
                    hintText: "Escribe la justificación",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, texto),
                child: const Text("Confirmar"),
              ),
            ],
          );
        },
      );
      if (justificacion == null || justificacion.trim().isEmpty) {
        return;
      }
    } else {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Confirmar $tipo"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Nombre: $nombre"),
                Text("Fecha: $fecha"),
                Text("Hora: $hora"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirmar"),
              ),
            ],
          );
        },
      );
      if (confirmado != true) return;
    }

    _registrar(tipo,
        fecha: fecha, hora: hora, nombre: nombre, justificacion: justificacion);
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
                          style:
                              const TextStyle(color: Colors.green, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    if (_loading) const CircularProgressIndicator(),
                    const SizedBox(height: 30),

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
                            : () =>
                                _confirmarRegistro("justificacion", pedirJustificacion: true),
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
