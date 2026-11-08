import 'package:flutter/material.dart';

class FiltroVeiculos {
  String busca;
  String status; // 'todos', 'disponivel', 'emViagem', 'emManutencao', 'inativo'
  String tipo; // 'todos', 'van', 'ambulancia', 'onibus', 'carro'
  bool possuiAC;
  bool possuiPreferencial;
  String faixaAssentos; // 'todos', 'ate_5', '6_a_15', 'mais_15'

  FiltroVeiculos({
    this.busca = '',
    this.status = 'todos',
    this.tipo = 'todos',
    this.possuiAC = false,
    this.possuiPreferencial = false,
    this.faixaAssentos = 'todos',
  });

  bool get temFiltrosAtivos =>
      status != 'todos' ||
      tipo != 'todos' ||
      possuiAC == true ||
      possuiPreferencial == true ||
      faixaAssentos != 'todos';

  int get quantidadeFiltrosAtivos {
    int qtd = 0;
    if (status != 'todos') qtd++;
    if (tipo != 'todos') qtd++;
    if (possuiAC) qtd++;
    if (possuiPreferencial) qtd++;
    if (faixaAssentos != 'todos') qtd++;
    return qtd;
  }

  void limpar() {
    status = 'todos';
    tipo = 'todos';
    possuiAC = false;
    possuiPreferencial = false;
    faixaAssentos = 'todos';
  }

  FiltroVeiculos clonar() {
    return FiltroVeiculos(
      busca: busca,
      status: status,
      tipo: tipo,
      possuiAC: possuiAC,
      possuiPreferencial: possuiPreferencial,
      faixaAssentos: faixaAssentos,
    );
  }
}

class ModalFiltrosVeiculo extends StatefulWidget {
  final FiltroVeiculos filtroAtual;

  const ModalFiltrosVeiculo({
    super.key,
    required this.filtroAtual,
  });

  @override
  State<ModalFiltrosVeiculo> createState() => _ModalFiltrosVeiculoState();
}

class _ModalFiltrosVeiculoState extends State<ModalFiltrosVeiculo> {
  late FiltroVeiculos _filtroTemp;

  @override
  void initState() {
    super.initState();
    _filtroTemp = widget.filtroAtual.clonar();
  }

