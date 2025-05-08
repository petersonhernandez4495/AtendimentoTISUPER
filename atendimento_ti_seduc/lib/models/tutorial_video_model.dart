// No seu arquivo tutorial_video_model.dart
String extractYouTubeIdFromString(String urlOrId) {
  urlOrId = urlOrId.trim(); // Remove espaços em branco

  // Verifica se já é um ID de 11 caracteres
  if (RegExp(r"^[a-zA-Z0-9_-]{11}$").hasMatch(urlOrId)) {
    return urlOrId;
  }

  // Tenta extrair de URLs comuns do YouTube
  try {
    Uri uri = Uri.parse(urlOrId);

    // Ex: youtube.com/watch?v=VIDEO_ID
    if ((uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) &&
        uri.queryParameters.containsKey('v')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && RegExp(r"^[a-zA-Z0-9_-]{11}$").hasMatch(videoId)) {
        return videoId;
      }
    }

    // Ex: youtu.be/VIDEO_ID
    if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      final videoId = uri.pathSegments.first;
      if (RegExp(r"^[a-zA-Z0-9_-]{11}$").hasMatch(videoId)) {
        return videoId;
      }
    }

    // Ex: youtube.com/embed/VIDEO_ID
    if (uri.host.contains('youtube.com') &&
        uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
      if (uri.pathSegments.length > 1) {
        final videoId = uri.pathSegments[1];
        if (RegExp(r"^[a-zA-Z0-9_-]{11}$").hasMatch(videoId)) {
          return videoId;
        }
      }
    }
  } catch (e) {
    // print("Erro ao analisar URL '$urlOrId' para extrair ID: $e. Tentando como ID direto se possível.");
    // Se o parse falhar, mas a string original ainda for um ID válido, retorne-a.
    if (RegExp(r"^[a-zA-Z0-9_-]{11}$").hasMatch(urlOrId)) {
      return urlOrId;
    }
  }
  print("AVISO (extractYouTubeIdFromString): Não foi possível extrair um ID de YouTube válido de: '$urlOrId'. Verifique o formato.");
  return ''; // Retorna vazio se não conseguir extrair um ID válido
}


class TutorialVideo {
  final String title;
  final String youtubeVideoId;
  final String description;
  final String categoria;

  TutorialVideo({
    required this.title,
    required this.youtubeVideoId,
    required this.description,
    required this.categoria,
  });

  factory TutorialVideo.fromMap(Map<String, dynamic> map) {
    String categoriaRaw = map['categoria']?.toString() ?? 'Outros';
    String youtubeVideoIdRaw = map['youtubeVideoId']?.toString() ?? '';

    return TutorialVideo(
      title: map['title']?.toString() ?? 'Título Indisponível',
      // Chama a função de extração aqui
      youtubeVideoId: extractYouTubeIdFromString(youtubeVideoIdRaw), 
      description: map['description']?.toString() ?? '',
      // Lógica de trim para categoria
      categoria: categoriaRaw.trim().isEmpty ? 'Outros' : categoriaRaw.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'youtubeVideoId': youtubeVideoId, // Armazena o ID limpo
      'description': description,
      'categoria': categoria,
    };
  }
}