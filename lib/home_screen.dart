import 'package:flutter/material.dart';
import 'admin_screen.dart';
import 'trabajadores_screen.dart';
import 'usuariosDashboard.dart';
import 'trabajadoresDashboard.dart';
import 'recordatorios_screen.dart'; 

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
          width: 120,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
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
        backgroundColor: const Color.fromARGB(255, 218, 92, 230),
        centerTitle: true,
        automaticallyImplyLeading: false, // 🔹 Quita solo el botón de volver del AppBar
      ),
      body: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildCardButton(
              icon: Icons.person,
              title: "Clientes",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              },
            ),
            _buildCardButton(
              icon: Icons.engineering,
              title: "Trabajadores",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrabajadoresScreen()),
                );
              },
            ),
            _buildCardButton(
              icon: Icons.dashboard,
              title: "Clientes Dashboard",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsuariosDetalleScreen()),
                );
              },
            ),
            _buildCardButton(
              icon: Icons.bar_chart,
              title: "Trabajadores Dashboard",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrabajadoresDashboard()),
                );
              },
            ),
            _buildCardButton(
              icon: Icons.note,
              title: "Recordatorios",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecordatoriosScreen()),
                );
              },
            ),
            _buildCardButton(
              icon: Icons.logout,
              title: "Salir",
              onTap: () {
                Navigator.pop(context); // 🔹 Mantener el botón de salir
              },
            ),
          ],
        ),
      ),
    );
  }
}
