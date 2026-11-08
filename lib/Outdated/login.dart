// ============================================================================
// ARQUIVO: lib/Outdated/login.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa um protótipo visual inicial da tela de login (StatefulWidget "Login").
// Contém campos de texto para nome/usuário e senha, um menu dropdown de debug
// para seleção rápida de perfil (Administrador, Motorista, Paciente), e botões
// de ação para autenticação simulada e redirecionamento para a tela de registro.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Código Legado / Obsoleto arquivado (pasta lib/Outdated/). Substituído na
// evolução do projeto pela tela de autenticação oficial conectada ao Firebase
// Auth e AuthService (lib/screens/login_screen.dart e lib/screens/auth_gate.dart).
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - Não é mais importado no fluxo de autenticação oficial nem em lib/main.dart.
//
// DE ONDE RECEBE DADOS:
// - Dados puramente estáticos mantidos em memória pelo estado da tela (_LoginState),
//   sem integração com serviços de rede ou autenticação real.
//
// O QUE EXPORTA / EXPÕE:
// - class Login extends StatefulWidget: Widget de login legado.
// - class _LoginState: Estado interno associado ao protótipo de login.
//
// ORIGEM HISTÓRICA:
// Criado no início do projeto nos commits prototípicos da equipe (commit 22b8657)
// e arquivado para a pasta Outdated no commit 588756d.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart: componentes de UI.
// - Efeitos colaterais: apenas navegação por rotas nomeadas ('/administrativo',
//   '/motorista', '/paciente', '/register').
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - Construído sem Scaffold e sem gerenciamento de dispose dos TextEditingControllers.
// - Autenticação baseada em condicional puramente visual sobre a variável cargoDebug.
// ============================================================================
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';

// tela de login sem Scaffold pq o professor mandou usar Material em tudo
// Declaração do StatefulWidget representando o protótipo de login legado
class Login extends StatefulWidget {
  // Construtor do widget Login com chave opcional
  Login({super.key});

  // Sobrescrita que instancia o estado do StatefulWidget
  @override
  // Cria o estado mutável _LoginState
  State<Login> createState() => _LoginState();
// Fechamento da classe Login
}

// Classe de estado privada associada ao protótipo de login
class _LoginState extends State<Login> {
  // dropdown feio no canto só pro professor testar os cargos e não encher meu saco
  // Variável para armazenar o perfil selecionado no dropdown de testes
  String cargoDebug = 'Administrador';

  // controladores que nem vou dar dispose pq esqueci como faz
  // Controlador de texto do campo de usuário
  final TextEditingController userController = TextEditingController();
  // Controlador de texto do campo de senha
  final TextEditingController passController = TextEditingController();

