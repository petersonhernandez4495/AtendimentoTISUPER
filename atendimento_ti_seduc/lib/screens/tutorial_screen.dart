// lib/screens/tutorial_screen.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tutorial_video_model.dart'; // Ajuste o caminho se necessário
import '../config/theme/app_theme.dart'; // Importa seu tema

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  YoutubePlayerController? _controller;
  String? _currentlyPlayingVideoId;
  List<TutorialVideo> _videoList = [];

  // Função para buscar vídeos do Firestore
  Future<List<TutorialVideo>> _fetchTutorialVideos() async {
    // Use try-catch para lidar com possíveis erros do Firestore
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tutoriais') // Considere usar uma constante para 'tutoriais'
          // .orderBy('order') // Descomente se tiver um campo de ordenação
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return TutorialVideo(
          title: data['title'] ?? 'Título Indisponível',
          // Validação do ID do YouTube (simples)
          youtubeVideoId: YoutubePlayer.convertUrlToId(data['youtubeVideoId'] ?? '') ?? '',
          description: data['description'] ?? '',
        );
      // Garante que apenas vídeos com ID válido sejam incluídos
      }).where((video) => video.youtubeVideoId.isNotEmpty).toList();
    } catch (e) {
      // Em caso de erro, retorna uma lista vazia ou lança o erro
      // para ser tratado pelo FutureBuilder
      print("Erro ao buscar tutoriais do Firestore: $e");
      // Retorna lista vazia ou lança exceção dependendo de como quer tratar
      return [];
      // ou throw Exception('Falha ao carregar vídeos: $e');
    }
  }

  void _playVideo(String videoId) {
    // Não recria o controller se o mesmo vídeo já estiver selecionado
    if (_currentlyPlayingVideoId == videoId && _controller != null) {
      // Talvez apenas garantir que esteja tocando?
      // _controller?.play();
      return;
    }

    // Libera o controller antigo antes de criar um novo
    _controller?.dispose();

    try {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true, // Inicia automaticamente
          mute: false,
          // useHybridComposition: false, // Defina como false para Android se tiver problemas de performance/UI piscando
          // enableCaption: true, // Habilita legendas se disponíveis
          // forceHD: false, // Força HD (pode consumir mais dados)
        ),
      );
      // Força rebuild para mostrar o novo player
      setState(() {
        _currentlyPlayingVideoId = videoId;
      });
      // Listener opcional para saber quando o controller está pronto
      // _controller?.addListener(_youtubePlayerListener);

    } catch (e) {
      print("Erro ao inicializar YoutubePlayerController: $e");
      // Opcional: Mostrar mensagem de erro para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar o vídeo.'), backgroundColor: Colors.red),
      );
      setState(() {
         _currentlyPlayingVideoId = null; // Reseta se falhar
         _controller = null;
      });
    }
  }

  /* void _youtubePlayerListener() {
    if (_controller != null && mounted) {
      // Exemplo: Verificar se está pronto
      // if (_controller!.value.isReady) {
      //   print("Player pronto!");
      // }
      // Exemplo: Verificar se terminou
      // if (_controller!.value.playerState == PlayerState.ended) {
      //    print("Vídeo terminou!");
      //    // Você pode fechar o player ou carregar o próximo
      //    // setState(() {
      //    //   _currentlyPlayingVideoId = null;
      //    //   _controller = null;
      //    // });
      // }
    }
  } */

  @override
  void dispose() {
    // Libera o controller quando a tela for descartada
    // _controller?.removeListener(_youtubePlayerListener); // Se adicionou listener
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtém o tema e o esquema de cores do contexto
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        // Usa a cor primária definida no seu AppBarTheme ou diretamente do AppTheme
        // backgroundColor: theme.appBarTheme.backgroundColor ?? AppTheme.kPrimaryColor,
        // titleTextStyle: theme.appBarTheme.titleTextStyle, // Usa o estilo do tema
        // iconTheme: theme.appBarTheme.iconTheme, // Usa o tema para o ícone de voltar
        title: const Text('Tutoriais em Vídeo'),
      ),
      body: Column(
        children: [
          // --- Player de Vídeo ou Placeholder ---
          AnimatedSwitcher( // Anima a transição entre placeholder e player
            duration: const Duration(milliseconds: 300),
            child: _controller != null && _currentlyPlayingVideoId != null
              ? Container(
                  key: ValueKey(_currentlyPlayingVideoId), // Chave para AnimatedSwitcher
                  color: Colors.black, // Fundo preto para o player
                  child: YoutubePlayerBuilder(
                    player: YoutubePlayer(
                      controller: _controller!,
                      showVideoProgressIndicator: true,
                      // Usa cores do tema para a barra de progresso
                      progressIndicatorColor: AppTheme.kPrimaryColor,
                      progressColors: const ProgressBarColors(
                        playedColor: AppTheme.kPrimaryColor,
                        handleColor: AppTheme.kSecondaryColor, // Cor secundária para o handle
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                      // Opcional: Adicionar callbacks
                      // onReady: () { print('Player pronto.'); },
                      // onEnded: (data) { print('Vídeo terminou.'); },
                    ),
                    builder: (context, player) {
                      // AspectRatio garante proporção correta do vídeo
                      return AspectRatio(
                        aspectRatio: 16 / 9,
                        child: player,
                      );
                    },
                  ),
                )
              : Container( // Placeholder quando nenhum vídeo está tocando
                  key: const ValueKey('placeholder'), // Chave para AnimatedSwitcher
                  height: 200,
                  // Usa uma cor de fundo sutil do tema
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 48,
                        color: AppTheme.kSecondaryTextColor.withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecione um vídeo abaixo',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppTheme.kSecondaryTextColor.withOpacity(0.8)
                        ),
                      ),
                    ],
                  ),
                ),
          ),

          // --- Lista de Vídeos ---
          Expanded(
            child: FutureBuilder<List<TutorialVideo>>(
              future: _fetchTutorialVideos(), // Busca os vídeos
              builder: (context, snapshot) {
                // Estado de carregamento
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Estado de erro
                if (snapshot.hasError) {
                  print("Erro no FutureBuilder: ${snapshot.error}");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erro ao carregar vídeos.\nTente novamente mais tarde.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      ),
                    ),
                  );
                }
                // Estado sem dados (ou lista vazia)
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum vídeo tutorial disponível no momento.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(color: AppTheme.kSecondaryTextColor),
                      ),
                    ),
                  );
                }

                // Atualiza a lista local com os dados carregados
                _videoList = snapshot.data!;

                // Constrói a lista de vídeos
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0), // Padding geral da lista
                  itemCount: _videoList.length,
                  itemBuilder: (context, index) {
                    final video = _videoList[index];
                    final bool isPlaying = _currentlyPlayingVideoId == video.youtubeVideoId;

                    return Card(
                      // O Card usará o CardTheme definido no AppTheme
                      // elevation: isPlaying ? 4.0 : 1.0, // Opcional: Aumentar elevação se tocando
                      // shape: RoundedRectangleBorder(...), // Já definido no tema
                      // color: theme.cardTheme.color, // Já definido no tema
                      clipBehavior: Clip.antiAlias, // Para o InkWell respeitar as bordas arredondadas
                      child: ListTile(
                        leading: Icon(
                          isPlaying ? Icons.play_arrow_rounded : Icons.video_library_rounded,
                          size: 28,
                          // Usa cor primária quando tocando, secundária caso contrário
                          color: isPlaying ? colorScheme.primary : AppTheme.kSecondaryTextColor,
                        ),
                        title: Text(
                          video.title,
                          style: textTheme.titleSmall?.copyWith(
                            // Usa cor primária e negrito quando tocando
                            color: isPlaying ? colorScheme.primary : AppTheme.kWinPrimaryText,
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: video.description.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  video.description,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppTheme.kSecondaryTextColor,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : null,
                        trailing: Icon( // Ícone indicativo de ação
                          Icons.chevron_right_rounded,
                          color: AppTheme.kSecondaryTextColor.withOpacity(0.6),
                        ),
                        onTap: () {
                          // Inicia a reprodução do vídeo ao tocar no item
                          _playVideo(video.youtubeVideoId);
                        },
                        // Destaque visual quando selecionado
                        selected: isPlaying,
                        selectedTileColor: colorScheme.primary.withOpacity(0.08),
                        dense: false, // Pode ajustar para true se quiser itens mais compactos
                        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Ajuste padding
                      ),
                    );
                  },
                  // Adiciona um divisor sutil entre os itens
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16, // Indentação para alinhar com o conteúdo do ListTile
                    endIndent: 16,
                    color: theme.dividerTheme.color?.withOpacity(0.5), // Usa cor do tema com opacidade
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}