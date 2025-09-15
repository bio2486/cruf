import 'package:flutter/material.dart';
import 'admin_screen.dart';
import 'trabajadores_screen.dart';
import 'usuariosDashboard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Widget _buildCardButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 120, // 🔹 más pequeño
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent), // 🔹 icono más chico
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menú Principal"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildCardButton(
              icon: Icons.person,
              title: "Usuarios",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              },
            ),
            _buildCardButton(
              icon: Icons.settings,
              title: "Trabajadores",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrabajadoresScreen()),
                  );
              },
            ),
            _buildCardButton(
              icon: Icons.info,
              title: "Usuarios Dashboard",
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsuariosDetalleScreen()),
                  );
              },
            ),
            _buildCardButton(
              icon: Icons.logout,
              title: "Salir",
              onTap: () {
                Navigator.pop(context); // volver al login
              },
            ),
          ],
        ),
      ),
    );
  }
}