  // Sobrescrita do método de construção da árvore de widgets
  @override
  // Constrói a interface gráfica do protótipo
  Widget build(BuildContext context) {
    // trocado Scaffold por Material raiz com SafeArea
    // Container Material utilizado como elemento raiz da tela
    return Material(
      // Cor de fundo cinza claro
      color: Color(0xFFF7F8FA),
      // Envolve em SafeArea para proteger contra áreas de corte da tela
      child: SafeArea(
        // Habilita rolagem vertical do conteúdo
        child: SingleChildScrollView(
          // Espaçamento horizontal nas bordas da tela
          padding: EdgeInsets.symmetric(horizontal: 28.0),
          // Coluna principal esticada horizontalmente
          child: Column(
            // Estica os filhos na largura total
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Lista de componentes do formulário de login
            children: [
              // Espaçador vertical
              SizedBox(height: 10),
              // linha do topo pro dropdown de debug já que tirei o Scaffold e o AppBar
              // Alinha o seletor de debug no canto superior direito
              Align(
                // Alinhamento ao topo direito
                alignment: Alignment.topRight,
                // Contêiner Material para envolver o dropdown
                child: Material(
                  // Fundo branco
                  color: Colors.white,
                  // Elevação sutil
                  elevation: 1,
                  // Cantos arredondados
                  borderRadius: BorderRadius.circular(8),
                  // Espaçamento interno do dropdown
                  child: Padding(
                    // Recuo horizontal e vertical compacto
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    // Linha com o rótulo e o DropdownButton
                    child: Row(
                      // Ocupa o tamanho mínimo horizontal
                      mainAxisSize: MainAxisSize.min,
                      // Filhos da linha do seletor de perfil
                      children: [
                        // Rótulo indicativo
                        Text(
                          // Texto do rótulo
                          'Cargo: ',
                          // Estilo tipográfico cinza
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        // Fechamento do Text
                        ),
                        // Menu suspenso para alternar entre perfis de teste
                        DropdownButton<String>(
                          // Valor selecionado atualmente
                          value: cargoDebug,
                          // Layout compacto
                          isDense: true,
                          // Oculta a linha sublinhada padrão do dropdown
                          underline:
                              SizedBox(), // gambiarra pra sumir com a linha
                          // Estilo tipográfico dos itens
                          style: TextStyle(
                            // Tamanho de 12 pixels
                            fontSize: 12,
                            // Cor escura
                            color: Colors.black87,
                            // Negrito
                            fontWeight: FontWeight.bold,
                          // Fechamento do TextStyle
                          ),
                          // Lista de itens do menu dropdown
                          items: [
                            // Opção Administrador
                            DropdownMenuItem(
                              // Valor interno correspondente
                              value: 'Administrador',
                              // Texto exibido na opção
                              child: Text('Admin'),
                            // Fechamento do DropdownMenuItem
                            ),
                            // Opção Motorista
                            DropdownMenuItem(
                              // Valor interno correspondente
                              value: 'Motorista',
                              // Texto exibido na opção
                              child: Text('Motorista'),
                            // Fechamento do DropdownMenuItem
                            ),
                            // Opção Paciente
                            DropdownMenuItem(
                              // Valor interno correspondente
                              value: 'Paciente',
                              // Texto exibido na opção
                              child: Text('Paciente'),
                            // Fechamento do DropdownMenuItem
                            ),
                          // Fechamento da lista items
                          ],
                          // Callback disparado ao selecionar um item
                          onChanged: (novo) {
                            // Atualiza o estado da tela com o novo perfil
                            setState(() {
                              // Atribui o novo valor
                              cargoDebug = novo!;
                            // Fechamento do setState
                            });
                          // Fechamento do onChanged
                          },
                        // Fechamento do DropdownButton
                        ),
                      // Fechamento dos filhos da Row
                      ],
                    // Fechamento da Row
                    ),
                  // Fechamento do Padding
                  ),
                // Fechamento do Material
                ),
              // Fechamento do Align
              ),
              // Espaçador vertical
              SizedBox(height: 20),
              // ícone genérico pq não tenho logo ainda
              // Centraliza o avatar de ícone de ônibus
              Center(
                // Avatar circular com fundo escuro
                child: CircleAvatar(
                  // Raio de 35 pixels
                  radius: 35,
                  // Cor escura azulada
                  backgroundColor: Color(0xFF0F172A),
                  // Ícone de ônibus em branco
                  child: Icon(
                    // Ícone de transporte
                    Icons.directions_bus,
                    // Tamanho destacado de 36 pixels
                    size: 36,
                    // Cor branca
                    color: Colors.white,
                  // Fechamento do Icon
                  ),
                // Fechamento do CircleAvatar
                ),
              // Fechamento do Center
              ),
              // Espaçador vertical
              SizedBox(height: 20),
              // Título da página de login
              Text(
                // Texto de boas-vindas
                'Acesse sua Conta',
                // Alinhamento centralizado
                textAlign: TextAlign.center,
                // Estilo tipográfico em negrito
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              // Fechamento do Text
              ),
              // Espaçador vertical sutil
              SizedBox(height: 6),
              // Subtítulo instrucional
              Text(
                // Instrução ao usuário
                'Digite seus dados para entrar',
                // Alinhamento centralizado
                textAlign: TextAlign.center,
                // Estilo suave cinza
                style: TextStyle(color: Colors.grey, fontSize: 13),
              // Fechamento do Text
              ),
              // Espaçador vertical
              SizedBox(height: 35),

              // campo nome
              // Rótulo do campo de usuário
              Text(
                // Texto do rótulo
                'NOME OU USUÁRIO',
                // Estilo tipográfico do rótulo
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
              SizedBox(height: 6),
              // Contêiner Material para o campo de texto
              Material(
                // Elevação de sombra sutil
                elevation: 1,
                // Cantos arredondados de 10 pixels
                borderRadius: BorderRadius.circular(10),
                // Fundo branco
                color: Colors.white,
                // Campo de entrada de texto para o usuário
                child: TextField(
                  // Controlador associado
                  controller: userController,
                  // Decoração do campo
                  decoration: InputDecoration(
                    // Dica de exemplo
                    hintText: 'Ex: Carlos Silva',
                    // Estilo da dica
                    hintStyle: TextStyle(
                      // Cor cinza suave
                      color: Colors.grey.shade400,
                      // Tamanho de fonte 14
                      fontSize: 14,
                    // Fechamento do TextStyle
                    ),
                    // Espaçamento interno
                    contentPadding: EdgeInsets.symmetric(
                      // Recuo horizontal
                      horizontal: 14,
                      // Recuo vertical
                      vertical: 12,
                    // Fechamento do EdgeInsets
                    ),
                    // Borda padrão
                    border: OutlineInputBorder(
                      // Raio de 10 pixels
                      borderRadius: BorderRadius.circular(10),
                      // Borda cinza suave
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    // Fechamento do OutlineInputBorder
                    ),
                    // Borda quando habilitado
                    enabledBorder: OutlineInputBorder(
                      // Raio de 10 pixels
                      borderRadius: BorderRadius.circular(10),
                      // Borda cinza suave
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    // Fechamento do OutlineInputBorder
                    ),
                  // Fechamento do InputDecoration
                  ),
                // Fechamento do TextField
                ),
              // Fechamento do Material
              ),
              // Espaçador vertical
              SizedBox(height: 16),

              // campo senha
              // Rótulo do campo de senha
              Text(
                // Texto do rótulo
                'SENHA',
                // Estilo tipográfico do rótulo
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
              SizedBox(height: 6),
              // Contêiner Material para o campo de senha
              Material(
                // Elevação de sombra sutil
                elevation: 1,
                // Cantos arredondados de 10 pixels
                borderRadius: BorderRadius.circular(10),
                // Fundo branco
                color: Colors.white,
                // Campo de entrada de texto com caracteres ocultos
                child: TextField(
                  // Controlador associado
                  controller: passController,
                  // Oculta os caracteres digitados por segurança
                  obscureText: true,
                  // Decoração do campo
                  decoration: InputDecoration(
                    // Dica de máscara de senha
                    hintText: '••••••••',
                    // Estilo da dica
                    hintStyle: TextStyle(
                      // Cor cinza suave
                      color: Colors.grey.shade400,
                      // Tamanho de fonte 14
                      fontSize: 14,
                    // Fechamento do TextStyle
                    ),
                    // Espaçamento interno
                    contentPadding: EdgeInsets.symmetric(
                      // Recuo horizontal
                      horizontal: 14,
                      // Recuo vertical
                      vertical: 12,
                    // Fechamento do EdgeInsets
                    ),
                    // Borda padrão
                    border: OutlineInputBorder(
                      // Raio de 10 pixels
                      borderRadius: BorderRadius.circular(10),
                      // Borda cinza suave
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    // Fechamento do OutlineInputBorder
                    ),
                    // Borda quando habilitado
                    enabledBorder: OutlineInputBorder(
                      // Raio de 10 pixels
                      borderRadius: BorderRadius.circular(10),
                      // Borda cinza suave
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    // Fechamento do OutlineInputBorder
                    ),
                  // Fechamento do InputDecoration
                  ),
                // Fechamento do TextField
                ),
              // Fechamento do Material
              ),
              // Espaçador vertical
              SizedBox(height: 28),

              // botão entrar com if de principiante
              // Botão elevado para autenticação e navegação por cargo
              ElevatedButton(
                // Estilização do botão elevado
                style: ElevatedButton.styleFrom(
                  // Fundo escuro azulado
                  backgroundColor: Color(0xFF0F172A),
                  // Texto em branco
                  foregroundColor: Colors.white,
                  // Espaçamento vertical interno
                  padding: EdgeInsets.symmetric(vertical: 14),
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
                // Callback de ação ao pressionar o botão Entrar
                onPressed: () {
                  // Redireciona conforme o cargo selecionado no dropdown de testes
                  if (cargoDebug == 'Administrador') {
                    // Navega para a tela administrativa
                    Navigator.pushNamed(context, '/administrativo');
                  // Se for motorista
                  } else if (cargoDebug == 'Motorista') {
                    // Navega para a tela de motorista
                    Navigator.pushNamed(context, '/motorista');
                  // Se for paciente
                  } else {
                    // Navega para a tela do paciente
                    Navigator.pushNamed(context, '/paciente');
                  // Fechamento da condicional
                  }
                // Fechamento do onPressed
                },
                // Texto do botão Entrar
                child: Text(
                  // Rótulo
                  'Entrar',
                  // Estilo em negrito
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                // Fechamento do Text
                ),
              // Fechamento do ElevatedButton
              ),
              // Espaçador vertical
              SizedBox(height: 12),

              // botão registrar-se que joga pra tela de cadastro
              // Botão delineado para transição à tela de registro
              OutlinedButton(
                // Estilização do botão delineado
                style: OutlinedButton.styleFrom(
                  // Espaçamento vertical interno
                  padding: EdgeInsets.symmetric(vertical: 14),
                  // Cantos arredondados
                  shape: RoundedRectangleBorder(
                    // Raio de 10 pixels
                    borderRadius: BorderRadius.circular(10),
                  // Fechamento do RoundedRectangleBorder
                  ),
                  // Borda cinza suave
                  side: BorderSide(color: Colors.grey.shade300),
                // Fechamento do OutlinedButton.styleFrom
                ),
                // Ação executada ao tocar no botão Registrar-se
                onPressed: () {
                  // Navega para a tela de registro de nova conta
                  Navigator.pushNamed(context, '/register');
                // Fechamento do onPressed
                },
                // Texto do botão Registrar-se
                child: Text(
                  // Rótulo
                  'Registrar-se',
                  // Estilo escuro suave
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                // Fechamento do Text
                ),
              // Fechamento do OutlinedButton
              ),
              // Espaçador vertical inferior
              SizedBox(height: 20),
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
// Fechamento da classe _LoginState
}
