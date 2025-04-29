// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pdf_generator.dart';
import 'detalhes_chamado_screen.dart';
import 'config/theme/app_theme.dart';
import 'widgets/ticket_card.dart';
import 'widgets/horizontal_date_selector.dart';
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
    // Removido 'Todos' daqui, será tratado implicitamente
    'aberto',
    'em andamento',
    'pendente',
    'resolvido',
    'fechado'
  ];
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': 'data_criacao', 'descending': true},
    {'label': 'Mais Antigos', 'field': 'data_criacao', 'descending': false},
    // Adicione outras opções de ordenação se necessário
    // {'label': 'Prioridade (Alta > Baixa)', 'field': 'prioridade', 'descending': true},
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Define a opção inicial
    // Configura o locale padrão para pt_BR para formatação de data
    // Descomente a linha abaixo e o import se necessário
    // initializeDateFormatting('pt_BR', null);
  }

  // Verifica se algum filtro está ativo (exceto ordenação padrão)
  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
           _selectedDateFilter != null ||
           _selectedSortOption['label'] != _sortOptions[0]['label']; // Verifica se não é a ordenação padrão
  }

  // Constrói a query do Firestore
  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('chamados');

    if (_selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59);
      query = query.where('data_criacao', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      query = query.where('data_criacao', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }
    query = query.orderBy(_sortField, descending: _sortDescending);
    if (_sortField != 'data_criacao') {
      query = query.orderBy('data_criacao', descending: true);
    }
    return query;
  }

  // Função para excluir chamado (sem alterações)
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
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Excluir', style: TextStyle(color: AppTheme.kErrorColor)),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ?? false;

    if (!confirmarExclusao || !mounted) return;

    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chamado excluído com sucesso!')),
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

  // Função para gerar PDF (sem alterações)
  Future<void> _gerarECompartilharPdfLista() async {
    if (_currentDocs == null || _currentDocs!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nenhum chamado na lista atual para gerar PDF.')));
      }
      return;
    }
    if (mounted) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
    }
    try {
      final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!);
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      final result = await Share.shareXFiles([XFile(filePath)], text: 'Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
       if (result.status == ShareResultStatus.success && mounted) {
         print("Compartilhamento da lista de chamados iniciado com sucesso.");
       } else if (mounted) {
         print("Compartilhamento cancelado ou falhou: ${result.status}");
       }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      print("Erro ao gerar/compartilhar PDF da lista: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao gerar PDF da lista: ${e.toString()}')));
      }
    }
  }

  // --- NOVA FUNÇÃO: Mostrar Bottom Sheet de Filtros ---
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o sheet seja maior que metade da tela
      shape: const RoundedRectangleBorder( // Bordas arredondadas
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        // StatefulBuilder permite atualizar a UI *dentro* do bottom sheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return DraggableScrollableSheet( // Permite rolagem se o conteúdo for grande
              expand: false, // Não expande para tela cheia por padrão
              initialChildSize: 0.5, // Altura inicial (50% da tela)
              minChildSize: 0.3, // Altura mínima
              maxChildSize: 0.8, // Altura máxima
              builder: (_, scrollController) {
                 return SingleChildScrollView( // Garante rolagem interna
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Ocupa o mínimo de espaço vertical
                      children: [
                        // --- Título ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Filtros e Ordenação', style: theme.textTheme.titleLarge),
                            // Botão para limpar filtros (opcional)
                            TextButton(
                              onPressed: () {
                                // Chama setState da tela principal e do sheet
                                setState(() {
                                  _selectedStatusFilter = null;
                                  _selectedSortOption = _sortOptions[0]; // Volta ao padrão
                                  _sortField = _selectedSortOption['field'];
                                  _sortDescending = _selectedSortOption['descending'];
                                  // Não limpa a data aqui, pois ela tem seu próprio controle
                                });
                                sheetSetState(() {}); // Atualiza o sheet
                                // Navigator.pop(context); // Fecha o sheet após limpar
                              },
                              child: const Text('Limpar'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // --- Filtro de Status ---
                        Text('Filtrar por Status:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _statusOptions.map((status) {
                            final bool isSelected = _selectedStatusFilter == status;
                            return FilterChip(
                              label: Text(status),
                              selected: isSelected,
                              onSelected: (selected) {
                                // Chama setState da tela principal E do sheet
                                setState(() {
                                  _selectedStatusFilter = selected ? status : null;
                                });
                                sheetSetState(() {}); // Atualiza visualmente o chip no sheet
                              },
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                              labelStyle: TextStyle(
                                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                              ),
                              // showCheckmark: false, // Se preferir sem o check
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // --- Ordenação ---
                        Text('Ordenar por:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _sortOptions.map((option) {
                            final bool isSelected = _selectedSortOption['label'] == option['label'];
                            return ChoiceChip(
                              label: Text(option['label'] as String),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  // Chama setState da tela principal E do sheet
                                  setState(() {
                                    _selectedSortOption = option;
                                    _sortField = option['field'] as String;
                                    _sortDescending = option['descending'] as bool;
                                  });
                                   sheetSetState(() {}); // Atualiza visualmente o chip no sheet
                                }
                              },
                              selectedColor: colorScheme.primaryContainer,
                               labelStyle: TextStyle(
                                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20), // Espaço extra no final
                         // Botão "Aplicar" ou "Fechar" (opcional)
                          /* ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Fechar'),
                          ), */
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Barra Superior com Ícones de Filtro e PDF ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espaça os ícones
            children: [
              // Ícone de Filtro
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Abrir Filtros',
                // Muda a cor do ícone se algum filtro estiver ativo
                color: _isFilterActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                onPressed: _showFilterBottomSheet, // Abre o Bottom Sheet
              ),
              // Ícone de PDF
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Gerar PDF da Lista',
                color: colorScheme.onSurfaceVariant, // Cor padrão
                onPressed: _gerarECompartilharPdfLista,
              ),
            ],
          ),
        ),
        // Linha divisória opcional
        // const Divider(height: 1, thickness: 1),

        // --- Carrossel de Datas ---
        HorizontalDateSelector(
          initialSelectedDate: _selectedDateFilter,
          onDateSelected: (date) {
            setState(() {
              _selectedDateFilter = date;
            });
          },
        ),

        // --- Lista/Grade de Chamados ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildFirestoreQuery().snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erro ao carregar chamados: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              _currentDocs = snapshot.data?.docs;

              if (_currentDocs == null || _currentDocs!.isEmpty) {
                bool filtroAtivo = _isFilterActive || _selectedDateFilter != null; // Checa filtros + data
                String mensagem = filtroAtivo
                    ? 'Nenhum chamado encontrado com os filtros atuais.'
                    : 'Nenhum chamado registrado no momento.';
                IconData icone = filtroAtivo ? Icons.filter_alt_off_outlined : Icons.inbox_outlined;

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
                      ],
                    ),
                  ),
                );
              }

              // Exibe a Grade de Chamados
              return GridView.builder(
                 padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 16.0),
                 gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                   maxCrossAxisExtent: 300.0,
                   mainAxisSpacing: 0,
                   crossAxisSpacing: 0,
                   childAspectRatio: (300 / 300),
                 ),
                 itemCount: _currentDocs!.length,
                 itemBuilder: (BuildContext context, int index) {
                    final DocumentSnapshot document = _currentDocs![index];
                    final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};

                    // Extração de dados
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

                    // Instancia o TicketCard
                    return TicketCard(
                      key: ValueKey(document.id),
                      chamadoId: document.id,
                      titulo: titulo,
                      prioridade: prioridade,
                      status: status,
                      creatorName: creatorName,
                      dataFormatada: dataFormatada,
                      creatorPhone: creatorPhone,
                      tecnicoResponsavel: tecnicoResponsavel,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),
                          ),
                        );
                      },
                      onDelete: () {
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
}