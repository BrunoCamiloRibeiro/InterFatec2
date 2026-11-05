import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'components/card_dados_consulta.dart';
import 'components/card_identificacao_paciente.dart';
import 'components/card_tracking_paciente.dart';
import 'models/paciente_model.dart';

// Tela principal do Módulo do Paciente (Issue #18)
// Centraliza a identificação, dados da consulta agendada, tracking e botões de ação
class Paciente extends StatefulWidget {
  // Identificador opcional do paciente autenticado
  final String? pacienteId;
  // Stream customizada de paciente injetada externamente (útil para testes unitários)
  final Stream<PacienteModel?>? pacienteStreamOverride;

  const Paciente({super.key, this.pacienteId, this.pacienteStreamOverride});

  @override
  State<Paciente> createState() => _PacienteState();
}

class _PacienteState extends State<Paciente> {
  // Verifica se o Firebase foi inicializado
  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Retorna a stream de dados do paciente ativo em tempo real
  Stream<PacienteModel?> _carregarPaciente() {
    // Permite injeção de stream para testes automatizados
    if (widget.pacienteStreamOverride != null) {
      return widget.pacienteStreamOverride!;
    }

    if (_isFirebaseDisponivel()) {
      // Caso o ID tenha sido fornecido, escuta direto o documento dele
      if (widget.pacienteId != null) {
        return FirebaseFirestore.instance
            .collection('usuarios')
            .doc(widget.pacienteId)
            .snapshots()
            .map((doc) {
              if (!doc.exists || doc.data() == null) return null;
              return PacienteModel.fromMap(doc.data()!, docId: doc.id);
            });
      }

      // Senão, pega o primeiro paciente cadastrado para desenvolvimento
      return FirebaseFirestore.instance
          .collection('usuarios')
          .where('role', isEqualTo: 'paciente')
          .limit(1)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) return null;
            final doc = snapshot.docs.first;
            return PacienteModel.fromMap(doc.data(), docId: doc.id);
          });
    }

    // Mock de fallback com dados realistas caso execute offline ou sem Firebase
    return Stream.value(
      PacienteModel(
        id: 'p1',
        nome: 'Maria das Graças Aparecida',
        cpf: '123.456.789-00',
        telefone: '(17) 99123-4567',
        enderecoPaciente: 'Rua das Flores, 125 - Centro',
        localConsulta: 'Hospital de Base de São José do Rio Preto',
        localSaida: 'Residência',
        horarioConsulta: '14:30',
        nomeAcompanhante: 'José Aparecido',
        status: 0,
        criadoEm: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PacienteModel?>(
      stream: _carregarPaciente(),
      builder: (context, snapshot) {
        // Estado de carregamento inicial
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F8FA),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final paciente = snapshot.data;

        // Caso nenhum registro seja localizado
        if (paciente == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: const Text('Painel do Paciente'),
            ),
            body: const Center(
              child: Text(
                'Nenhum dado de paciente encontrado.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
            ),
            title: const Text(
              'Painel do Paciente',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          // Layout responsivo adaptável a 100% da largura da tela, assim como a Lista de Passageiros
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. COMPONENTE: Card de Identificação do Paciente
                  CardIdentificacaoPaciente(
                    nome: paciente.nome,
                    cpf: paciente.cpf,
                    status: paciente.status,
                  ),
                  const SizedBox(height: 16),

                  // 2. COMPONENTE: Card com Dados da Consulta
                  CardDadosConsulta(
                    localConsulta: paciente.localConsulta,
                    horarioConsulta: paciente.horarioConsulta,
                    localSaida: paciente.localSaida,
                    enderecoPaciente: paciente.enderecoPaciente,
                    nomeAcompanhante: paciente.nomeAcompanhante,
                  ),
                  const SizedBox(height: 16),

                  // 3. BOTÕES DE AÇÃO: Primário ("Estou Pronto") e Secundário ("Fui embora")
                  Row(
                    children: [
                      // Botão Secundário: Fui embora (Carona)
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFB83227),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: const Color(0xFFFFFDF8),
                            ),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Color(0xFFB83227),
                              size: 18,
                            ),
                            label: const Text(
                              'Fui embora',
                              style: TextStyle(
                                color: Color(0xFFB83227),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              // TODO: Implementar backend do botão Fui embora / Carona (Issue #19)
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Botão Primário: Estou Pronto
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Estou Pronto',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              // TODO: Implementar backend do botão Estou Pronto (Issue #19)
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. COMPONENTE: Card com Espaço Reservado para o Tracking
                  const CardTrackingPaciente(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
