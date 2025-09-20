import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode(); // 🔹 Para controlar el foco
  final FirebaseFirestore db = FirebaseFirestore.instance;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 🔹 Pedir foco automáticamente al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usernameFocus.requestFocus();
    });
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _error = "Introduce un usuario";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = await db
          .collection("admins")
          .where("username", isEqualTo: _usernameController.text.trim())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(usuario: ''), // 🔹 Ajusta según tu lógica
          ),
        );
      } else {
        setState(() {
          _error = "Usuario incorrecto";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error de conexión: $e";
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
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔹 Logo
                    Image.asset(
                      "assets/images/logo.png",
                      height: 100,
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      "Acceso Admin",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25),

                    // 🔹 Campo usuario
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _usernameController,
                        focusNode: _usernameFocus, // 🔹 Autofoco
                        autofocus: true, // 🔹 Abre teclado en móvil
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_loading) _login();
                        },
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

                    // 🔹 Mensaje de error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // 🔹 Botón login
                    SizedBox(
                      width: 280,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Text(
                                "Entrar",
                                style: TextStyle(fontSize: 17),
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
