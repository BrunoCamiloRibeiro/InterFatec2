// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/firebase_options.dart
// Camada: Infraestrutura e Configuração Raiz (Scaffold FlutterFire CLI)
//
// O QUE ESTE ARQUIVO FAZ:
// Fornece a classe de configuração DefaultFirebaseOptions com as credenciais e
// identificadores do projeto Google Firebase (projeto 'trans-saude2') específicos
// para cada plataforma suportada (Web, Android e Windows), resolvidos
// dinamicamente pelo getter estático currentPlatform.
//
// PARA QUE SERVE NO PROJETO:
// Permite que o método Firebase.initializeApp em lib/main.dart configure
// corretamente a chave de API, project ID, bucket de armazenamento e app ID
// correspondentes à plataforma em que o aplicativo está sendo executado.
//
// ONDE É USADO NO PROJETO:
// - lib/main.dart (na inicialização do Firebase Core: Firebase.initializeApp)
//
// DE ONDE RECEBE DADOS:
// Parâmetros gerados pelo console do Firebase e pela CLI FlutterFire.
//
// O QUE EXPORTA / EXPÕE:
// - class DefaultFirebaseOptions:
//   * static FirebaseOptions get currentPlatform
//   * static const FirebaseOptions web
//   * static const FirebaseOptions android
//   * static const FirebaseOptions windows
//
// ORIGEM HISTÓRICA:
// Código de scaffold gerado automaticamente pelo FlutterFire CLI (flutterfire configure)
// no commit inicial 59a63c4 e mantido inalterado pela equipe.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:firebase_core/firebase_core.dart' e 'package:flutter/foundation.dart'.
// Classe estática imutável: sem efeitos colaterais, sem mutabilidade e sem chamadas de rede.
// ============================================================================

// Importa a classe FirebaseOptions do pacote firebase_core
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
// Importa utilitários de identificação de plataforma do framework Flutter
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Linha em branco separadora entre imports e a classe DefaultFirebaseOptions
// Declaração da classe estática de opções do Firebase
class DefaultFirebaseOptions {
  // Getter estático que devolve as opções adequadas para a plataforma atual
  static FirebaseOptions get currentPlatform {
    // Se a aplicação estiver sendo executada em ambiente Web, retorna a configuração web
    if (kIsWeb) {
      return web;
    }
    // Avalia a plataforma nativa do dispositivo através de switch
    switch (defaultTargetPlatform) {
      // Caso seja o sistema operacional Android
      case TargetPlatform.android:
        return android;
      // Caso seja o sistema operacional Windows Desktop
      case TargetPlatform.windows:
        return windows;
      // Caso padrão para outras plataformas não mapeadas
      default:
        return web;
    }
  }

  // Linha em branco separadora entre currentPlatform e constantes de plataforma

  // Configurações do projeto Firebase para a plataforma Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBZD3GsIY68mllCD0_y63T14UXnNnG_dl8',
    authDomain: 'trans-saude2.firebaseapp.com',
    projectId: 'trans-saude2',
    storageBucket: 'trans-saude2.firebasestorage.app',
    messagingSenderId: '1010712989031',
    appId: '1:1010712989031:web:6bdcd79a001d67953db3c2',
  );

  // Linha em branco separadora entre constantes de plataforma

  // Configurações do projeto Firebase para a plataforma Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBZD3GsIY68mllCD0_y63T14UXnNnG_dl8',
    projectId: 'trans-saude2',
    storageBucket: 'trans-saude2.firebasestorage.app',
    appId: '1:1010712989031:web:6bdcd79a001d67953db3c2',
    messagingSenderId: '1010712989031',
  );

  // Linha em branco separadora entre constantes de plataforma

  // Configurações do projeto Firebase para a plataforma Windows
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBZD3GsIY68mllCD0_y63T14UXnNnG_dl8',
    authDomain: 'trans-saude2.firebaseapp.com',
    projectId: 'trans-saude2',
    storageBucket: 'trans-saude2.firebasestorage.app',
    appId: '1:1010712989031:web:6bdcd79a001d67953db3c2',
    messagingSenderId: '1010712989031',
  );
}