  Widget _secaoTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[900],
        ),
      ),
    );
  }

  Widget _chipOpcao({
    required String label,
    required bool selecionado,
    required VoidCallback onTap,
    IconData? icone,
    Color? corIcone,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? Colors.blueGrey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? Colors.blueGrey[900]! : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(
                icone,
                size: 14,
                color: selecionado ? Colors.white : (corIcone ?? Colors.grey[700]),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selecionado ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BARRA DE ARRASTE SUTIL
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // CABEÇALHO DO MODAL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_outlined, color: Colors.blueGrey[900], size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtros de Veículos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filtroTemp.limpar();
                    });
                  },
                  child: const Text('Limpar'),
                ),
              ],
            ),
            const Divider(height: 1),

            // 1. FILTRO POR STATUS
            _secaoTitulo('Status Operacional'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipOpcao(
                  label: 'Todos',
                  selecionado: _filtroTemp.status == 'todos',
                  onTap: () => setState(() => _filtroTemp.status = 'todos'),
                ),
                _chipOpcao(
                  label: 'Disponível',
                  icone: Icons.circle,
                  corIcone: Colors.green,
                  selecionado: _filtroTemp.status == 'disponivel',
                  onTap: () => setState(() => _filtroTemp.status = 'disponivel'),
                ),
                _chipOpcao(
                  label: 'Em Viagem',
                  icone: Icons.circle,
                  corIcone: Colors.blue,
                  selecionado: _filtroTemp.status == 'emViagem',
                  onTap: () => setState(() => _filtroTemp.status = 'emViagem'),
                ),
                _chipOpcao(
                  label: 'Em Manutenção',
                  icone: Icons.circle,
                  corIcone: Colors.orange,
                  selecionado: _filtroTemp.status == 'emManutencao',
                  onTap: () => setState(() => _filtroTemp.status = 'emManutencao'),
                ),
                _chipOpcao(
                  label: 'Inativo',
                  icone: Icons.circle,
                  corIcone: Colors.grey,
                  selecionado: _filtroTemp.status == 'inativo',
                  onTap: () => setState(() => _filtroTemp.status = 'inativo'),
                ),
              ],
            ),

            // 2. FILTRO POR TIPO DE VEÍCULO
            _secaoTitulo('Tipo de Veículo'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipOpcao(
                  label: 'Todos',
                  selecionado: _filtroTemp.tipo == 'todos',
                  onTap: () => setState(() => _filtroTemp.tipo = 'todos'),
                ),
                _chipOpcao(
                  label: 'Van',
                  icone: Icons.airport_shuttle_outlined,
                  selecionado: _filtroTemp.tipo == 'van',
                  onTap: () => setState(() => _filtroTemp.tipo = 'van'),
                ),
                _chipOpcao(
                  label: 'Ambulância',
                  icone: Icons.emergency_outlined,
                  corIcone: Colors.red[700],
                  selecionado: _filtroTemp.tipo == 'ambulancia',
                  onTap: () => setState(() => _filtroTemp.tipo = 'ambulancia'),
                ),
                _chipOpcao(
                  label: 'Ônibus / Micro',
                  icone: Icons.directions_bus_outlined,
                  selecionado: _filtroTemp.tipo == 'onibus',
                  onTap: () => setState(() => _filtroTemp.tipo = 'onibus'),
                ),
                _chipOpcao(
                  label: 'Carro',
                  icone: Icons.directions_car_outlined,
                  selecionado: _filtroTemp.tipo == 'carro',
                  onTap: () => setState(() => _filtroTemp.tipo = 'carro'),
                ),
              ],
            ),

            // 3. FILTRO POR OPCIONAIS / EQUIPAMENTOS
            _secaoTitulo('Opcionais e Recursos'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipOpcao(
                  label: 'Com Ar-condicionado',
                  icone: Icons.ac_unit_outlined,
                  corIcone: Colors.blue,
                  selecionado: _filtroTemp.possuiAC,
                  onTap: () => setState(() => _filtroTemp.possuiAC = !_filtroTemp.possuiAC),
                ),
                _chipOpcao(
                  label: 'Acesso Preferencial / PCD',
                  icone: Icons.accessible_outlined,
                  corIcone: Colors.purple,
                  selecionado: _filtroTemp.possuiPreferencial,
                  onTap: () => setState(
                      () => _filtroTemp.possuiPreferencial = !_filtroTemp.possuiPreferencial),
                ),
              ],
            ),

            // 4. FILTRO POR CAPACIDADE DE ASSENTOS
            _secaoTitulo('Capacidade de Assentos'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipOpcao(
                  label: 'Qualquer capacidade',
                  selecionado: _filtroTemp.faixaAssentos == 'todos',
                  onTap: () => setState(() => _filtroTemp.faixaAssentos = 'todos'),
                ),
                _chipOpcao(
                  label: 'Até 5 lugares',
                  icone: Icons.chair_outlined,
                  selecionado: _filtroTemp.faixaAssentos == 'ate_5',
                  onTap: () => setState(() => _filtroTemp.faixaAssentos = 'ate_5'),
                ),
                _chipOpcao(
                  label: '6 a 15 lugares',
                  icone: Icons.event_seat_outlined,
                  selecionado: _filtroTemp.faixaAssentos == '6_a_15',
                  onTap: () => setState(() => _filtroTemp.faixaAssentos = '6_a_15'),
                ),
                _chipOpcao(
                  label: 'Mais de 15 lugares',
                  icone: Icons.groups_outlined,
                  selecionado: _filtroTemp.faixaAssentos == 'mais_15',
                  onTap: () => setState(() => _filtroTemp.faixaAssentos = 'mais_15'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // BOTÃO APLICAR FILTROS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(_filtroTemp);
                },
                child: const Text(
                  'Aplicar Filtros',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
