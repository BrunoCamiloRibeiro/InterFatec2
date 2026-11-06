import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lista_pessoas.dart';
import '../services/pessoa_service.dart';

/// Formatador de máscara para CPF: 000.000.000-00
class _MascaraCpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 11) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digitos.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digitos[i]);
    }

    final formatado = buffer.toString();
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}

/// Formatador de máscara para Telefone: (00) 00000-0000 ou (00) 0000-0000
class _MascaraTelefoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 11) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digitos.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (digitos.length <= 10) {
        if (i == 6) buffer.write('-');
      } else {
        if (i == 7) buffer.write('-');
      }
      buffer.write(digitos[i]);
    }

    final formatado = buffer.toString();
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}

/// Diálogo Modal de Formulário para Criação e Edição de Pessoas (Issue #34)
class FormularioPessoa extends StatefulWidget {
  /// Pessoa para edição (se nulo, opera em modo de criação)
  final PessoaItem? pessoaParaEditar;

  /// Callback opcional disparado após salvar com sucesso
  final void Function(PessoaItem pessoaSalva)? onSalvo;

  const FormularioPessoa({
    super.key,
    this.pessoaParaEditar,
    this.onSalvo,
  });

  @override
  State<FormularioPessoa> createState() => _FormularioPessoaState();
}

class _FormularioPessoaState extends State<FormularioPessoa> {
  final _formKey = GlobalKey<FormState>();

  late String _roleSelecionado;
  late TextEditingController _nomeController;
  late TextEditingController _cpfController;
  late TextEditingController _telefoneController;

  // Campos específicos de Paciente
  late TextEditingController _enderecoController;
  late TextEditingController _consultaController;

  // Campos específicos de Motorista
  late TextEditingController _cnhController;
  late TextEditingController _veiculoModeloController;
  late TextEditingController _veiculoPlacaController;

  // Campos específicos de Admin
  late TextEditingController _emailController;

  bool _salvando = false;
  String? _erroMensagem;

  bool get _isEdicao => widget.pessoaParaEditar != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pessoaParaEditar;

    _roleSelecionado = p?.role ?? 'paciente';
    _nomeController = TextEditingController(text: p?.nome ?? '');
    _cpfController = TextEditingController(text: p?.cpf ?? '');
    _telefoneController = TextEditingController(text: p?.telefone ?? '');

    // Inicializa campos contextuais
    _enderecoController = TextEditingController();
    _consultaController = TextEditingController();
    _cnhController = TextEditingController();
    _veiculoModeloController = TextEditingController();
    _veiculoPlacaController = TextEditingController();
    _emailController = TextEditingController();

    // Se estiver em modo edição, extrai detalhes contextuais conhecidos
    if (p != null && p.detalheExtra != null) {
      final extra = p.detalheExtra!;
      if (extra.startsWith('Consulta: ')) {
        _consultaController.text = extra.replaceFirst('Consulta: ', '');
      } else if (extra.startsWith('E-mail: ')) {
        _emailController.text = extra.replaceFirst('E-mail: ', '');
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _consultaController.dispose();
    _cnhController.dispose();
    _veiculoModeloController.dispose();
    _veiculoPlacaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
      _erroMensagem = null;
    });

    final nome = _nomeController.text.trim();
    final cpf = _cpfController.text.trim();
    final telefone = _telefoneController.text.trim();
    final role = _roleSelecionado;

    // Constrói detalhe contextual para exibição no card
    String? detalheExtra;
    Color badgeCor;
    String badgeLabel;

    if (role == 'paciente') {
      badgeCor = const Color(0xFF2563EB);
      badgeLabel = 'Paciente';
      final consulta = _consultaController.text.trim();
      if (consulta.isNotEmpty) detalheExtra = 'Consulta: $consulta';
    } else if (role == 'motorista') {
      badgeCor = const Color(0xFF0F172A);
      badgeLabel = 'Motorista';
      final mod = _veiculoModeloController.text.trim();
      final plc = _veiculoPlacaController.text.trim().toUpperCase();
      if (mod.isNotEmpty || plc.isNotEmpty) {
        detalheExtra = 'Veículo: $mod ${plc.isNotEmpty ? '($plc)' : ''}'.trim();
      }
    } else {
      badgeCor = const Color(0xFF7C3AED);
      badgeLabel = 'Administrador';
      final email = _emailController.text.trim();
      if (email.isNotEmpty) detalheExtra = 'E-mail: $email';
    }

