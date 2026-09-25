import 'package:flutter/material.dart';

// tela de login sem Scaffold pq o professor mandou usar Material em tudo
class Login extends StatefulWidget {
  Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // dropdown feio no canto só pro professor testar os cargos e não encher meu saco
  String cargoDebug = 'Administrador';

  // controladores que nem vou dar dispose pq esqueci como faz
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // trocado Scaffold por Material raiz com SafeArea
    return Material(
      color: Color(0xFFF7F8FA),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 10),
              // linha do topo pro dropdown de debug já que tirei o Scaffold e o AppBar
              Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cargo: ',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        DropdownButton<String>(
                          value: cargoDebug,
                          isDense: true,
                          underline:
                              SizedBox(), // gambiarra pra sumir com a linha
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Administrador',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'Motorista',
                              child: Text('Motorista'),
                            ),
                            DropdownMenuItem(
                              value: 'Paciente',
                              child: Text('Paciente'),
                            ),
                          ],
                          onChanged: (novo) {
                            setState(() {
                              cargoDebug = novo!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // ícone genérico pq não tenho logo ainda
              Center(
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0xFF0F172A),
                  child: Icon(
                    Icons.directions_bus,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Acesse sua Conta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Digite seus dados para entrar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              SizedBox(height: 35),

              // campo nome
              Text(
                'NOME OU USUÁRIO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 6),
              Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: TextField(
                  controller: userController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Carlos Silva',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // campo senha
              Text(
                'SENHA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 6),
              Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                child: TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 28),

              // botão entrar com if de principiante
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  if (cargoDebug == 'Administrador') {
                    Navigator.pushNamed(context, '/administrativo');
                  } else if (cargoDebug == 'Motorista') {
                    Navigator.pushNamed(context, '/motorista');
                  } else {
                    Navigator.pushNamed(context, '/paciente');
                  }
                },
                child: Text(
                  'Entrar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 12),

              // botão registrar-se que joga pra tela de cadastro
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: Text(
                  'Registrar-se',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
