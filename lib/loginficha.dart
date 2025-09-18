import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fichar_screen.dart';
import 'fichajes_screen.dart';

class LoginFichaScreen extends StatefulWidget {
  const LoginFichaScreen({super.key});

  @override
  State<LoginFichaScreen> createState() => _LoginFichaScreenState();
}

class _LoginFichaScreenState extends State<LoginFichaScreen> {
  final TextEditingController _userController = TextEditingController();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = await db
          .collection("fichadores")
          .where("usuario", isEqualTo: _userController.text.trim())
          .where("activo", isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();

        final String rol = data["rol"] ?? "user";
        final String usuario = data["usuario"];

        if (rol == "admin") {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => FichajesScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => FicharScreen(usuario: usuario)),
          );
        }
      } else {
        setState(() {
          _error = "Usuario no encontrado o inactivo";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Padding(
                padding: const EdgeInsets.all(32.0), // 🔹 Un poco más amplio
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school, size: 100, color: Colors.blueAccent), // 🔹 Un poco más grande
                    const SizedBox(height: 18),
                    const Text(
                      "Acceso al sistema educativo",
                      style: TextStyle(
                        fontSize: 20, // 🔹 Tamaño intermedio
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25),

                    // Campo usuario
                    SizedBox(
                      width: 280, // 🔹 Más ancho que antes (220 → 240)
                      child: TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: "Usuario",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Mensaje error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Botón
                    SizedBox(
                      width: 280,
                      height: 50, // 🔹 Un poco más alto que antes (45 → 50)
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text(
                                "Entrar",
                                style: TextStyle(fontSize: 17), // 🔹 Un poco más grande
                              ),
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
