import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection'; // Para LinkedHashMap
import 'package:url_launcher/url_launcher.dart'; // Importar o url_launcher

// Importe seu modelo e tema.
// Certifique-se que o modelo TutorialVideo tem o método fromMap
// e que a função extractYouTubeIdFromString está acessível e sendo usada por ele.
import '../models/tutorial_video_model.dart';
import '../config/theme/app_theme.dart'; // Suas configurações de tema

class TutorialScreen extends StatefulWidget {
  static const String routeName = '/tutoriais';
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  // Variáveis de estado para a lista e seleção
  Map<String, List<TutorialVideo>> _videosPorCategoria = LinkedHashMap();
  List<String> _categorias = [];
  bool _isLoadingData = true;
  String? _errorMessage;
  String? _selectedVideoIdForHighlight;
  String? _lastSelectedVideoTitle; // Para mostrar qual vídeo foi selecionado para abrir

  @override
  void initState() {
    super.initState();
    _fetchAndGroupTutorialVideos();
  }

  Future<void> _fetchAndGroupTutorialVideos() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tutoriais')
          .get();

      final List<TutorialVideo> todosOsVideos = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            // Assume que TutorialVideo.fromMap chama extractYouTubeIdFromString internamente
            // e também trata a formatação da categoria.
            final video = TutorialVideo.fromMap(data);
            if (video.youtubeVideoId.isNotEmpty) {
              return video;
            } else {
              print(
                  "AVISO (TutorialScreen): Documento ${doc.id} ('${data['title'] ?? 'Título Desconhecido'}') com ID do YouTube vazio ou inválido. Ignorando.");
              return null;
            }
          })
          .whereType<TutorialVideo>()
          .toList();

      final groupedVideos = LinkedHashMap<String, List<TutorialVideo>>();
      final List<String> orderedCategories = [];

      for (var video in todosOsVideos) {
        if (!orderedCategories.contains(video.categoria)) {
          orderedCategories.add(video.categoria);
        }
        (groupedVideos[video.categoria] ??= []).add(video);
      }

      groupedVideos.forEach((categoria, videos) {
        videos.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      });

      if (!mounted) return;
      setState(() {
        _videosPorCategoria = groupedVideos;
        _categorias = orderedCategories;
        _isLoadingData = false;
      });
    } catch (e, stackTrace) {
      print("Erro GERAL ao buscar e agrupar tutoriais: $e");
      print("Stack Trace GERAL: $stackTrace");
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Falha ao carregar os tutoriais. Verifique sua conexão ou os dados no Firestore.';
        _isLoadingData = false;
      });
    }
  }

  // CORRIGIDO DEFINITIVAMENTE para abrir a URL pública correta do YouTube no navegador
  Future<void> _openVideoInBrowser(String videoId, String videoTitle) async {
    if (videoId.isEmpty) {
      print("Tentativa de abrir vídeo com ID vazio.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ID do vídeo inválido.")),
        );
      }
      return;
    }

    // Constrói a URL padrão de visualização do YouTube
    final Uri youtubeUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    if (mounted) {
      setState(() {
        _selectedVideoIdForHighlight = videoId;
        _lastSelectedVideoTitle = videoTitle;
      });
    }

    print("Tentando abrir URL: $youtubeUrl"); // Log para verificar a URL completa

    if (await canLaunchUrl(youtubeUrl)) {
      // Tenta abrir no aplicativo do YouTube se possível, senão no navegador
      await launchUrl(youtubeUrl, mode: LaunchMode.externalApplication);
    } else {
      print("Não foi possível abrir a URL: $youtubeUrl");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Não foi possível abrir o vídeo: '$videoTitle'. Verifique se você tem um navegador ou o app do YouTube instalado.")),
        );
        setState(() {
          _lastSelectedVideoTitle = null;
          _selectedVideoIdForHighlight = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Widget topMessageArea = Container(
      padding: const EdgeInsets.all(16.0),
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      alignment: Alignment.center,
      child: Text(
        _lastSelectedVideoTitle != null
            ? 'Abrindo vídeo: $_lastSelectedVideoTitle...'
            : 'Selecione um vídeo da lista para abrir no seu navegador.',
        style: textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topMessageArea,
        const Divider(height: 1),
        Expanded(
          child: _isLoadingData
              ? buildLoadingWidget()
              : _errorMessage != null
                  ? buildErrorWidget()
                  : _categorias.isEmpty && !_isLoadingData
                      ? buildEmptyListWidget()
                      : DefaultTabController(
                          length: _categorias.length,
                          child: Column(
                            children: [
                              Container(
                                color: theme.appBarTheme.backgroundColor ?? AppTheme.kWinBackground, // Adapte se AppTheme.kWinBackground não existir
                                child: TabBar(
                                  isScrollable: true,
                                  indicatorColor: colorScheme.primary,
                                  labelColor: colorScheme.primary,
                                  unselectedLabelColor: AppTheme.kSecondaryTextColor.withOpacity(0.8), // Adapte se AppTheme.kSecondaryTextColor não existir
                                  labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  unselectedLabelStyle: textTheme.titleSmall,
                                  tabs: _categorias.map((categoria) => Tab(text: categoria)).toList(),
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Expanded(
                                child: TabBarView(
                                  children: _categorias.map((categoria) {
                                    final videosDaCategoria = _videosPorCategoria[categoria] ?? [];
                                    if (videosDaCategoria.isEmpty) {
                                      return Center(
                                          child: Text(
                                              'Nenhum vídeo nesta categoria.',
                                              style: textTheme.bodyMedium));
                                    }
                                    return ListView.separated(
                                      padding: const EdgeInsets.all(8.0),
                                      itemCount: videosDaCategoria.length,
                                      itemBuilder: (context, index) {
                                        final video = videosDaCategoria[index];
                                        final bool isSelected = _selectedVideoIdForHighlight == video.youtubeVideoId;
                                        return Card(
                                          elevation: isSelected ? 4.0 : 1.0,
                                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                                          clipBehavior: Clip.antiAlias,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: isSelected
                                                ? BorderSide(color: colorScheme.primary, width: 1.5)
                                                : BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                                          ),
                                          child: ListTile(
                                            leading: Icon(
                                              Icons.smart_display_rounded,
                                              size: 32,
                                              color: isSelected ? colorScheme.primary : AppTheme.kSecondaryTextColor, // Adapte se não existir
                                            ),
                                            title: Text(
                                              video.title,
                                              style: textTheme.titleSmall?.copyWith(
                                                color: isSelected ? colorScheme.primary : AppTheme.kWinPrimaryText, // Adapte se não existir
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: video.description.isNotEmpty
                                                ? Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
                                                    child: Text(
                                                      video.description,
                                                      style: textTheme.bodySmall?.copyWith(color: AppTheme.kSecondaryTextColor), // Adapte se não existir
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  )
                                                : null,
                                            trailing: const Icon(Icons.launch_rounded),
                                            onTap: () {
                                              _openVideoInBrowser(video.youtubeVideoId, video.title);
                                            },
                                            selected: isSelected,
                                            selectedTileColor: colorScheme.primary.withOpacity(0.08),
                                          ),
                                        );
                                      },
                                      separatorBuilder: (context, index) => const SizedBox(height: 4),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ],
    );
  }

  Widget buildLoadingWidget() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _errorMessage ?? 'Ocorreu um erro inesperado.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget buildEmptyListWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Nenhum vídeo tutorial disponível no momento.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.kSecondaryTextColor), // Adapte se não existir
        ),
      ),
    );
  }
}