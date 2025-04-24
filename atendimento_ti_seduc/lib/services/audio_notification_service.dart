// lib/services/audio_notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioNotificationService {
  // Instância estática para fácil acesso (padrão Singleton simples)
  // static final AudioNotificationService _instance = AudioNotificationService._internal();
  // factory AudioNotificationService() => _instance;
  // AudioNotificationService._internal();
  // Alternativa: Usar métodos estáticos diretamente, mais simples para este caso.

  static AudioPlayer? _audioPlayer;
  static StreamSubscription? _chamadosSubscription;
  static bool _isFirstLoadComplete = false;

  // Método estático para INICIAR o serviço/listener
  static void startListening() {
    // Evita iniciar múltiplos listeners se chamado acidentalmente mais de uma vez
    if (_chamadosSubscription != null) {
      print("Listener de áudio já iniciado.");
      return;
    }

    print("Iniciando AudioNotificationService listener...");
    _audioPlayer = AudioPlayer(); // Cria instância do player
    _isFirstLoadComplete = false; // Reseta flag ao iniciar

    final query = FirebaseFirestore.instance
        .collection('chamados')
        .orderBy('data_criacao', descending: true);

    _chamadosSubscription = query.snapshots().listen(
      (QuerySnapshot snapshot) {
        print("AudioService: Snapshot recebido. Changes: ${snapshot.docChanges.length}");

        if (!_isFirstLoadComplete) {
          print("AudioService: Primeiro carregamento, ignorando.");
          _isFirstLoadComplete = true;
          return;
        }

        bool newTicketFound = false;
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            // TODO: Considerar adicionar lógica de timestamp aqui também, se necessário
            // para ignorar chamados adicionados "muito no passado" durante sincronizações.
            print("AudioService: Novo chamado detectado (${change.doc.id})!");
            newTicketFound = true;
            break;
          }
        }

        if (newTicketFound) {
          _playSound();
        }
      },
      onError: (error) {
        print("AudioService: Erro no listener de chamados: $error");
        // Considerar logar erro ou reportar de alguma forma
      },
      onDone: () {
        print("AudioService: Listener de chamados finalizado.");
        // Opcional: tentar reiniciar o listener? Ou apenas logar.
      }
    );
     print("AudioNotificationService iniciado e ouvindo.");
  }

  // Método estático para PARAR o serviço/listener (chamar se necessário, ex: logout)
  static void stopListening() {
    print("Parando AudioNotificationService listener...");
    _chamadosSubscription?.cancel();
    _chamadosSubscription = null; // Limpa a referência
    _audioPlayer?.dispose();      // Libera recursos do player
    _audioPlayer = null;         // Limpa a referência
    _isFirstLoadComplete = false; // Reseta para a próxima vez que iniciar
    print("AudioNotificationService parado.");
  }

  // Método privado e estático para tocar o som
  static Future<void> _playSound() async {
    if (_audioPlayer == null) return; // Segurança extra
    print("AudioService: Tocando som...");
    try {
      // <<< Use o nome exato do seu arquivo de som >>>
      await _audioPlayer!.play(AssetSource('sounds/notification.ogg'));
      print("AudioService: Som tocado.");
    } catch (e) {
      print("AudioService: Erro ao tocar som: $e");
    }
  }
}