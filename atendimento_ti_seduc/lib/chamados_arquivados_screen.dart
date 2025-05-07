// lib/screens/chamados_arquivados_screen.dart (Exemplo de caminho)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../pdf_generator.dart' as pdfGen;
// --- CORREÇÃO DE IMPORTAÇÃO ---
// Assumindo que 'detalhes_chamado_screen.dart' está na pasta 'lib/'
// e este arquivo ('chamados_arquivados_screen.dart') está em 'lib/screens/'
import '../detalhes_chamado_screen.dart';
import '../config/theme/app_theme.dart';
import '../widgets/chamado_list_item.dart';
import '../services/chamado_service.dart';

// Constantes de Espaçamento (MAIS COMPACTAS) - movidas para o topo do arquivo ou para um arquivo de constantes global
const double kSpacingXXSmall = 2.0;
const double kSpacingXSmall = 4.0;
const double kSpacingSmall = 8.0;
const double kSpacingMedium = 12.0;
const double kSpacingLarge = 16.0;
const double kSpacingXLarge = 20.0;


class ListaChamadosArquivadosScreen extends StatefulWidget {
  const ListaChamadosArquivadosScreen({super.key});

  @override
  State<ListaChamadosArquivadosScreen> createState() =>
      _ListaChamadosArquivadosScreenState();
}

