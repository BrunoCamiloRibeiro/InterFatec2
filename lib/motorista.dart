import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/viagem_service.dart';

import 'components/card_paciente.dart';
import 'components/footer_pacientes.dart';

class Motorista extends StatefulWidget {
  // Viagem inicial informada para exibição dos dados na tela
  final ViagemModel? viagemInicial;
  // Instância customizada do serviço de viagens
  final ViagemService? viagemServiceOverride;
  // Stream de pacientes injetada externamente
  final Stream<List<PacienteModel>>? pacientesStreamOverride;

  const Motorista({
    super.key,
    this.viagemInicial,
    this.viagemServiceOverride,
    this.pacientesStreamOverride,
  });

  @override
  State<Motorista> createState() => _MotoristaState();
}

class _MotoristaState extends State<Motorista> {
  // Instância do serviço de viagens
  late final ViagemService _viagemService;

  // Inscrição para escutar mudanças no estado da viagem ativa
  StreamSubscription<ViagemModel?>? _subViagemAtiva;

  // Viagem ativa associada à sessão do motorista
  ViagemModel? _viagemAtiva;

  // Capacidade do veículo obtida dos dados do motorista
  int _capacidadeVeiculo = 0;

  // Verifica se existem instâncias ativas do Firebase inicializadas
  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _viagemService = widget.viagemServiceOverride ?? ViagemService();

    // Inicializa a variável com a viagem fornecida no construtor
    _viagemAtiva = widget.viagemInicial;

    // Assina a stream de atualização da viagem ativa
    _subViagemAtiva = _viagemService.viagemAtivaStream.listen((viagem) {
      if (mounted) {
        setState(() {
          _viagemAtiva = viagem;
        });
      }
    });

    // Inicia a escuta dos dados do motorista caso o Firebase esteja disponível
    if (_isFirebaseDisponivel()) {
      _ouvirDadosMotorista();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Obtém os argumentos de rota contendo a viagem iniciada
    if (_viagemAtiva == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ViagemModel) {
        _viagemAtiva = args;
      }
    }
  }

  @override
  void dispose() {
    // Cancela a inscrição na stream de viagem ativa
    _subViagemAtiva?.cancel();
    super.dispose();
  }

  // Consulta os dados do motorista na coleção 'usuarios' do Firestore
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

  // Retorna a stream de pacientes cadastrados
  Stream<List<PacienteModel>> carregarPacientes() {
    if (widget.pacientesStreamOverride != null) {
      return widget.pacientesStreamOverride!;
    }

    if (_isFirebaseDisponivel()) {
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

    // Retorna lista com pacientes de teste quando o Firebase não está disponível
    return Stream.value([
      PacienteModel(
        id: 'p1',
        nome: 'Maria das Graças Aparecida',
        cpf: '123.456.789-00',
        enderecoPaciente: 'Rua das Flores, 125 - Centro',
        telefone: '(17) 99123-4567',
        localConsulta: 'Hospital de Base',
        localSaida: 'Laboratório de Análises Clínicas',
        status: 0,
      ),
      PacienteModel(
        id: 'p2',
        nome: 'Carlos Eduardo Martins',
        cpf: '987.654.321-00',
        enderecoPaciente: 'Rua dos Ipês, 310',
        telefone: '(17) 99456-7890',
        localConsulta: 'AME São José do Rio Preto',
        localSaida: 'Centro de Diagnóstico por Imagem',
        status: 1,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Define lista inicial de pacientes quando o Firebase não está disponível
    final pacientesIniciais = _isFirebaseDisponivel()
        ? null
        : [
            PacienteModel(
              id: 'p1',
              nome: 'Maria das Graças Aparecida',
              cpf: '123.456.789-00',
              enderecoPaciente: 'Rua das Flores, 125 - Centro',
              telefone: '(17) 99123-4567',
              localConsulta: 'Hospital de Base',
              localSaida: 'Laboratório de Análises Clínicas',
              status: 0,
            ),
            PacienteModel(
              id: 'p2',
              nome: 'Carlos Eduardo Martins',
              cpf: '987.654.321-00',
              enderecoPaciente: 'Rua dos Ipês, 310',
              telefone: '(17) 99456-7890',
              localConsulta: 'AME São José do Rio Preto',
              localSaida: 'Centro de Diagnóstico por Imagem',
              status: 1,
            ),
          ];

    return StreamBuilder<List<PacienteModel>>(
      initialData: pacientesIniciais,
      stream: carregarPacientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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

        int preenchidos = 0;
        // Passageiros a bordo: status 1 (Ida) ou status 3 (Volta). Se houver acompanhante, ocupa 2 vagas
        for (var p in pacientes.where((p) => p.status == 1 || p.status == 3)) {
          preenchidos += (p.nomeAcompanhante?.isNotEmpty == true) ? 2 : 1;
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Retorna à tela anterior ou redireciona para a rota inicial
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
            ),
            title: const Text('Lista de Passageiros'),
            actions: [
              // Exibe a placa do veículo associado à viagem ativa
              if (_viagemAtiva != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Em Viagem: ${_viagemAtiva!.veiculoPlaca}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
                          color: Colors.red.withValues(alpha: 0.4),
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
                          color: Colors.green.withValues(alpha: 0.4),
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

                        // Decrementa o status do paciente ao arrastar da esquerda para a direita
                        if (direction == DismissDirection.startToEnd) {
                          if (statusAtual > 0 && statusAtual < 5) {
                            novoStatus = statusAtual - 1;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Puxado da Esquerda para a Direita',
                              ),
                            ),
                          );
                          // Incrementa o status do paciente ao arrastar da direita para a esquerda
                        } else if (direction == DismissDirection.endToStart) {
                          if (statusAtual >= 0 && statusAtual < 4) {
                            novoStatus = statusAtual + 1;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Puxado da Direita para a Esquerda',
                              ),
                            ),
                          );
                        }
                        // Atualiza o status do paciente no Firestore caso tenha sido alterado
                        if (novoStatus != statusAtual &&
                            _isFirebaseDisponivel()) {
                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(paciente.id)
                              .update({'status': novoStatus});
                        }
                        return false;
                      },
                      child: CardPaciente(
                        nomePaciente: paciente.nome,
                        enderecoPaciente: paciente.enderecoPaciente,
                        telPaciente: paciente.telefone,
                        localConsulta: paciente.localConsulta,
                        localSaida: paciente.localSaida,
                        status: paciente.status,
                        // Repassa os dados do acompanhante para o card
                        nomeAcompanhante: paciente.nomeAcompanhante,
                        telAcompanhante: paciente.telAcompanhante,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: FooterPacientes(
            lugaresPreenchidos: preenchidos,
            lugaresTotais: _capacidadeVeiculo,
            viagem: _viagemAtiva,
            pacientes: pacientes,
          ),
        );
      },
    );
  }
}
