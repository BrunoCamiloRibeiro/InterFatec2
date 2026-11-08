// ============================================================================
// ARQUIVO: lib/Outdated/administrativo.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa um protótipo visual legado da tela de painel do administrador
// (StatelessWidget "Administrativo"). Contém atalhos para telas de pacientes e
// motoristas, um formulário de cadastro de paciente estático e uma lista simulada
// de últimos pacientes escalados, renderizados sobre widgets Material puros.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Código Legado / Obsoleto arquivado (pasta lib/Outdated/). Substituído na
// evolução do projeto pela tela de gestão de pessoas (lib/lista_pessoas.dart)
// e painel administrativo oficial.
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - lib/Outdated/login.dart: navegado via Navigator.pushNamed('/administrativo').
// - Não é mais utilizado no fluxo principal de produção nem na rota raiz.
//
// DE ONDE RECEBE DADOS:
// - Dados puramente estáticos e visuais (hardcoded), sem consumo de banco de dados
//   ou APIs externas.
//
// O QUE EXPORTA / EXPÕE:
// - class Administrativo extends StatelessWidget: Widget do painel legado.
//
// ORIGEM HISTÓRICA:
// Criado no início do projeto nos commits prototípicos da equipe (commit 4651c09,
// 22b8657) e arquivado para a pasta Outdated no commit 588756d.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart: componentes de UI.
// - Efeitos colaterais: apenas navegação de tela e abertura de AlertDialog estático.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - Construído sem Scaffold, utilizando Material como container raiz.
// - Os campos de formulário não possuem controllers nem persistência real.
// ============================================================================
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';

// tela do administrador sem Scaffold e entupida de Material
// Declaração do StatelessWidget legado representando o painel do administrador
class Administrativo extends StatelessWidget {
  // Construtor do widget administrativo que aceita uma chave opcional
  Administrativo({super.key});