class _ListaChamadosArquivadosScreenState
    extends State<ListaChamadosArquivadosScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<QueryDocumentSnapshot>? _currentDocs;

  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Finalizados Mais Recentes', 'field': kFieldAdminFinalizouData, 'descending': true},
    {'label': 'Finalizados Mais Antigos', 'field': kFieldAdminFinalizouData, 'descending': false},
    {'label': 'Data de Criação (Recentes)', 'field': kFieldDataCriacao, 'descending': true},
    {'label': 'Data de Criação (Antigos)', 'field': kFieldDataCriacao, 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  User? _currentUser;
  bool _isDownloadingPdf = false;
  String? _downloadingPdfId;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0];
    _currentUser = _auth.currentUser;
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (!mounted) return;
    if (!_isLoadingRole) return;
    bool isAdminResult = false;
    User? user = _auth.currentUser;
    if (user != null) {
      final userId = user.uid;
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        }
      } catch (e, s) {
        print("Erro buscar role Arquivados: $e\n$s");
      }
    }
    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false;
      });
    }
  }

  bool get _isFilterActive {
    return _selectedDateFilter != null ||
        _selectedSortOption['field'] != kFieldAdminFinalizouData;
  }

  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection(kCollectionChamados);

    query = query.where(kFieldStatus, isEqualTo: kStatusFinalizado);

    if (!_isLoadingRole && !_isAdmin) {
      if (_currentUser != null) {
        query = query.where(kFieldCreatorUid, isEqualTo: _currentUser!.uid);
      } else {
        query = query.where('__inexistente__', isEqualTo: '__sem_resultados__');
      }
    } else if (_isLoadingRole) {
        query = query.where('__inexistente__', isEqualTo: '__aguardando_role__');
    }

    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59, 999);
      query = query.where(kFieldAdminFinalizouData, isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      query = query.where(kFieldAdminFinalizouData, isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    final String sortField = _selectedSortOption['field'] as String;
    final bool sortDescending = _selectedSortOption['descending'] as bool;

    query = query.orderBy(sortField, descending: sortDescending);

    if (sortField != kFieldDataCriacao) {
      query = query.orderBy(kFieldDataCriacao, descending: true);
    }
    return query;
  }

  Future<void> _handleDownloadPdf(String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(key: ValueKey("pdf_loading_dialog_arquivados"))));

    Map<String, dynamic>? docData;
    QueryDocumentSnapshot? foundDoc;

    if (_currentDocs != null) {
      for (final docInLoop in _currentDocs!) {
        if (docInLoop.id == chamadoId) {
          foundDoc = docInLoop;
          break;
        }
      }
    }
    
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
    }

    if (foundDoc != null && foundDoc.exists) {
      docData = foundDoc.data() as Map<String, dynamic>?;
    } else {
      try {
        DocumentSnapshot firestoreDoc = await FirebaseFirestore.instance.collection(kCollectionChamados).doc(chamadoId).get();
        if (firestoreDoc.exists) {
          docData = firestoreDoc.data() as Map<String, dynamic>?;
        }
      } catch (e) {
        // Erro já tratado no print
      }
    }

    if (docData == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Erro: Dados do chamado arquivado não encontrados para gerar PDF.'), backgroundColor: Colors.orange));
      if(mounted) setState(() { _isDownloadingPdf = false; _downloadingPdfId = null; });
      return;
    }

    if (mounted) setState(() { _isDownloadingPdf = true; _downloadingPdfId = chamadoId;});

    try {
      await pdfGen.generateAndOpenPdfForTicket(
        context: context,
        chamadoId: chamadoId,
        dadosChamado: docData,
      );
    } catch (e, s) {
      print(" _handleDownloadPdf Arquivados: Exceção ao gerar/abrir PDF $chamadoId: $e\nStackTrace: $s");
    } finally {
      if (mounted) {
        setState(() { _isDownloadingPdf = false; _downloadingPdfId = null;});
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            final theme = Theme.of(context);
            return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 0.8,
                builder: (_, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(kSpacingMedium).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + kSpacingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Filtros e Ordenação (Arquivados)', style: theme.textTheme.titleLarge),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDateFilter = null;
                                  _selectedSortOption = _sortOptions[0];
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Limpar'),
                            ),
                          ],
                        ),
                        const Divider(height: kSpacingLarge),
                        Text('Filtrar por Data de Finalização:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: kSpacingSmall),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _selectedDateFilter == null
                                  ? 'Selecionar Data'
                                  : 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDateFilter!)}',
                                ),
                                onPressed: () async {
                                  final DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDateFilter ?? DateTime.now(),
                                    firstDate: DateTime(DateTime.now().year - 5),
                                    lastDate: DateTime.now(),
                                    locale: const Locale('pt', 'BR'),
                                    helpText: 'SELECIONE A DATA DE FINALIZAÇÃO',
                                  );
                                  if (pickedDate != null) {
                                    setState(() { _selectedDateFilter = pickedDate; });
                                    sheetSetState(() {});
                                  }
                                },
                              ),
                            ),
                            if (_selectedDateFilter != null) IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                onPressed: () {
                                  setState(() { _selectedDateFilter = null; });
                                  sheetSetState(() {});
                                },
                              )
                          ],
                        ),
                        const SizedBox(height: kSpacingLarge),
                        Text('Ordenar por:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: kSpacingSmall),
                        Wrap(
                          spacing: kSpacingSmall,
                          runSpacing: kSpacingXSmall,
                          children: _sortOptions.map((option) {
                            final bool isSelected = _selectedSortOption['label'] == option['label'];
                            return ChoiceChip(
                              label: Text(option['label'] as String),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() { _selectedSortOption = option; });
                                  sheetSetState(() {});
                                }
                              },
                              selectedColor: theme.colorScheme.primaryContainer,
                              labelStyle: TextStyle(color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: kSpacingLarge),
                      ],
                    ),
                  );
                });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ AppTheme.kWinBackground, Colors.white, ],
                begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.7],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpacingMedium, kSpacingSmall, kSpacingMedium, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          Icons.filter_list_alt,
                          color: _isFilterActive ? colorScheme.primary : AppTheme.kWinSecondaryText,
                          size: 20,
                        ),
                        label: Text('Filtros', style: TextStyle(color: _isFilterActive ? colorScheme.primary : AppTheme.kWinSecondaryText,)),
                        onPressed: _showFilterBottomSheet,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoadingRole
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<QuerySnapshot>(
                          stream: _buildFirestoreQuery().snapshots(),
                          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Padding(
                                padding: const EdgeInsets.all(kSpacingMedium),
                                child: Text('Erro: ${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                              ));
                            }
                            if (snapshot.connectionState == ConnectionState.waiting && _currentDocs == null) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            _currentDocs = snapshot.data?.docs;
                                                        
                            if (_currentDocs == null || _currentDocs!.isEmpty) {
                              String msg = _isAdmin ? 'Nenhum chamado finalizado/arquivado.' : 'Você não possui chamados finalizados/arquivados.';
                              if (_isFilterActive) msg = 'Nenhum chamado finalizado com os filtros.';
                              
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(kSpacingLarge),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey[500]),
                                      const SizedBox(height: kSpacingMedium),
                                      Text(msg, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                                      if (_isFilterActive) ...[
                                        const SizedBox(height: kSpacingLarge),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.clear_all),
                                          label: const Text('Limpar Filtros'),
                                          onPressed: () => setState(() { _selectedDateFilter = null; _selectedSortOption = _sortOptions[0]; }),
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

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: kSpacingSmall, left: kSpacingSmall, right: kSpacingSmall, bottom: 72.0),
                              itemCount: _currentDocs!.length,
                              itemBuilder: (BuildContext context, int index) {
                                final DocumentSnapshot document = _currentDocs![index];
                                final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};
                                final chamadoId = document.id;
                                final bool isLoadingPdf = _isDownloadingPdf && _downloadingPdfId == chamadoId;
                                
                                final Timestamp? adminFinalizouTimestamp = data[kFieldAdminFinalizouData] as Timestamp?;
                                final String dataFinalizacaoKey = adminFinalizouTimestamp?.millisecondsSinceEpoch.toString() ?? data[kFieldDataCriacao]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

                                return ChamadoListItem(
                                  key: ValueKey("archived_${chamadoId}_$dataFinalizacaoKey"),
                                  chamadoId: chamadoId,
                                  chamadoData: data,
                                  currentUser: _currentUser,
                                  isAdmin: _isAdmin,
                                  onConfirmar: null, // Ação não relevante para arquivados
                                  isLoadingConfirmation: false,
                                  onDelete: null, // Decidimos não permitir exclusão de arquivados por enquanto
                                  onNavigateToDetails: (id) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DetalhesChamadoScreen(chamadoId: id)),
                                    );
                                  },
                                  onDownloadPdf: _handleDownloadPdf,
                                  isLoadingPdfDownload: isLoadingPdf,
                                  // onFinalizarArquivar e isLoadingFinalizarArquivar não são necessários aqui
                                );
                              },
                            );
                          },
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