import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../lista_pessoas.dart';
import '../models/admin_model.dart';
import '../models/motorista_model.dart';
import '../models/paciente_model.dart';

/// Resultado encapsulado de operações no backend de Pessoas
class ResultadoOperacaoPessoa {
  final bool sucesso;
  final String? id;
  final String? mensagemErro;

  const ResultadoOperacaoPessoa._({
    required this.sucesso,
    this.id,
    this.mensagemErro,
  });

  factory ResultadoOperacaoPessoa.sucesso([String? id]) =>
      ResultadoOperacaoPessoa._(sucesso: true, id: id);

  factory ResultadoOperacaoPessoa.erro(String mensagem) =>
      ResultadoOperacaoPessoa._(sucesso: false, mensagemErro: mensagem);
}

/// Validador puro de dados cadastrais (Camada 1: Client-Side Schema Validation)
class ValidacaoPessoa {
  /// Validação do algoritmo oficial do CPF (Dígitos Verificadores em Módulo 11)
  static bool isCpfValido(String? cpf) {
    if (cpf == null) return false;
    final limpo = cpf.replaceAll(RegExp(r'\D'), '');

    if (limpo.length != 11) return false;

    // Rejeita padrões com todos os dígitos idênticos (ex: 111.111.111-11)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(limpo)) return false;

    // Primeiro dígito verificador
    int soma1 = 0;
    for (int i = 0; i < 9; i++) {
      soma1 += int.parse(limpo[i]) * (10 - i);
    }
    int digito1 = 11 - (soma1 % 11);
    if (digito1 >= 10) digito1 = 0;
    if (int.parse(limpo[9]) != digito1) return false;

    // Segundo dígito verificador
    int soma2 = 0;
    for (int i = 0; i < 10; i++) {
      soma2 += int.parse(limpo[i]) * (11 - i);
    }
    int digito2 = 11 - (soma2 % 11);
    if (digito2 >= 10) digito2 = 0;
    if (int.parse(limpo[10]) != digito2) return false;

    return true;
  }

  /// Valida conjunto completo de campos de pessoa antes do envio à rede
  static String? validarDados({
    required String nome,
    required String cpf,
    required String telefone,
    required String role,
  }) {
    if (nome.trim().length < 3) {
      return 'O nome deve conter pelo menos 3 caracteres.';
    }
    if (!isCpfValido(cpf)) {
      return 'O CPF informado é inválido.';
    }
    final telLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    if (telLimpo.length < 10 || telLimpo.length > 11) {
      return 'Informe um telefone com DDD válido (10 ou 11 dígitos).';
    }
    const rolesValidos = {'paciente', 'motorista', 'admin', 'administrador'};
    if (!rolesValidos.contains(role.toLowerCase())) {
      return 'Papel de usuário inválido: $role.';
    }
    return null; // Dados válidos
  }
}

/// Serviço de Backend para Gestão de Pessoas (CRUD, Governança e LGPD no Cloud Firestore)
class PessoaService {
  final FirebaseFirestore _firestore;

  PessoaService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _colecao =>
      _firestore.collection('usuarios');

