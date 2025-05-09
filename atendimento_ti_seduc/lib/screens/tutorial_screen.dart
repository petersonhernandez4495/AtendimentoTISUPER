import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection'; // Para LinkedHashMap
import 'package:url_launcher/url_launcher.dart';

// Importe seu modelo e tema.
import '../models/tutorial_video_model.dart';
import '../config/theme/app_theme.dart';

class TutorialScreen extends StatefulWidget {
  static const String routeName = '/tutoriais';
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  Map<String, List<TutorialVideo>> _videosPorCategoria = LinkedHashMap();
  List<String> _categorias = [];
  bool _isLoadingData = true;
  String? _errorMessage;
  String? _selectedVideoIdForHighlight;
  String? _lastSelectedVideoTitle;

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
          .collection('tutoriais') // Sua coleção de tutoriais
          .orderBy('ordem',
              descending:
                  false) // Opcional: ordene pela ordem definida no Firestore
          .get();

      final List<TutorialVideo> todosOsVideos = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;
            try {
              // <<<--- CORREÇÃO AQUI: Removido doc.id da chamada --- >>>
              final video = TutorialVideo.fromMap(data);
              if (video.youtubeVideoId.isNotEmpty) {
                return video;
              } else {
                print(
                    "AVISO (TutorialScreen): Documento ${doc.id} ('${data['title'] ?? 'Título Desconhecido'}') com ID do YouTube vazio ou inválido. Ignorando.");
                return null;
              }
            } catch (e) {
              print("Erro ao processar o vídeo ${doc.id}: $e");
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
        videos.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
    final Uri youtubeUrl =
        Uri.parse('https://www.youtube.com/watch?v=$videoId');

    if (mounted) {
      setState(() {
        _selectedVideoIdForHighlight = videoId;
        _lastSelectedVideoTitle = videoTitle;
      });
    }

    print("Tentando abrir URL: $youtubeUrl");

    if (await canLaunchUrl(youtubeUrl)) {
      await launchUrl(youtubeUrl, mode: LaunchMode.externalApplication);
    } else {
      print("Não foi possível abrir a URL: $youtubeUrl");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Não foi possível abrir o vídeo: '$videoTitle'. Verifique se você tem um navegador ou o app do YouTube instalado.")),
        );
        setState(() {
          // Limpa a seleção se falhar
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        _lastSelectedVideoTitle != null
            ? 'Abrindo vídeo: $_lastSelectedVideoTitle...'
            : 'Selecione um vídeo da lista para assistir.',
        style:
            textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topMessageArea,
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
                                color: theme.appBarTheme.backgroundColor ??
                                    theme.colorScheme.surface,
                                child: TabBar(
                                  isScrollable: true,
                                  indicatorColor: colorScheme.primary,
                                  labelColor: colorScheme.primary,
                                  unselectedLabelColor: colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.8),
                                  labelStyle: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5),
                                  unselectedLabelStyle: textTheme.titleSmall
                                      ?.copyWith(letterSpacing: 0.5),
                                  indicatorWeight: 2.5,
                                  indicatorPadding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  tabs: _categorias
                                      .map((categoria) =>
                                          Tab(text: categoria.toUpperCase()))
                                      .toList(),
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Expanded(
                                child: TabBarView(
                                  children: _categorias.map((categoria) {
                                    final videosDaCategoria =
                                        _videosPorCategoria[categoria] ?? [];
                                    if (videosDaCategoria.isEmpty) {
                                      return Center(
                                          child: Text(
                                              'Nenhum vídeo nesta categoria.',
                                              style: textTheme.bodyMedium));
                                    }
                                    return ListView.builder(
                                      padding: const EdgeInsets.all(12.0),
                                      itemCount: videosDaCategoria.length,
                                      itemBuilder: (context, index) {
                                        final video = videosDaCategoria[index];
                                        final bool isSelected =
                                            _selectedVideoIdForHighlight ==
                                                video.youtubeVideoId;
                                        final thumbnailUrl =
                                            'https://img.youtube.com/vi/${video.youtubeVideoId}/mqdefault.jpg';

                                        return Card(
                                          elevation: isSelected ? 6.0 : 2.0,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          clipBehavior: Clip.antiAlias,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: isSelected
                                                ? BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 2)
                                                : BorderSide(
                                                    color: theme.dividerColor
                                                        .withOpacity(0.3)),
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              _openVideoInBrowser(
                                                  video.youtubeVideoId,
                                                  video.title);
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    child: Image.network(
                                                      thumbnailUrl,
                                                      width: 120,
                                                      height: 70,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Container(
                                                          width: 120,
                                                          height: 70,
                                                          color:
                                                              Colors.grey[300],
                                                          child: Icon(
                                                              Icons
                                                                  .ondemand_video_rounded,
                                                              color: Colors
                                                                  .grey[600],
                                                              size: 40),
                                                        );
                                                      },
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return Container(
                                                            width: 120,
                                                            height: 70,
                                                            color: Colors
                                                                .grey[200],
                                                            child: Center(
                                                                child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    value: loadingProgress.expectedTotalBytes !=
                                                                            null
                                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                                            loadingProgress.expectedTotalBytes!
                                                                        : null)));
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          video.title,
                                                          style: textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                            color: isSelected
                                                                ? colorScheme
                                                                    .primary
                                                                : colorScheme
                                                                    .onSurface,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (video.description
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            video.description,
                                                            style: textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                    color: colorScheme
                                                                        .onSurfaceVariant),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8.0),
                                                    child: Icon(
                                                        Icons
                                                            .open_in_new_rounded,
                                                        color: colorScheme
                                                            .primary
                                                            .withOpacity(0.8),
                                                        size: 20),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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
    return const Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Carregando tutoriais...'),
      ],
    ));
  }

  Widget buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ??
                  'Ocorreu um erro inesperado ao carregar os tutoriais.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar Novamente'),
              onPressed: _fetchAndGroupTutorialVideos,
            )
          ],
        ),
      ),
    );
  }

  Widget buildEmptyListWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                color: Colors.grey[500], size: 48),
            const SizedBox(height: 16),
            Text(
              'Nenhum vídeo tutorial disponível no momento.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
