import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection'; // Para LinkedHashMap

import 'package:webview_windows/webview_windows.dart' as windows_webview;

// Importe seu modelo e tema. Certifique-se que os caminhos estão corretos.
import '../models/tutorial_video_model.dart';
import '../config/theme/app_theme.dart';

class TutorialScreen extends StatefulWidget {
  static const String routeName = '/tutoriais';
  const TutorialScreen({super.key}); // super.key é o correto para o construtor principal da tela

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  String? _currentVideoIdForEmbed;
  String? _selectedVideoIdForHighlight;

  final _webviewController = windows_webview.WebviewController();

  Map<String, List<TutorialVideo>> _videosPorCategoria = LinkedHashMap();
  List<String> _categorias = [];
  bool _isLoadingData = true;
  String? _errorMessage;
  bool _isWebviewInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchAndGroupTutorialVideos();
    _initWebview();
  }

  @override
  void dispose() {
    _webviewController.dispose();
    super.dispose();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();
      if (!mounted) return;
      setState(() {
        _isWebviewInitialized = true;
      });

      _webviewController.url.listen((url) {
        // print('WebView (Windows) navegou para: $url');
      });
      _webviewController.loadingState.listen((state) {
        // print('WebView (Windows) estado de carregamento: $state');
      });
    } catch (e) {
      print("Erro ao inicializar o WebView para Windows: $e");
      if (!mounted) return;
      setState(() {
        if (e.toString().toLowerCase().contains("webview2 runtime") ||
            e.toString().toLowerCase().contains("0x80070002")) {
          _errorMessage =
              "O componente WebView2 Runtime não foi encontrado ou está desatualizado. "
              "Este componente é necessário para exibir vídeos.\n\n"
              "Por favor, instale ou atualize o WebView2 Runtime da Microsoft e reinicie o aplicativo.";
        } else {
          _errorMessage = "Erro ao inicializar o player de vídeo: $e.";
        }
        _isWebviewInitialized = false;
      });
    }
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

      // Utiliza TutorialVideo.fromMap que deve chamar a função de extração de ID internamente
      final List<TutorialVideo> todosOsVideos = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return null;

            // TutorialVideo.fromMap é responsável por chamar extractYouTubeIdFromString
            // e tratar a categoria corretamente.
            final video = TutorialVideo.fromMap(data);

            if (video.youtubeVideoId.isNotEmpty) {
              return video;
            } else {
              // O print de aviso deve vir da função de extração ou de dentro do fromMap
              // se o ID raw for vazio.
              print(
                  "AVISO (TutorialScreen): Documento ${doc.id} ('${data['title'] ?? 'Título Desconhecido'}') com ID do YouTube vazio ou inválido após processamento. Ignorando.");
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

  void _playVideo(String videoId) {
    if (videoId.isEmpty) {
      print("Tentativa de reproduzir vídeo com ID vazio.");
      if (mounted) {
        setState(() {
          _errorMessage = "ID do vídeo inválido.";
          _currentVideoIdForEmbed = null;
        });
      }
      return;
    }

    if (!_isWebviewInitialized) {
      print(
          "WebView (Windows) não está inicializado. Tentando inicializar novamente...");
      _initWebview().then((_) {
        if (_isWebviewInitialized && mounted) {
          _loadVideoIntoWebview(videoId);
        } else if (mounted) {
          print("Falha ao inicializar o WebView após tentativa em _playVideo.");
          setState(() {
            _errorMessage =
                "Não foi possível inicializar o player de vídeo. Tente selecionar novamente.";
          });
        }
      });
      return;
    }
    _loadVideoIntoWebview(videoId);
  }

  // Carrega o vídeo no componente WebView com a URL de embed CORRIGIDA
  void _loadVideoIntoWebview(String videoId) {
    final String embedUrl =
        'youtu.be8$videoId?autoplay=1&modestbranding=1&rel=0'; // rel=0 para não mostrar relacionados
    print("Carregando vídeo no WebView (Windows): ID $videoId, URL: $embedUrl");

    if (!mounted) return;
    setState(() {
      _currentVideoIdForEmbed = videoId;
      _selectedVideoIdForHighlight = videoId;
      _errorMessage = null;
    });

    if (_isWebviewInitialized) {
      _webviewController.loadUrl(embedUrl);
    } else {
      print(
          "Erro crítico: _loadVideoIntoWebview chamado mas WebView não está inicializado.");
      if (mounted) {
        setState(() {
          _errorMessage =
              "Player não inicializado. Não é possível carregar o vídeo.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Widget playerArea;

    if (_errorMessage != null &&
        _errorMessage!.toLowerCase().contains("webview2 runtime")) {
      playerArea = Container(
        key: const ValueKey('webview_error_runtime'),
        color: colorScheme.errorContainer.withOpacity(0.2),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: colorScheme.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Problema ao Carregar Vídeos',
                style: textTheme.titleLarge
                    ?.copyWith(color: colorScheme.onErrorContainer),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer.withOpacity(0.9)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.info_outline),
                label: const Text('Mais Informações'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: const Text(
                                "Microsoft Edge WebView2 Runtime"),
                            content: const Text(
                                "Este aplicativo utiliza o componente WebView2 da Microsoft para exibir conteúdo da web, como vídeos do YouTube.\n\n"
                                "Se os vídeos não estão carregando e você vê uma mensagem sobre o 'WebView2 Runtime', significa que este componente pode estar faltando, desatualizado ou corrompido no seu Windows.\n\n"
                                "Soluções comuns:\n"
                                "1. Verifique se o Microsoft Edge está atualizado.\n"
                                "2. Procure por 'Download WebView2 Runtime' no seu navegador e instale a versão 'Evergreen Standalone Installer' ou 'Evergreen Bootstrapper' do site oficial da Microsoft.\n"
                                "3. Reinicie este aplicativo após a instalação/atualização."),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text("OK"))
                            ],
                          ));
                },
              )
            ],
          ),
        ),
      );
    } else if (_currentVideoIdForEmbed != null && _isWebviewInitialized) {
      playerArea = windows_webview.Webview(
        _webviewController,
        // key: ValueKey('webview_player_$_currentVideoIdForEmbed'), // LINHA 316 ORIGINAL - Comentada conforme solicitado
        permissionRequested: (url, permission, isUserInitiated) async {
          return windows_webview.WebviewPermissionDecision.allow;
        },
      );
    } else if (!_isWebviewInitialized && _currentVideoIdForEmbed != null) {
      playerArea = Container(
          key: const ValueKey('webview_initializing_after_click'),
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text("Inicializando player de vídeo...",
                  style: textTheme.bodyMedium),
            ],
          ));
    } else {
      playerArea = Container(
        key: const ValueKey('placeholder_video_area'),
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 56,
              color: AppTheme.kSecondaryTextColor.withOpacity(
                  0.7), // Adapte se kSecondaryTextColor não existir em AppTheme
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Selecione um vídeo tutorial abaixo',
              style: textTheme.titleMedium?.copyWith(
                color: _errorMessage != null
                    ? colorScheme.error
                    : AppTheme.kSecondaryTextColor.withOpacity(
                        0.9), // Adapte se kSecondaryTextColor não existir
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
            aspectRatio: 16 / 9,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: playerArea,
            )),
        Expanded(
          child: _isLoadingData
              ? buildLoadingWidget()
              : (_errorMessage != null &&
                      !_errorMessage!
                          .toLowerCase()
                          .contains("webview2 runtime") &&
                      _currentVideoIdForEmbed == null)
                  ? buildErrorWidget()
                  : _categorias.isEmpty && !_isLoadingData
                      ? buildEmptyListWidget()
                      : DefaultTabController(
                          length: _categorias.length,
                          child: Column(
                            children: [
                              Container(
                                color: theme.appBarTheme.backgroundColor ??
                                    AppTheme
                                        .kWinBackground, // Adapte se kWinBackground não existir
                                child: TabBar(
                                  isScrollable: true,
                                  indicatorColor: colorScheme.primary,
                                  labelColor: colorScheme.primary,
                                  unselectedLabelColor: AppTheme
                                      .kSecondaryTextColor
                                      .withOpacity(
                                          0.8), // Adapte se kSecondaryTextColor não existir
                                  labelStyle: textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  unselectedLabelStyle: textTheme.titleSmall,
                                  tabs: _categorias
                                      .map((categoria) => Tab(text: categoria))
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
                                    return ListView.separated(
                                      // key: PageStorageKey('tutorial_list_$categoria'), // Comentado por precaução devido a erros anteriores com 'key'
                                      padding: const EdgeInsets.all(8.0),
                                      itemCount: videosDaCategoria.length,
                                      itemBuilder: (context, index) {
                                        final video = videosDaCategoria[index];
                                        final bool isPlaying =
                                            _selectedVideoIdForHighlight ==
                                                video.youtubeVideoId;
                                        return Card(
                                          elevation: isPlaying ? 4.0 : 1.0,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4.0, horizontal: 0),
                                          clipBehavior: Clip.antiAlias,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            side: isPlaying
                                                ? BorderSide(
                                                    color: colorScheme.primary,
                                                    width: 1.5)
                                                : BorderSide(
                                                    color: theme.dividerColor
                                                        .withOpacity(0.5)),
                                          ),
                                          child: ListTile(
                                            leading: Icon(
                                              isPlaying
                                                  ? Icons
                                                      .play_circle_filled_rounded
                                                  : Icons
                                                      .ondemand_video_rounded,
                                              size: 32,
                                              color: isPlaying
                                                  ? colorScheme.primary
                                                  : AppTheme
                                                      .kSecondaryTextColor, // Adapte se não existir
                                            ),
                                            title: Text(
                                              video.title,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(
                                                color: isPlaying
                                                    ? colorScheme.primary
                                                    : AppTheme
                                                        .kWinPrimaryText, // Adapte se não existir
                                                fontWeight: isPlaying
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: video
                                                    .description.isNotEmpty
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 4.0),
                                                    child: Text(
                                                      video.description,
                                                      style: textTheme.bodySmall
                                                          ?.copyWith(
                                                              color: AppTheme
                                                                  .kSecondaryTextColor), // Adapte
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )
                                                : null,
                                            trailing: Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppTheme
                                                  .kSecondaryTextColor
                                                  .withOpacity(
                                                      0.6), // Adapte
                                            ),
                                            onTap: () {
                                              _playVideo(video.youtubeVideoId);
                                            },
                                            selected: isPlaying,
                                            selectedTileColor: colorScheme
                                                .primary
                                                .withOpacity(0.08),
                                            dense: false,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8.0,
                                                    horizontal: 16.0),
                                          ),
                                        );
                                      },
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: 4),
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
          _errorMessage ??
              'Ocorreu um erro inesperado ao carregar os tutoriais.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.error),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme
                  .kSecondaryTextColor), // Adapte se kSecondaryTextColor não existir
        ),
      ),
    );
  }
}