  bool get _isFirebaseDisponivel {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Stream em tempo real da listagem de pessoas com filtros eficientes
  Stream<List<PessoaItem>> listarPessoasStream({
    String role = 'todos',
    bool apenasAtivos = true,
  }) {
    if (!_isFirebaseDisponivel) {
      return Stream.value(const []);
    }

    Query<Map<String, dynamic>> query = _colecao;

    if (apenasAtivos) {
      query = query.where('ativo', isEqualTo: true);
    }

    if (role != 'todos') {
      query = query.where('role', isEqualTo: role);
    }

    return query.snapshots().map((snapshot) {
      final lista = <PessoaItem>[];
      for (final doc in snapshot.docs) {
        try {
          final dados = doc.data();
          final papel = (dados['role'] ?? 'paciente').toString().toLowerCase();

          if (papel == 'admin' || papel == 'administrador') {
            lista.add(PessoaItem.fromAdmin(AdminModel.fromMap(dados, docId: doc.id)));
          } else if (papel == 'motorista') {
            lista.add(PessoaItem.fromMotorista(MotoristaModel.fromMap(dados, docId: doc.id)));
          } else {
            lista.add(PessoaItem.fromPaciente(PacienteModel.fromMap(dados, docId: doc.id)));
          }
        } catch (e) {
          debugPrint('Aviso: documento ${doc.id} ignorado por formato incompatível: $e');
        }
      }
      return lista;
    });
  }

  /// Cria uma nova pessoa utilizando ID auto-gerado do Firestore (nunca CPF)
  /// e carimbos de data e hora do servidor (serverTimestamp)
  Future<ResultadoOperacaoPessoa> criarPessoa({
    required String nome,
    required String cpf,
    required String telefone,
    required String role,
    Map<String, dynamic>? camposExtras,
  }) async {
    // 1. Validação em Camada de Aplicação (Client Validation)
    final erroValidacao = ValidacaoPessoa.validarDados(
      nome: nome,
      cpf: cpf,
      telefone: telefone,
      role: role,
    );
    if (erroValidacao != null) {
      return ResultadoOperacaoPessoa.erro(erroValidacao);
    }

    if (!_isFirebaseDisponivel) {
      return ResultadoOperacaoPessoa.erro('Firebase não inicializado nesta sessão.');
    }

    try {
      // 2. Criação com ID automático gerado pelo Firestore (Anti-pattern do CPF como ID eliminado)
      final novoDocRef = _colecao.doc();

      final payload = <String, dynamic>{
        'nome': nome.trim(),
        'cpf': cpf.trim(),
        'telefone': telefone.trim(),
        'role': role.toLowerCase().trim(),
        'ativo': true,
        // Carimbos gerados pelo servidor no momento da gravação
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
        ...?camposExtras,
      };

      await novoDocRef.set(payload);
      return ResultadoOperacaoPessoa.sucesso(novoDocRef.id);
    } on FirebaseException catch (e) {
      return ResultadoOperacaoPessoa.erro(_traduzirErroFirebase(e));
    } catch (e) {
      return ResultadoOperacaoPessoa.erro('Falha inesperada ao cadastrar: $e');
    }
  }

  /// Atualiza os dados de uma pessoa garantindo a imutabilidade do criadoEm
  Future<ResultadoOperacaoPessoa> atualizarPessoa({
    required String id,
    required String nome,
    required String cpf,
    required String telefone,
    Map<String, dynamic>? camposExtras,
  }) async {
    final erroValidacao = ValidacaoPessoa.validarDados(
      nome: nome,
      cpf: cpf,
      telefone: telefone,
      role: 'paciente', // validação estrutural
    );
    if (erroValidacao != null) {
      return ResultadoOperacaoPessoa.erro(erroValidacao);
    }

    if (!_isFirebaseDisponivel) {
      return ResultadoOperacaoPessoa.erro('Firebase indisponível.');
    }

    try {
      final docRef = _colecao.doc(id);

      final payload = <String, dynamic>{
        'nome': nome.trim(),
        'cpf': cpf.trim(),
        'telefone': telefone.trim(),
        // Garante atualização do carimbo temporal sem mutar o criadoEm original
        'atualizadoEm': FieldValue.serverTimestamp(),
        ...?camposExtras,
      };

      await docRef.update(payload);
      return ResultadoOperacaoPessoa.sucesso(id);
    } on FirebaseException catch (e) {
      return ResultadoOperacaoPessoa.erro(_traduzirErroFirebase(e));
    } catch (e) {
      return ResultadoOperacaoPessoa.erro('Falha ao atualizar dados: $e');
    }
  }

  /// Exclusão Lógica (Soft Delete) em conformidade com as diretrizes da LGPD
  /// e auditoria pública de viagens do transporte sanitário
  Future<ResultadoOperacaoPessoa> inativarPessoa(String id) async {
    if (!_isFirebaseDisponivel) {
      return ResultadoOperacaoPessoa.erro('Firebase indisponível.');
    }

    try {
      await _colecao.doc(id).update({
        'ativo': false,
        'inativadoEm': FieldValue.serverTimestamp(),
      });
      return ResultadoOperacaoPessoa.sucesso(id);
    } on FirebaseException catch (e) {
      return ResultadoOperacaoPessoa.erro(_traduzirErroFirebase(e));
    } catch (e) {
      return ResultadoOperacaoPessoa.erro('Falha ao inativar registro: $e');
    }
  }

  /// Mapeia códigos técnicos do Firebase para mensagens amigáveis em português
  String _traduzirErroFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permissão negada pelas regras de segurança (Security Rules).';
      case 'not-found':
        return 'Registro não encontrado no banco de dados.';
      case 'unavailable':
        return 'Servidor temporariamente indisponível. Verifique sua conexão.';
      case 'already-exists':
        return 'Já existe um registro com os dados informados.';
      default:
        return 'Erro do banco de dados: ${e.message ?? e.code}';
    }
  }
}
