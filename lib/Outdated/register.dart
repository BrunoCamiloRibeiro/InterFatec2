// ============================================================================
// ARQUIVO: lib/Outdated/register.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa um protótipo visual legado da tela de cadastro de usuários
// (StatefulWidget "Register"). Apresenta campos de texto para nome/usuário, senha
// e confirmação de senha, com botões para cadastrar ou retornar à tela de login,
// renderizados sobre widgets Material puros.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Código Legado / Obsoleto arquivado (pasta lib/Outdated/). Substituído na
// evolução do projeto pelo fluxo de gerenciamento administrativo de pessoas
// e autenticação oficial.
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - lib/Outdated/login.dart: navegado via Navigator.pushNamed('/register').
//
// DE ONDE RECEBE DADOS:
// - Dados puramente estáticos mantidos em memória via controladores de texto
//   (TextEditingController), sem persistência remota.
//
// O QUE EXPORTA / EXPÕE:
// - class Register extends StatefulWidget: Widget de cadastro legado.
// - class _RegisterState: Estado interno associado ao formulário de registro.
//
// ORIGEM HISTÓRICA:
// Criado no início do projeto nos commits prototípicos da equipe (commit 22b8657)
// e arquivado para a pasta Outdated no commit 588756d.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart: componentes de UI.
// - Efeitos colaterais: navegação pop de tela.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - Construído sem Scaffold e sem gerenciamento de dispose dos controladores.
// - Ação de cadastrar apenas fecha a tela via Navigator.pop(context) sem persistência.
// ============================================================================
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';

// tela de registro com Material e sem Scaffold pra agradar o professor
// Declaração do StatefulWidget representando o protótipo legado de cadastro
class Register extends StatefulWidget {
  // Construtor do widget com chave opcional
  Register({super.key});

  // Sobrescrita que cria o estado mutável do widget
  @override
  // Instancia e retorna a classe de estado privada _RegisterState
  State<Register> createState() => _RegisterState();
// Fechamento da classe Register
}

// Classe de estado privada associada ao protótipo de registro
class _RegisterState extends State<Register> {
  // Controlador de texto para o campo de nome ou usuário
  final TextEditingController userController = TextEditingController();
  // Controlador de texto para o campo de senha
  final TextEditingController passController = TextEditingController();
  // Controlador de texto para o campo de confirmação de senha
  final TextEditingController confirmPassController = TextEditingController();

  // Sobrescrita do método de construção da árvore de widgets
  @override
  // Constrói a interface gráfica do protótipo de cadastro
  Widget build(BuildContext context) {
    // Scaffold banido, só Material agora
    // Utiliza Material como elemento raiz da tela
    return Material(
      // Fundo cinza suave
      color: Color(0xFFF7F8FA),
      // Envolve em SafeArea para proteger contra áreas de corte da tela
      child: SafeArea(
        // Habilita rolagem vertical do conteúdo
        child: SingleChildScrollView(
          // Espaçamento horizontal nas laterais da tela
          padding: EdgeInsets.symmetric(horizontal: 28.0),
          // Coluna que organiza os campos verticalmente
          child: Column(
            // Estica os filhos na largura total
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Lista de elementos do formulário de registro
            children: [
              // Espaçador vertical
              SizedBox(height: 10),
              // botão voltar feito na mão pq não tem AppBar
              // Alinha o botão de voltar à esquerda
              Align(
                // Alinhamento à esquerda
                alignment: Alignment.centerLeft,
                // Botão de retorno
                child: IconButton(
                  // Ícone de seta preta para a esquerda
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  // Ação ao clicar no botão voltar
                  onPressed: () {
                    // Desempilha a tela atual e retorna
                    Navigator.pop(context);
                  // Fechamento do onPressed
                  },
                // Fechamento do IconButton
                ),
              // Fechamento do Align
              ),
              // Espaçador vertical
              SizedBox(height: 10),
              // Centraliza o avatar de ícone de adicionar pessoa
              Center(
                // Avatar circular com fundo escuro
                child: CircleAvatar(
                  // Raio de 35 pixels
                  radius: 35,
                  // Cor escura azulada
                  backgroundColor: Color(0xFF0F172A),
                  // Ícone de pessoa com sinal de mais em branco
                  child: Icon(Icons.person_add, size: 36, color: Colors.white),
                // Fechamento do CircleAvatar
                ),
              // Fechamento do Center
              ),
              // Espaçador vertical
              SizedBox(height: 20),
              // Título da página de registro
              Text(
                // Texto do título
                'Criar Nova Conta',
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
                // Texto descritivo
                'Preencha os campos para se registrar',
                // Alinhamento centralizado
                textAlign: TextAlign.center,
                // Estilo em cor cinza suave
                style: TextStyle(color: Colors.grey, fontSize: 13),
              // Fechamento do Text
              ),
              // Espaçador vertical
              SizedBox(height: 30),

              // campo nome
              // Rótulo do campo de nome ou usuário
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
                // Campo de entrada de texto para o nome ou usuário
                child: TextField(
                  // Controlador associado
                  controller: userController,
                  // Decoração do campo
                  decoration: InputDecoration(
                    // Dica de exemplo de nome
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
              SizedBox(height: 16),

              // confirmar senha
              // Rótulo do campo de confirmação de senha
              Text(
                // Texto do rótulo
                'CONFIRMAR SENHA',
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
              // Contêiner Material para o campo de confirmação de senha
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
                  controller: confirmPassController,
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

              // botão cadastrar
              // Botão elevado para submeter o cadastro simulado
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
                // Ação ao clicar no botão de cadastro
                onPressed: () {
                  // Desempilha a tela e retorna
                  Navigator.pop(context);
                // Fechamento do onPressed
                },
                // Texto do botão Cadastrar
                child: Text(
                  // Rótulo
                  'Cadastrar',
                  // Estilo em negrito
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                // Fechamento do Text
                ),
              // Fechamento do ElevatedButton
              ),
              // Espaçador vertical
              SizedBox(height: 12),

              // aqui o registrar-se virou entrar
              // Botão delineado para retornar à tela de login
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
                // Ação ao pressionar o botão Entrar
                onPressed: () {
                  // Desempilha a tela atual e retorna ao login
                  Navigator.pop(context);
                // Fechamento do onPressed
                },
                // Texto do botão Entrar
                child: Text(
                  // Rótulo
                  'Entrar',
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
// Fechamento da classe _RegisterState
}
