import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';

import 'components/card_paciente.dart';
import 'components/footer_pacientes.dart';

class Motorista extends StatefulWidget {
  const Motorista({super.key});

  @override
  State<Motorista> createState() => _MotoristaState();
}

class _MotoristaState extends State<Motorista> {
  // Capacidade do veículo puxada diretamente do motorista no Firebase
  int _capacidadeVeiculo = 0;

  @override
  void initState() {
    super.initState();
    _ouvirDadosMotorista();
  }

  // Puxa e escuta em tempo real os dados do motorista (veículo, capacidade)
  void _ouvirDadosMotorista() {
    FirebaseFirestore.instance
        .collection('usuarios')
        .where('role', isEqualTo: 'motorista')
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        final motorista = MotoristaModel.fromMap(
          snapshot.docs.first.data(),
          docId: snapshot.docs.first.id,
        );
        setState(() {
          _capacidadeVeiculo = motorista.capacidadeVeiculo;
        });
      }
    });
  }

  // Troca por stream, para mudança de status imediata
  // Relacionando com o paciente_model.dart
  // Pegando o documento por id
  Stream<List<PacienteModel>> carregarPacientes() {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .where('role', isEqualTo: 'paciente')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PacienteModel.fromMap(doc.data(), docId: doc.id);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PacienteModel>>(
      stream: carregarPacientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Erro ao carregar os pacientes.')),
          );
        }

        final pacientes = snapshot.data ?? [];
        // Calcula os lugares ocupados (pacientes com status == 1 "Embarcou")
        final preenchidos = pacientes.where((p) => p.status == 1).length;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Lista de Passageiros'),
          ),
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final paciente in pacientes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey(
                        paciente.id.isNotEmpty ? paciente.id : paciente.nome,
                        // Agora que é um objeto não mais JSON puro ex: paciente['nomePaciente']
                      ),
                      direction: switch (paciente.status) {
                        0 => DismissDirection.endToStart,
                        4 => DismissDirection.startToEnd,
                        5 => DismissDirection.none,
                        _ => DismissDirection.horizontal,
                      },
                      background: Container(
                        padding: const EdgeInsets.only(left: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 50,
                            ),
                            Text(
                              'Retroceder',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        padding: const EdgeInsets.only(right: 16),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 50,
                            ),
                            Text(
                              'Avançar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final int statusAtual = paciente.status;
                        int novoStatus = statusAtual;

                        if (direction == DismissDirection.startToEnd) {
                          // INSERIR LÓGICA DE RETROCEDER STATUS
                          if (statusAtual > 0 && statusAtual < 5) {
                            novoStatus = statusAtual - 1;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Puxado da Esquerda para a Direita'),
                            ),
                          );
                        } else if (direction == DismissDirection.endToStart) {
                          // INSERIR LÓGICA DE AVANÇAR STATUS
                          if (statusAtual >= 0 && statusAtual < 4) {
                            novoStatus = statusAtual + 1;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Puxado da Direita para a Esquerda'),
                            ),
                          );
                        }
                        if (novoStatus != statusAtual) {
                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(paciente.id)
                              .update({'status': novoStatus});
                        }
                        return false;
                      },
                      child: CardPaciente(
                        // Alteração para objeto, não json
                        nomePaciente: paciente.nome,
                        enderecoPaciente: paciente.enderecoPaciente,
                        telPaciente: paciente.telefone,
                        localConsulta: paciente.localConsulta,
                        localSaida: paciente.localSaida,
                        status: paciente.status,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Rodapé compacto fixo na parte inferior da tela do motorista
          bottomNavigationBar: FooterPacientes(
            lugaresPreenchidos: preenchidos,
            // Puxa a capacidade real do veículo do motorista direto do Firestore!
            lugaresTotais: _capacidadeVeiculo,
          ),
        );
      },
    );
  }
}
