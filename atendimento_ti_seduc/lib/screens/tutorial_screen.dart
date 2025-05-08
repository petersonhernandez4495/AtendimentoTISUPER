import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection';

import '../models/tutorial_video_model.dart';
import '../config/theme/app_theme.dart';

class TutorialScreen extends StatefulWidget {
  static const String routeName = '/tutoriais';
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  YoutubePlayerController? _controller;
  String? _currentlyPlayingVideoId;

  Map<String, List<TutorialVideo>> _videosPorCategoria = LinkedHashMap();
  List<String> _categorias = [];
  bool _isLoadingData = true;
  String? _errorMessage;

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

      final List<TutorialVideo> todosOsVideos = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String categoria = data['categoria']?.toString() ?? 'Outros';
        if (categoria.trim().isEmpty) {
            categoria = 'Outros';
        }

        return TutorialVideo(
          title: data['title'] ?? 'Título Indisponível',
          youtubeVideoId: YoutubePlayer.convertUrlToId(data['youtubeVideoId'] ?? '') ?? '',
          description: data['description'] ?? '',
          categoria: categoria,
        );
      }).where((video) => video.youtubeVideoId.isNotEmpty).toList();

      final groupedVideos = LinkedHashMap<String, List<TutorialVideo>>();
      final categoriesSet = <String>{};

      for (var video in todosOsVideos) {
        categoriesSet.add(video.categoria);
        (groupedVideos[video.categoria] ??= []).add(video);
      }

      if (mounted) {
        setState(() {
          _videosPorCategoria = groupedVideos;
          _categorias = categoriesSet.toList();
          _isLoadingData = false;
        });
      }

    } catch (e) {
      print("Erro ao buscar e agrupar tutoriais: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao carregar os tutoriais.';
          _isLoadingData = false;
        });
      }
    }
  }

  void _playVideo(String videoId) {
    if (_currentlyPlayingVideoId == videoId && _controller != null) {
      return;
    }
    _controller?.dispose();
    try {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
        ),
      );
      setState(() {
        _currentlyPlayingVideoId = videoId;
      });
    } catch (e) {
      print("Erro ao inicializar YoutubePlayerController: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar o vídeo.'), backgroundColor: Colors.red),
        );
      }
      setState(() {
          _currentlyPlayingVideoId = null;
          _controller = null;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Widget buildLoading() {
      return const Center(child: CircularProgressIndicator());
    }

    Widget buildError() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage ?? 'Ocorreu um erro inesperado.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      );
     }

    Widget buildEmpty() {
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

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _controller != null && _currentlyPlayingVideoId != null
              ? Container(
                  key: ValueKey(_currentlyPlayingVideoId),
                  color: Colors.black,
                  child: YoutubePlayerBuilder(
                    player: YoutubePlayer(
                      controller: _controller!,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: AppTheme.kPrimaryColor,
                      progressColors: const ProgressBarColors(
                        playedColor: AppTheme.kPrimaryColor,
                        handleColor: AppTheme.kSecondaryColor,
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    builder: (context, player) {
                      return AspectRatio(
                        aspectRatio: 16 / 9,
                        child: player,
                      );
                    },
                  ),
                )
              : Container(
                  key: const ValueKey('placeholder'),
                  height: 200,
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
                          color: AppTheme.kSecondaryTextColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Expanded(
          child: _isLoadingData
              ? buildLoading()
              : _errorMessage != null
                  ? buildError()
                  : _categorias.isEmpty
                      ? buildEmpty()
                      : DefaultTabController(
                          length: _categorias.length,
                          child: Column(
                            children: [
                              Container(
                                color: theme.appBarTheme.backgroundColor ?? AppTheme.kWinBackground,
                                child: TabBar(
                                  isScrollable: true,
                                  indicatorColor: colorScheme.primary,
                                  labelColor: colorScheme.primary,
                                  unselectedLabelColor: AppTheme.kSecondaryTextColor,
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
                                      return Center(child: Text('Nenhum vídeo nesta categoria.', style: textTheme.bodyMedium));
                                    }
                                    return ListView.separated(
                                      key: PageStorageKey('tutorial_list_$categoria'),
                                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                      itemCount: videosDaCategoria.length,
                                      itemBuilder: (context, index) {
                                        final video = videosDaCategoria[index];
                                        final bool isPlaying = _currentlyPlayingVideoId == video.youtubeVideoId;
                                        return Card(
                                          clipBehavior: Clip.antiAlias,
                                          child: ListTile(
                                            leading: Icon(
                                              isPlaying ? Icons.play_arrow_rounded : Icons.video_library_rounded,
                                              size: 28,
                                              color: isPlaying ? colorScheme.primary : AppTheme.kSecondaryTextColor,
                                            ),
                                            title: Text(
                                              video.title,
                                              style: textTheme.titleSmall?.copyWith(
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
                                            trailing: Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppTheme.kSecondaryTextColor.withOpacity(0.6),
                                            ),
                                            onTap: () {
                                              _playVideo(video.youtubeVideoId);
                                            },
                                            selected: isPlaying,
                                            selectedTileColor: colorScheme.primary.withOpacity(0.08),
                                            dense: false,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                          ),
                                        );
                                      },
                                      separatorBuilder: (context, index) => Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        indent: 16,
                                        endIndent: 16,
                                        color: theme.dividerTheme.color?.withOpacity(0.5),
                                      ),
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
}
