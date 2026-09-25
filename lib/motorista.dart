import 'package:flutter/material.dart';

// tela da lista de passageiros sem Scaffold e recheada de Material
class Motorista extends StatelessWidget {
  Motorista({super.key});

  @override
  Widget build(BuildContext context) {
    // Material direto no lugar de Scaffold
    return Material(
      color: Color(0xFFF7F8FA),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // cabeçalho na mão já que não tem AppBar do Scaffold
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Lista de Passageiros',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                  ), // gambiarra pra centralizar o texto certinho
                ],
              ),
              SizedBox(height: 10),

              // Card 1: Maria das Dores Silva (laranja)
              _cardPassageiro(
                nome: 'Maria das Dores Silva',
                horario: '07:30',
                local: 'Hospital Santa Casa - Nefrologia',
                corBarra: Colors.orange,
                idaAtiva: true,
                voltaAtiva: false,
                textoAcao: 'Toque para confirmar Volta',
                corAcao: Colors.orange,
              ),
              SizedBox(height: 12),

              // Card 2: José de Alencar Santos (cinza)
              _cardPassageiro(
                nome: 'José de Alencar Santos',
                horario: '09:00',
                local: 'Clínica de Olhos - Consulta',
                corBarra: Colors.grey.shade400,
                idaAtiva: false,
                voltaAtiva: false,
                textoAcao: 'Toque para confirmar Ida',
                corAcao: Colors.grey.shade600,
              ),
              SizedBox(height: 12),

              // Card 3: Francisca Pereira Lima (verde/concluído)
              _cardPassageiro(
                nome: 'Francisca Pereira Lima',
                horario: '11:15',
                local: 'Centro de Reabilitação - Fisioterapia',
                corBarra: Colors.green,
                idaAtiva: true,
                voltaAtiva: true,
                textoAcao: 'Concluído',
                corAcao: Colors.green,
              ),
              SizedBox(height: 12),

              // Card 4: Antônio Marcos Souza (cinza)
              _cardPassageiro(
                nome: 'Antônio Marcos Souza',
                horario: '14:00',
                local: 'Hospital Universitário - Oncologia',
                corBarra: Colors.grey.shade400,
                idaAtiva: false,
                voltaAtiva: false,
                textoAcao: 'Toque para confirmar Ida',
                corAcao: Colors.grey.shade600,
              ),
              SizedBox(height: 25),

              // botão que o professor pediu lá embaixo pra gerar lista para assinar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  icon: Icon(Icons.assignment_outlined, size: 18),
                  label: Text(
                    'Gerar lista para assinar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    // dialog em vez de snackbar já que não temos Scaffold
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Lista de Presença'),
                        content: Text(
                          'Lista gerada para assinatura! (fictício)',
                        ),
                        actions: [
                          TextButton(
                            child: Text('OK'),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // card feito usando Material em vez de Container com decoration
  static Widget _cardPassageiro({
    required String nome,
    required String horario,
    required String local,
    required Color corBarra,
    required bool idaAtiva,
    required bool voltaAtiva,
    required String textoAcao,
    required Color corAcao,
  }) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias, // corta a barrinha de cima certinho
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // barrinha colorida de cima
          Container(height: 4, color: corBarra),
          Padding(
            padding: EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // linha com nome e horário
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          horario,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                // linha com o local
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        local,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // badges e texto de ação
                Row(
                  children: [
                    _badgeStatus(
                      label: idaAtiva ? 'IDA ✓' : 'IDA',
                      ativo: idaAtiva,
                      corAtivo: corBarra,
                    ),
                    SizedBox(width: 6),
                    _badgeStatus(
                      label: voltaAtiva ? 'VOLTA ✓' : 'VOLTA',
                      ativo: voltaAtiva,
                      corAtivo: corBarra,
                    ),
                    Spacer(),
                    Text(
                      textoAcao,
                      style: TextStyle(
                        fontSize: 11,
                        color: corAcao,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // badge usando Material com borderRadius
  static Widget _badgeStatus({
    required String label,
    required bool ativo,
    required Color corAtivo,
  }) {
    return Material(
      color: ativo ? corAtivo.withValues(alpha: 0.12) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: ativo ? corAtivo : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