  // Sobrescrita do método build responsável por descrever a interface gráfica
  @override
  // Constrói e retorna a árvore de widgets da tela legada
  Widget build(BuildContext context) {
    // Material no lugar de Scaffold
    // Utiliza Material como elemento raiz da tela para gerenciar tema e plano de fundo
    return Material(
      // Define a cor de fundo cinza clara personalizada
      color: Color(0xFFF7F8FA),
      // Envolve o conteúdo em SafeArea para respeitar entalhes e barras do sistema
      child: SafeArea(
        // Habilita rolagem vertical para permitir a visualização em telas menores
        child: SingleChildScrollView(
          // Define recuo horizontal de 20 pixels nas margens da tela
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          // Organiza os blocos da página em uma coluna vertical
          child: Column(
            // Alinha todos os filhos à esquerda da coluna
            crossAxisAlignment: CrossAxisAlignment.start,
            // Lista de componentes dispostos sequencialmente
            children: [
              // Espaçador vertical superior
              SizedBox(height: 8),
              // botão de voltar na mão
              // Alinha o botão de voltar à esquerda
              Align(
                // Alinhamento centralizado à esquerda
                alignment: Alignment.centerLeft,
                // Botão com ícone para retroceder
                child: IconButton(
                  // Ícone de seta preta de retorno
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  // Ação executada ao tocar no botão voltar
                  onPressed: () {
                    // Desempilha a tela atual e retorna à anterior
                    Navigator.pop(context);
                  // Fechamento do callback onPressed
                  },
                // Fechamento do IconButton
                ),
              // Fechamento do Align
              ),
              // Espaçador vertical
              SizedBox(height: 4),

              // cabeçalho igualzinho tava no figma
              // Título principal do painel administrativo
              Text(
                // Texto do título
                'Gestão de Transporte',
                // Estilo tipográfico do título
                style: TextStyle(
                  // Tamanho da fonte
                  fontSize: 22,
                  // Peso da fonte em negrito
                  fontWeight: FontWeight.bold,
                  // Cor preta suave
                  color: Colors.black87,
                // Fechamento do TextStyle
                ),
              // Fechamento do Text
              ),
              // Espaçador vertical sutil
              SizedBox(height: 2),
              // Subtítulo do painel administrativo
              Text(
                // Texto descritivo
                'Painel do Administrador',
                // Estilo tipográfico do subtítulo
                style: TextStyle(fontSize: 13, color: Colors.grey),
              // Fechamento do Text
              ),
              // Espaçador vertical
              SizedBox(height: 18),

              // 4 botões de atalho em Material
              // Primeira linha de botões de atalho (Pacientes e Motoristas)
              Row(
                // Filhos dispostos lado a lado
                children: [
                  // Primeiro atalho ocupando largura proporcional
                  Expanded(
                    // Contêiner Material para fornecer elevação e cantos arredondados
                    child: Material(
                      // Elevação de sombra sutil
                      elevation: 1,
                      // Fundo branco
                      color: Colors.white,
                      // Cantos arredondados
                      borderRadius: BorderRadius.circular(10),
                      // Botão delineado com ícone para atalho de Pacientes
                      child: OutlinedButton.icon(
                        // Estilização do botão delineado
                        style: OutlinedButton.styleFrom(
                          // Cor do texto e ícone
                          foregroundColor: Colors.black87,
                          // Espaçamento vertical interno
                          padding: EdgeInsets.symmetric(vertical: 12),
                          // Borda cinza suave
                          side: BorderSide(color: Colors.grey.shade300),
                          // Formato com cantos arredondados
                          shape: RoundedRectangleBorder(
                            // Raio de 10 pixels
                            borderRadius: BorderRadius.circular(10),
                          // Fechamento do RoundedRectangleBorder
                          ),
                        // Fechamento do OutlinedButton.styleFrom
                        ),
                        // Ícone representativo de pessoa/paciente
                        icon: Icon(Icons.person_outline, size: 18),
                        // Rótulo textual do botão
                        label: Text(
                          // Texto exibido
                          'Pacientes',
                          // Tamanho da fonte
                          style: TextStyle(fontSize: 12),
                        // Fechamento do Text
                        ),
                        // Ação ao clicar no atalho
                        onPressed: () {
                          // Navega para a rota de paciente
                          Navigator.pushNamed(context, '/paciente');
                        // Fechamento do onPressed
                        },
                      // Fechamento do OutlinedButton.icon
                      ),
                    // Fechamento do Material
                    ),
                  // Fechamento do Expanded
                  ),
                  // Espaçamento horizontal entre os dois botões
                  SizedBox(width: 10),
                  // Segundo atalho ocupando largura proporcional
                  Expanded(
                    // Contêiner Material para fornecer elevação
                    child: Material(
                      // Elevação de sombra sutil
                      elevation: 1,
                      // Fundo branco
                      color: Colors.white,
                      // Cantos arredondados
                      borderRadius: BorderRadius.circular(10),
                      // Botão delineado com ícone para atalho de Motoristas
                      child: OutlinedButton.icon(
                        // Estilização do botão delineado
                        style: OutlinedButton.styleFrom(
                          // Cor do texto e ícone
                          foregroundColor: Colors.black87,
                          // Espaçamento vertical interno
                          padding: EdgeInsets.symmetric(vertical: 12),
                          // Borda cinza suave
                          side: BorderSide(color: Colors.grey.shade300),
                          // Formato com cantos arredondados
                          shape: RoundedRectangleBorder(
                            // Raio de 10 pixels
                            borderRadius: BorderRadius.circular(10),
                          // Fechamento do RoundedRectangleBorder
                          ),
                        // Fechamento do OutlinedButton.styleFrom
                        ),
                        // Ícone de automóvel
                        icon: Icon(Icons.directions_car_outlined, size: 18),
                        // Rótulo textual do botão
                        label: Text(
                          // Texto exibido
                          'Motoristas',
                          // Tamanho da fonte
                          style: TextStyle(fontSize: 12),
                        // Fechamento do Text
                        ),
                        // Ação ao clicar no atalho
                        onPressed: () {
                          // Navega para a rota de motorista
                          Navigator.pushNamed(context, '/motorista');
                        // Fechamento do onPressed
                        },
                      // Fechamento do OutlinedButton.icon
                      ),
                    // Fechamento do Material
                    ),
                  // Fechamento do Expanded
                  ),
                // Fechamento dos filhos da Row
                ],
              // Fechamento da Row
              ),
              // Espaçador vertical
              SizedBox(height: 8),
              // Segunda linha de botões de atalho (Escalas)
              Row(
                // Filhos dispostos lado a lado
                children: [
                  // Primeiro atalho de escala ocupando largura proporcional
                  Expanded(
                    // Contêiner Material com elevação
                    child: Material(
                      // Elevação de sombra sutil
                      elevation: 1,
                      // Fundo branco
                      color: Colors.white,
                      // Cantos arredondados
                      borderRadius: BorderRadius.circular(10),
                      // Botão com ícone para Escala de Pacientes
                      child: OutlinedButton.icon(
                        // Estilização do botão delineado
                        style: OutlinedButton.styleFrom(
                          // Cor do texto e ícone
                          foregroundColor: Colors.black87,
                          // Espaçamento vertical interno
                          padding: EdgeInsets.symmetric(vertical: 12),
                          // Borda cinza suave
                          side: BorderSide(color: Colors.grey.shade300),
                          // Formato com cantos arredondados
                          shape: RoundedRectangleBorder(
                            // Raio de 10 pixels
                            borderRadius: BorderRadius.circular(10),
                          // Fechamento do RoundedRectangleBorder
                          ),
                        // Fechamento do OutlinedButton.styleFrom
                        ),
                        // Ícone de calendário diário
                        icon: Icon(Icons.calendar_today_outlined, size: 18),
                        // Rótulo textual do botão
                        label: Text(
                          // Texto abreviado
                          'Escala P.',
                          // Tamanho da fonte
                          style: TextStyle(fontSize: 12),
                        // Fechamento do Text
                        ),
                        // Ação ao clicar no atalho
                        onPressed: () {
                          // Navega para a rota de paciente
                          Navigator.pushNamed(context, '/paciente');
                        // Fechamento do onPressed
                        },
                      // Fechamento do OutlinedButton.icon
                      ),
                    // Fechamento do Material
                    ),
                  // Fechamento do Expanded
                  ),
                  // Espaçamento horizontal entre os botões de escala
                  SizedBox(width: 10),
                  // Segundo atalho de escala ocupando largura proporcional
                  Expanded(
                    // Contêiner Material com elevação
                    child: Material(
                      // Elevação de sombra sutil
                      elevation: 1,
                      // Fundo branco
                      color: Colors.white,
                      // Cantos arredondados
                      borderRadius: BorderRadius.circular(10),
                      // Botão com ícone para Escala de Motoristas
                      child: OutlinedButton.icon(
                        // Estilização do botão delineado
                        style: OutlinedButton.styleFrom(
                          // Cor do texto e ícone
                          foregroundColor: Colors.black87,
                          // Espaçamento vertical interno
                          padding: EdgeInsets.symmetric(vertical: 12),
                          // Borda cinza suave
                          side: BorderSide(color: Colors.grey.shade300),
                          // Formato com cantos arredondados
                          shape: RoundedRectangleBorder(
                            // Raio de 10 pixels
                            borderRadius: BorderRadius.circular(10),
                          // Fechamento do RoundedRectangleBorder
                          ),
                        // Fechamento do OutlinedButton.styleFrom
                        ),
                        // Ícone de calendário mensal
                        icon: Icon(Icons.calendar_month_outlined, size: 18),
                        // Rótulo textual do botão
                        label: Text(
                          // Texto abreviado
                          'Escala M.',
                          // Tamanho da fonte
                          style: TextStyle(fontSize: 12),
                        // Fechamento do Text
                        ),
                        // Ação ao clicar no atalho
                        onPressed: () {
                          // Navega para a rota de motorista
                          Navigator.pushNamed(context, '/motorista');
                        // Fechamento do onPressed
                        },
                      // Fechamento do OutlinedButton.icon
                      ),
                    // Fechamento do Material
                    ),
                  // Fechamento do Expanded
                  ),
                // Fechamento dos filhos da Row
                ],
              // Fechamento da Row
              ),
              // Espaçador vertical
              SizedBox(height: 8),
              // Terceira linha de botões de atalho: Frota de Veículos (Issue #33)
              Row(
                children: [
                  Expanded(
                    child: Material(
                      elevation: 1,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(Icons.airport_shuttle_outlined, size: 18),
                        label: Text(
                          'Frota de Veículos',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/veiculos');
                        },
                      ),
                    ),
                  ),
                ],
              ),
              // Espaçador vertical
              SizedBox(height: 20),

              // card do formulário feito com Material em vez de Container com BoxShadow
              // Card do formulário estático de cadastro de novos pacientes
              Material(
                // Elevação de sombra suave
                elevation: 1,
                // Cor de fundo branca
                color: Colors.white,
                // Cantos arredondados de 14 pixels
                borderRadius: BorderRadius.circular(14),
                // Espaçamento interno do formulário
                child: Padding(
                  // Recuo uniforme de 16 pixels
                  padding: EdgeInsets.all(16),
                  // Coluna com os campos do formulário
                  child: Column(
                    // Alinha os campos à esquerda
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Filhos do formulário
                    children: [
                      // Título da seção de cadastro
                      Text(
                        // Texto do título
                        'Novo Cadastro de Paciente',
                        // Estilo tipográfico do título da seção
                        style: TextStyle(
                          // Tamanho da fonte
                          fontSize: 14,
                          // Negrito
                          fontWeight: FontWeight.bold,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                      // Espaçador vertical
                      SizedBox(height: 14),

                      // campo 1
                      // Rótulo descritivo do campo Nome Completo
                      Text(
                        // Texto do rótulo
                        'NOME COMPLETO',
                        // Estilo tipográfico do rótulo
                        style: TextStyle(
                          // Tamanho reduzido
                          fontSize: 10,
                          // Negrito
                          fontWeight: FontWeight.bold,
                          // Cor cinza escura
                          color: Colors.black54,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                      // Espaçador vertical sutil
                      SizedBox(height: 5),
                      // Contêiner Material para o campo de texto
                      Material(
                        // Fundo branco
                        color: Colors.white,
                        // Cantos arredondados
                        borderRadius: BorderRadius.circular(8),
                        // Campo de texto para digitação do nome
                        child: TextField(
                          // Decoração do campo
                          decoration: InputDecoration(
                            // Dica de preenchimento
                            hintText: 'Ex: Maria das Dores Silva',
                            // Estilo da dica
                            hintStyle: TextStyle(
                              // Cor cinza suave
                              color: Colors.grey.shade400,
                              // Tamanho da fonte
                              fontSize: 13,
                            // Fechamento do TextStyle
                            ),
                            // Espaçamento interno do texto
                            contentPadding: EdgeInsets.symmetric(
                              // Recuo horizontal
                              horizontal: 12,
                              // Recuo vertical
                              vertical: 10,
                            // Fechamento do EdgeInsets
                            ),
                            // Borda padrão
                            border: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                            // Borda quando habilitado
                            enabledBorder: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                          // Fechamento do InputDecoration
                          ),
                        // Fechamento do TextField
                        ),
                      // Fechamento do Material
                      ),
                      // Espaçador vertical
                      SizedBox(height: 12),

                      // campo 2
                      // Rótulo descritivo do campo CPF
                      Text(
                        // Texto do rótulo
                        'CPF',
                        // Estilo tipográfico do rótulo
                        style: TextStyle(
                          // Tamanho reduzido
                          fontSize: 10,
                          // Negrito
                          fontWeight: FontWeight.bold,
                          // Cor cinza escura
                          color: Colors.black54,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                      // Espaçador vertical sutil
                      SizedBox(height: 5),
                      // Contêiner Material para o campo de CPF
                      Material(
                        // Fundo branco
                        color: Colors.white,
                        // Cantos arredondados
                        borderRadius: BorderRadius.circular(8),
                        // Campo de texto para inserção do CPF
                        child: TextField(
                          // Decoração do campo
                          decoration: InputDecoration(
                            // Dica com máscara de CPF
                            hintText: '000.000.000-00',
                            // Estilo da dica
                            hintStyle: TextStyle(
                              // Cor cinza suave
                              color: Colors.grey.shade400,
                              // Tamanho da fonte
                              fontSize: 13,
                            // Fechamento do TextStyle
                            ),
                            // Espaçamento interno
                            contentPadding: EdgeInsets.symmetric(
                              // Recuo horizontal
                              horizontal: 12,
                              // Recuo vertical
                              vertical: 10,
                            // Fechamento do EdgeInsets
                            ),
                            // Borda padrão
                            border: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                            // Borda quando habilitado
                            enabledBorder: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                          // Fechamento do InputDecoration
                          ),
                        // Fechamento do TextField
                        ),
                      // Fechamento do Material
                      ),
                      // Espaçador vertical
                      SizedBox(height: 12),

                      // campo 3
                      // Rótulo descritivo do campo Destino
                      Text(
                        // Texto do rótulo
                        'DESTINO (HOSPITAL/CLÍNICA)',
                        // Estilo tipográfico do rótulo
                        style: TextStyle(
                          // Tamanho reduzido
                          fontSize: 10,
                          // Negrito
                          fontWeight: FontWeight.bold,
                          // Cor cinza escura
                          color: Colors.black54,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                      // Espaçador vertical sutil
                      SizedBox(height: 5),
                      // Contêiner Material para o campo de destino
                      Material(
                        // Fundo branco
                        color: Colors.white,
                        // Cantos arredondados
                        borderRadius: BorderRadius.circular(8),
                        // Campo de texto para preenchimento do destino
                        child: TextField(
                          // Decoração do campo
                          decoration: InputDecoration(
                            // Dica de exemplo de hospital
                            hintText: 'Ex: Hospital Central - Ala Norte',
                            // Estilo da dica
                            hintStyle: TextStyle(
                              // Cor cinza suave
                              color: Colors.grey.shade400,
                              // Tamanho da fonte
                              fontSize: 13,
                            // Fechamento do TextStyle
                            ),
                            // Espaçamento interno
                            contentPadding: EdgeInsets.symmetric(
                              // Recuo horizontal
                              horizontal: 12,
                              // Recuo vertical
                              vertical: 10,
                            // Fechamento do EdgeInsets
                            ),
                            // Borda padrão
                            border: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                            // Borda quando habilitado
                            enabledBorder: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                          // Fechamento do InputDecoration
                          ),
                        // Fechamento do TextField
                        ),
                      // Fechamento do Material
                      ),
                      // Espaçador vertical
                      SizedBox(height: 12),

                      // campo 4
                      // Rótulo descritivo do campo Horário da Consulta
                      Text(
                        // Texto do rótulo
                        'HORÁRIO DA CONSULTA',
                        // Estilo tipográfico do rótulo
                        style: TextStyle(
                          // Tamanho reduzido
                          fontSize: 10,
                          // Negrito
                          fontWeight: FontWeight.bold,
                          // Cor cinza escura
                          color: Colors.black54,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                      // Espaçador vertical sutil
                      SizedBox(height: 5),
                      // Contêiner Material para o campo de horário
                      Material(
                        // Fundo branco
                        color: Colors.white,
                        // Cantos arredondados
                        borderRadius: BorderRadius.circular(8),
                        // Campo de texto para o horário da consulta
                        child: TextField(
                          // Decoração do campo
                          decoration: InputDecoration(
                            // Dica de exemplo de horário
                            hintText: 'Ex: 14:30',
                            // Estilo da dica
                            hintStyle: TextStyle(
                              // Cor cinza suave
                              color: Colors.grey.shade400,
                              // Tamanho da fonte
                              fontSize: 13,
                            // Fechamento do TextStyle
                            ),
                            // Espaçamento interno
                            contentPadding: EdgeInsets.symmetric(
                              // Recuo horizontal
                              horizontal: 12,
                              // Recuo vertical
                              vertical: 10,
                            // Fechamento do EdgeInsets
                            ),
                            // Borda padrão
                            border: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                            // Borda quando habilitado
                            enabledBorder: OutlineInputBorder(
                              // Raio de 8 pixels
                              borderRadius: BorderRadius.circular(8),
                              // Borda cinza suave
                              borderSide: BorderSide(
                                // Cor da borda
                                color: Colors.grey.shade300,
                              // Fechamento do BorderSide
                              ),
                            // Fechamento do OutlineInputBorder
                            ),
                          // Fechamento do InputDecoration
                          ),
                        // Fechamento do TextField
                        ),
                      // Fechamento do Material
                      ),
                    // Fechamento dos filhos do formulário
                    ],
                  // Fechamento da Column
                  ),
                // Fechamento do Padding
                ),
              // Fechamento do Material
              ),
              // Espaçador vertical
              SizedBox(height: 20),

              // lista de últimos escalados em Material
              // Título da seção de últimos pacientes escalados
              Text(
                // Texto do título
                'ÚLTIMOS PACIENTES ESCALADOS',
                // Estilo tipográfico do título
                style: TextStyle(
                  // Tamanho reduzido
                  fontSize: 11,
                  // Negrito
                  fontWeight: FontWeight.bold,
                  // Cor cinza escura
                  color: Colors.black54,
                // Fechamento do TextStyle
                ),
              // Fechamento do Text
              ),
              // Espaçador vertical sutil
              SizedBox(height: 8),

              // card do João Santos em Material
              // Card estático de exibição do paciente João Santos
              Material(
                // Elevação de sombra sutil
                elevation: 1,
                // Fundo branco
                color: Colors.white,
                // Cantos arredondados de 12 pixels
                borderRadius: BorderRadius.circular(12),
                // Espaçamento interno do card
                child: Padding(
                  // Recuo uniforme de 12 pixels
                  padding: EdgeInsets.all(12),
                  // Linha com avatar, textos e tag de status
                  child: Row(
                    // Filhos dispostos horizontalmente
                    children: [
                      // Avatar circular com iniciais do paciente
                      CircleAvatar(
                        // Raio de 18 pixels
                        radius: 18,
                        // Fundo cinza suave
                        backgroundColor: Colors.grey.shade200,
                        // Iniciais do nome
                        child: Text(
                          // Texto das iniciais
                          'JS',
                          // Estilo tipográfico
                          style: TextStyle(
                            // Tamanho de 12 pixels
                            fontSize: 12,
                            // Negrito
                            fontWeight: FontWeight.bold,
                            // Cor cinza escura
                            color: Colors.black54,
                          // Fechamento do TextStyle
                          ),
                        // Fechamento do Text
                        ),
                      // Fechamento do CircleAvatar
                      ),
                      // Espaçamento horizontal
                      SizedBox(width: 12),
                      // Coluna com nome e detalhes do agendamento
                      Column(
                        // Alinha os textos à esquerda
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // Filhos da coluna
                        children: [
                          // Nome do paciente
                          Text(
                            // Texto com nome
                            'João Santos',
                            // Estilo em negrito
                            style: TextStyle(
                              // Tamanho de fonte 13
                              fontSize: 13,
                              // Negrito
                              fontWeight: FontWeight.bold,
                            // Fechamento do TextStyle
                            ),
                          // Fechamento do Text
                          ),
                          // Espaçador vertical sutil
                          SizedBox(height: 2),
                          // Local e horário da consulta
                          Text(
                            // Informações do agendamento
                            'UPA Centro • 13:00',
                            // Estilo com cor cinza
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          // Fechamento do Text
                          ),
                        // Fechamento dos filhos da Column
                        ],
                      // Fechamento da Column
                      ),
                      // Espaçador elástico que empurra a tag para a direita
                      Spacer(),
                      // tag pendente com Material
                      // Tag de status com cantos arredondados
                      Material(
                        // Fundo cinza bem claro
                        color: Colors.grey.shade100,
                        // Cantos arredondados de 6 pixels
                        borderRadius: BorderRadius.circular(6),
                        // Espaçamento interno da tag
                        child: Padding(
                          // Recuo horizontal e vertical compacto
                          padding: EdgeInsets.symmetric(
                            // Recuo horizontal
                            horizontal: 8,
                            // Recuo vertical
                            vertical: 4,
                          // Fechamento do EdgeInsets
                          ),
                          // Texto do status
                          child: Text(
                            // Rótulo pendente
                            'PENDENTE',
                            // Estilo tipográfico compacto
                            style: TextStyle(
                              // Tamanho de 9 pixels
                              fontSize: 9,
                              // Negrito
                              fontWeight: FontWeight.bold,
                              // Cor cinza
                              color: Colors.grey,
                            // Fechamento do TextStyle
                            ),
                          // Fechamento do Text
                          ),
                        // Fechamento do Padding
                        ),
                      // Fechamento do Material
                      ),
                    // Fechamento dos filhos da Row
                    ],
                  // Fechamento da Row
                  ),
                // Fechamento do Padding
                ),
              // Fechamento do Material
              ),
              // Espaçador vertical
              SizedBox(height: 25),

              // botão salvar paciente
              // Botão centralizado para salvar o paciente
              Center(
                // Botão elevado com ícone
                child: ElevatedButton.icon(
                  // Estilização do botão elevado
                  style: ElevatedButton.styleFrom(
                    // Cor escura azulada de fundo
                    backgroundColor: Color(0xFF0F172A),
                    // Cor branca do texto e ícone
                    foregroundColor: Colors.white,
                    // Espaçamento interno confortável
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    // Cantos arredondados
                    shape: RoundedRectangleBorder(
                      // Raio de 10 pixels
                      borderRadius: BorderRadius.circular(10),
                    // Fechamento do RoundedRectangleBorder
                    ),
                    // Elevação de 2 pixels
                    elevation: 2,
                  // Fechamento do ElevatedButton.styleFrom
                  ),
                  // Ícone de adição
                  icon: Icon(Icons.add, size: 18),
                  // Rótulo textual do botão
                  label: Text(
                    // Texto do botão
                    'Salvar Paciente',
                    // Estilização tipográfica
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  // Fechamento do Text
                  ),
                  // Callback disparado ao clicar no botão
                  onPressed: () {
                    // showDialog em vez de snackbar pq tiramos o Scaffold
                    // Abre diálogo modal de confirmação estático
                    showDialog(
                      // Contexto da tela
                      context: context,
                      // Construtor do AlertDialog
                      builder: (ctx) => AlertDialog(
                        // Título do diálogo
                        title: Text('Confirmação'),
                        // Conteúdo com mensagem de confirmação puramente visual
                        content: Text(
                          // Mensagem de feedback
                          'Paciente salvo com sucesso (só no visual)!',
                        // Fechamento do Text
                        ),
                        // Ações de fechamento do diálogo
                        actions: [
                          // Botão textual para fechar
                          TextButton(
                            // Rótulo OK
                            child: Text('OK'),
                            // Fecha o diálogo modal
                            onPressed: () => Navigator.pop(ctx),
                          // Fechamento do TextButton
                          ),
                        // Fechamento da lista actions
                        ],
                      // Fechamento do AlertDialog
                      ),
                    // Fechamento do showDialog
                    );
                  // Fechamento do onPressed
                  },
                // Fechamento do ElevatedButton.icon
                ),
              // Fechamento do Center
              ),
              // Espaçador vertical inferior
              SizedBox(height: 25),
            // Fechamento dos filhos da Column
            ],
          // Fechamento da Column
          ),
        // Fechamento do SingleChildScrollView
        ),
      // Fechamento do SafeArea
      ),
    // Fechamento do Material
    );
  // Fechamento do método build
  }
// Fechamento da classe Administrativo
}
