// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pdf_generator.dart'; // Certifique-se que este import existe e está correto
import 'detalhes_chamado_screen.dart';
import 'config/theme/app_theme.dart'; // Certifique-se que este import existe e está correto
import 'widgets/ticket_card.dart'; // Certifique-se que este import existe e está correto
import 'widgets/horizontal_date_selector.dart'; // Certifique-se que este import existe e está correto
// Descomente se a formatação de data pt_BR não estiver globalmente configurada
// import 'package:intl/date_symbol_data_local.dart';

class ListaChamadosScreen extends StatefulWidget {
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  List<QueryDocumentSnapshot>? _currentDocs;
  String? _selectedStatusFilter; // null representa 'Todos'
  String _sortField = 'data_criacao';
  bool _sortDescending = true;
  final List<String> _statusOptions = [
    'aberto',
    'em andamento',
    'pendente',
    'resolvido',
    'fechado'
  ];
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': 'data_criacao', 'descending': true},
    {'label': 'Mais Antigos', 'field': 'data_criacao', 'descending': false},
    // Adicione outras opções de ordenação se necessário (ex: por prioridade, status)
    // Lembre-se que ordenações diferentes de 'data_criacao' podem exigir índices compostos no Firestore.
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Inicia com 'Mais Recentes'
    // initializeDateFormatting('pt_BR', null); // Descomente se necessário
  }

  // Verifica se algum filtro (status, data ou ordenação diferente da padrão) está ativo
  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
           _selectedDateFilter != null ||
           _selectedSortOption['label'] != _sortOptions[0]['label'];
  }

  // Constrói a query do Firestore com base nos filtros e ordenação selecionados
  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('chamados');

    // Aplica filtro de status
    if (_selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }

    // Aplica filtro de data (dia inteiro)
    if (_selectedDateFilter != null) {
      // Define o início do dia (00:00:00)
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      // Define o fim do dia (23:59:59)
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59);
      // Filtra documentos onde 'data_criacao' está entre startOfDay e endOfDay
      query = query.where('data_criacao', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      query = query.where('data_criacao', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      // IMPORTANTE: Consultas de intervalo (range) em campos diferentes exigem índices.
      // Se você já filtra por status, filtrar por data_criacao pode dar erro sem um índice composto.
      // Ex: (status ASC, data_criacao ASC) e (status ASC, data_criacao DESC)
    }

    // Aplica ordenação principal
    query = query.orderBy(_sortField, descending: _sortDescending);

    // Adiciona ordenação secundária por data_criacao se a primária não for data_criacao
    // Ajuda a desempatar e garante ordem consistente. Requer índices compostos!
    if (_sortField != 'data_criacao') {
      query = query.orderBy('data_criacao', descending: true); // Ou false se preferir
    }
    return query;
  }

  // Função para mostrar confirmação e excluir chamado
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    bool confirmarExclusao = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: const Text(
                'Tem certeza que deseja excluir este chamado?\nEsta ação não pode ser desfeita.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  // Usando a cor de erro do tema atual
                  child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false; // Retorna false se o dialog for fechado sem clicar nos botões

    if (!confirmarExclusao || !mounted) return; // Sai se não confirmar ou se o widget foi desmontado

    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chamado excluído com sucesso!'), duration: Duration(seconds: 2)),
        );
      }
    } catch (error) {
      print('Erro ao excluir chamado: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir chamado: ${error.toString()}')),
        );
      }
    }
  }

  // Função para gerar e compartilhar PDF da lista atual de chamados
  Future<void> _gerarECompartilharPdfLista() async {
    if (_currentDocs == null || _currentDocs!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nenhum chamado na lista atual para gerar PDF.')));
      }
      return;
    }

    // Mostra indicador de progresso enquanto gera o PDF
    if (mounted) {
      showDialog(
          context: context,
          barrierDismissible: false, // Impede fechar clicando fora
          builder: (_) => const Center(child: CircularProgressIndicator()));
    }

    try {
      // Chama a função externa para gerar os bytes do PDF
      final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!); // Verifique se esta função existe e funciona

      // Salva o PDF em um arquivo temporário
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Fecha o dialog de progresso ANTES de abrir o compartilhamento
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Usa share_plus para compartilhar o arquivo
      final result = await Share.shareXFiles(
          [XFile(filePath)], // Cria um XFile a partir do path
          text: 'Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');

      // Feedback sobre o compartilhamento (opcional)
      if (result.status == ShareResultStatus.success && mounted) {
        print("Compartilhamento da lista de chamados iniciado com sucesso.");
      } else if (mounted) {
        print("Compartilhamento cancelado ou falhou: ${result.status}");
      }

    } catch (e) {
      // Garante fechar o dialog em caso de erro
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      print("Erro ao gerar/compartilhar PDF da lista: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao gerar PDF da lista: ${e.toString()}')));
      }
    }
  }

  // Função para mostrar o BottomSheet de filtros e ordenação
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o sheet ocupe mais espaço vertical
      shape: const RoundedRectangleBorder( // Bordas arredondadas no topo
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        // Usa StatefulBuilder para que os chips possam atualizar o estado visual
        // sem reconstruir a tela inteira por baixo.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            // Permite arrastar para ajustar a altura e rolar o conteúdo
            return DraggableScrollableSheet(
              expand: false, // Não expande para tela cheia
              initialChildSize: 0.6, // Altura inicial (ex: 60%)
              minChildSize: 0.3,   // Altura mínima
              maxChildSize: 0.9,   // Altura máxima
              builder: (_, scrollController) {
                // Conteúdo rolável dentro do sheet
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0).copyWith(bottom: 32.0), // Padding maior no final
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cabeçalho
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filtros e Ordenação', style: theme.textTheme.titleLarge),
                          TextButton(
                            onPressed: () {
                              // Ação Limpar: Reseta status e ordenação, mantém data
                              setState(() { // Atualiza o estado principal
                                _selectedStatusFilter = null;
                                _selectedSortOption = _sortOptions[0];
                                _sortField = _selectedSortOption['field'];
                                _sortDescending = _selectedSortOption['descending'];
                              });
                              sheetSetState(() {}); // Atualiza a UI do sheet
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Filtro por Status
                      Text('Filtrar por Status:', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0, runSpacing: 4.0,
                        children: _statusOptions.map((status) {
                          final bool isSelected = _selectedStatusFilter == status;
                          return FilterChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() { _selectedStatusFilter = selected ? status : null; });
                              sheetSetState(() {});
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                            labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Ordenar por
                      Text('Ordenar por:', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0, runSpacing: 4.0,
                        children: _sortOptions.map((option) {
                          final bool isSelected = _selectedSortOption['label'] == option['label'];
                          return ChoiceChip(
                            label: Text(option['label'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedSortOption = option;
                                  _sortField = option['field'] as String;
                                  _sortDescending = option['descending'] as bool;
                                });
                                sheetSetState(() {});
                              }
                            },
                            selectedColor: colorScheme.primaryContainer,
                            labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                    ],
                  ),
                );
              }
            );
          },
        );
      },
    );
  }


  // --- MÉTODO BUILD MODIFICADO ---
  // Removemos Scaffold e AppBar. Retornamos o Column diretamente.
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column( // <= Retorna Column diretamente
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botões de Filtro e PDF (mantidos aqui por enquanto)
        // Se a tela principal tiver uma AppBar, considere mover estes botões para lá.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espaça os botões
            children: [
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  // Destaque visual se filtro estiver ativo
                  color: _isFilterActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Abrir Filtros',
                onPressed: _showFilterBottomSheet,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Gerar PDF da Lista',
                color: colorScheme.onSurfaceVariant,
                onPressed: _gerarECompartilharPdfLista,
              ),
            ],
          ),
        ),

        // Seletor de Data Horizontal
        HorizontalDateSelector(
          initialSelectedDate: _selectedDateFilter,
          onDateSelected: (date) {
            setState(() {
              // Lógica para selecionar/desselecionar data
              _selectedDateFilter = (_selectedDateFilter == date) ? null : date;
            });
          },
        ),
        const Divider(height: 1, thickness: 1), // Linha divisória

        // Conteúdo principal: A lista de chamados
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildFirestoreQuery().snapshots(), // Usa a query dinâmica
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              // --- Tratamento de Estados do Stream ---
              if (snapshot.hasError) {
                print("Erro no StreamBuilder: ${snapshot.error}"); // Log do erro
                return Center(child: Text('Erro ao carregar chamados: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator()); // Indicador de carregamento
              }

              // Armazena os documentos atuais para uso no PDF
              _currentDocs = snapshot.data?.docs;

              // --- Tratamento de Lista Vazia ---
              if (_currentDocs == null || _currentDocs!.isEmpty) {
                bool filtroAtivo = _isFilterActive;
                String mensagem = filtroAtivo
                    ? 'Nenhum chamado encontrado com os filtros atuais.'
                    : 'Nenhum chamado registrado no momento.';
                IconData icone = filtroAtivo ? Icons.filter_alt_off_outlined : Icons.inbox_outlined;

                // Widget exibido quando não há chamados
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icone, size: 50, color: Colors.grey[500]),
                        const SizedBox(height: 16),
                        Text(
                          mensagem,
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                        ),
                        if (filtroAtivo) ...[ // Mostra botão apenas se filtro ativo
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Limpar Filtros'),
                              onPressed: () {
                                setState(() { // Limpa TODOS os filtros
                                  _selectedStatusFilter = null;
                                  _selectedDateFilter = null;
                                  _selectedSortOption = _sortOptions[0];
                                  _sortField = _selectedSortOption['field'];
                                  _sortDescending = _selectedSortOption['descending'];
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: colorScheme.onSecondaryContainer,
                                backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8)
                              ),
                            )
                        ]
                      ],
                    ),
                  ),
                );
              }

              // --- Construção da Grade de Chamados ---
              return GridView.builder(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 12.0, bottom: 16.0),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300.0, // Largura máx de cada item
                    mainAxisSpacing: 8.0,      // Espaço vertical
                    crossAxisSpacing: 8.0,     // Espaço horizontal
                    childAspectRatio: (2 / 2.1), // Proporção Largura/Altura - Ajuste conforme necessário!
                  ),
                  itemCount: _currentDocs!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final DocumentSnapshot document = _currentDocs![index];
                    // Usa um Map vazio seguro caso data() seja null
                    final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};

                    // Extração segura de dados com valores padrão
                    final String titulo = data['problema_ocorre'] as String? ?? data['titulo'] as String? ?? 'Problema não descrito';
                    final String prioridade = data['prioridade'] as String? ?? 'Normal';
                    final String status = data['status'] as String? ?? 'aberto';
                    final String creatorName = data['creatorName'] as String? ?? data['nome_solicitante'] as String? ?? 'Anônimo';
                    final String? creatorPhone = data['celular_contato'] as String? ?? data['creatorPhone'] as String?;
                    final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?;
                    final Timestamp? dataCriacaoTimestamp = data['data_criacao'] as Timestamp?;
                    final String dataFormatada = dataCriacaoTimestamp != null
                        ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate())
                        : '--';
                    final String cidade = data['cidade'] as String? ?? '';
                    final String instituicao = data['instituicao'] as String? ?? '';
                    final String? tipoSolicitante = data['tipo_solicitante'] as String?;
                    final String? setorSuperintendencia = data['setor_superintendencia'] as String?;
                    final String? cidadeSuperintendencia = data['cidade_superintendencia'] as String?;

                    // Cria e retorna o widget TicketCard para cada chamado
                    return TicketCard(
                      key: ValueKey(document.id), // Chave única para o widget
                      chamadoId: document.id,
                      titulo: titulo,
                      prioridade: prioridade,
                      status: status,
                      creatorName: creatorName,
                      dataFormatada: dataFormatada,
                      creatorPhone: creatorPhone,
                      tecnicoResponsavel: tecnicoResponsavel,
                      cidade: cidade,
                      instituicao: instituicao,
                      tipoSolicitante: tipoSolicitante,
                      setorSuperintendencia: setorSuperintendencia,
                      cidadeSuperintendencia: cidadeSuperintendencia,
                      onTap: () {
                        // Navega para detalhes ao tocar no card
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),
                          ),
                        );
                      },
                      onDelete: () {
                        // Chama a função de exclusão
                        _excluirChamado(context, document.id);
                      },
                    );
                  },
                );
            },
          ),
        ),
      ],
    );
  }

  // --- MÉTODO DISPOSE CORRIGIDO ---
  @override
  void dispose() {
    // Não há _scrollController para fazer dispose aqui nesta classe
    super.dispose(); // Chama o dispose da classe pai (importante!)
  }
}