    try {
      String idFinal = widget.pessoaParaEditar?.id ?? '';

      // Persistência no Cloud Firestore quando disponível
      if (_isFirebaseDisponivel()) {
        final col = FirebaseFirestore.instance.collection('usuarios');

        if (_isEdicao) {
          // UPDATE
          final payload = <String, dynamic>{
            'nome': nome,
            'cpf': cpf,
            'telefone': telefone,
            'atualizadoEm': FieldValue.serverTimestamp(),
          };

          if (role == 'paciente') {
            payload['localConsulta'] = _consultaController.text.trim();
            payload['enderecoPaciente'] = _enderecoController.text.trim();
          } else if (role == 'motorista') {
            payload['cnh'] = _cnhController.text.trim();
            payload['veiculoModelo'] = _veiculoModeloController.text.trim();
            payload['veiculoPlaca'] =
                _veiculoPlacaController.text.trim().toUpperCase();
          } else if (role == 'admin') {
            payload['email'] = _emailController.text.trim();
          }

          await col.doc(idFinal).update(payload);
        } else {
          // CREATE
          final docRef = col.doc();
          idFinal = docRef.id;

          final payload = <String, dynamic>{
            'nome': nome,
            'cpf': cpf,
            'telefone': telefone,
            'role': role,
            'ativo': true,
            'criadoEm': FieldValue.serverTimestamp(),
            'atualizadoEm': FieldValue.serverTimestamp(),
          };

          if (role == 'paciente') {
            payload['localConsulta'] = _consultaController.text.trim();
            payload['enderecoPaciente'] = _enderecoController.text.trim();
            payload['localSaida'] = 'Residência';
            payload['status'] = 0;
          } else if (role == 'motorista') {
            payload['cnh'] = _cnhController.text.trim();
            payload['veiculoModelo'] = _veiculoModeloController.text.trim();
            payload['veiculoPlaca'] =
                _veiculoPlacaController.text.trim().toUpperCase();
            payload['capacidadeVeiculo'] = 4;
            payload['emViagem'] = false;
          } else if (role == 'admin') {
            payload['email'] = _emailController.text.trim();
          }

          await docRef.set(payload);
        }
      } else {
        // Fallback para execução sem Firebase/Testes
        if (!_isEdicao) {
          idFinal = 'local_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      final pessoaResultante = PessoaItem(
        id: idFinal,
        nome: nome,
        cpf: cpf,
        telefone: telefone,
        role: role,
        badgeLabel: badgeLabel,
        badgeCor: badgeCor,
        detalheExtra: detalheExtra,
        status: widget.pessoaParaEditar?.status ?? 0,
        ativo: true,
      );

      widget.onSalvo?.call(pessoaResultante);

      if (mounted) {
        Navigator.of(context).pop(pessoaResultante);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erroMensagem = 'Falha ao salvar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isEdicao ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
            color: const Color(0xFF0F172A),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEdicao ? 'Editar Pessoa' : 'Nova Pessoa',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_erroMensagem != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      _erroMensagem!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Seleção de Papel (Role)
                const Text(
                  'Perfil de Acesso',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Paciente'),
                      selected: _roleSelecionado == 'paciente',
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: _roleSelecionado == 'paciente'
                            ? Colors.white
                            : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: _isEdicao
                          ? null
                          : (_) => setState(() => _roleSelecionado = 'paciente'),
                    ),
                    ChoiceChip(
                      label: const Text('Motorista'),
                      selected: _roleSelecionado == 'motorista',
                      selectedColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: _roleSelecionado == 'motorista'
                            ? Colors.white
                            : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: _isEdicao
                          ? null
                          : (_) => setState(() => _roleSelecionado = 'motorista'),
                    ),
                    ChoiceChip(
                      label: const Text('Administrador'),
                      selected: _roleSelecionado == 'admin',
                      selectedColor: const Color(0xFF7C3AED),
                      labelStyle: TextStyle(
                        color: _roleSelecionado == 'admin'
                            ? Colors.white
                            : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: _isEdicao
                          ? null
                          : (_) => setState(() => _roleSelecionado = 'admin'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Campo: Nome Completo
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo *',
                    hintText: 'Ex: Maria Silva Santos',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Informe o nome completo (mín. 3 letras)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo: CPF com validação matemática e máscara
                TextFormField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _MascaraCpfFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'CPF *',
                    hintText: '000.000.000-00',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (!ValidacaoPessoa.isCpfValido(val)) {
                      return 'CPF inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Campo: Telefone com máscara
                TextFormField(
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _MascaraTelefoneFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Telefone com DDD *',
                    hintText: '(14) 99876-5432',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final limpo = val?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (limpo.length < 10) {
                      return 'Informe DDD e telefone completos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ==========================================
                // CAMPOS ESPECÍFICOS POR PAPEL (ROLE)
                // ==========================================
                if (_roleSelecionado == 'paciente') ...[
                  TextFormField(
                    controller: _consultaController,
                    decoration: const InputDecoration(
                      labelText: 'Local da Consulta Médica',
                      hintText: 'Ex: Hospital de Base, AME Bauru',
                      prefixIcon: Icon(Icons.local_hospital_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _enderecoController,
                    decoration: const InputDecoration(
                      labelText: 'Endereço Residencial',
                      hintText: 'Ex: Rua das Flores, 123',
                      prefixIcon: Icon(Icons.home_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else if (_roleSelecionado == 'motorista') ...[
                  TextFormField(
                    controller: _cnhController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Número da CNH',
                      hintText: '01234567890',
                      prefixIcon: Icon(Icons.credit_card_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _veiculoModeloController,
                          decoration: const InputDecoration(
                            labelText: 'Modelo do Veículo',
                            hintText: 'Chevrolet Spin',
                            prefixIcon: Icon(Icons.directions_car_outlined, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _veiculoPlacaController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Placa',
                            hintText: 'BRA2E19',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_roleSelecionado == 'admin') ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail Corporativo/Admin',
                      hintText: 'admin@saude.sp.gov.br',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: _salvando ? null : _submeter,
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdicao ? 'Salvar Alterações' : 'Cadastrar'),
        ),
      ],
    );
  }
}
