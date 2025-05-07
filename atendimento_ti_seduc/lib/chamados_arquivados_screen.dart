import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// --- CORREÇÃO DE IMPORTAÇÃO ---
// Ajuste os caminhos conforme a estrutura do seu projeto
import '../pdf_generator.dart' as pdfGen;
import '../detalhes_chamado_screen.dart';
import '../config/theme/app_theme.dart';
import '../widgets/chamado_list_item.dart';
import '../services/chamado_service.dart';

// Constantes de Espaçamento
const double kSpacingSmall = 8.0;
const double kSpacingMedium = 12.0;
const double kSpacingLarge = 16.0;

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

  // --- NOVOS ESTADOS PARA LOADING DO PDF ---
  bool _isGeneratingOrHandlingPdfArquivados = false;
  String? _processingPdfIdArquivados;
  // --- FIM DOS NOVOS ESTADOS ---

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

  // --- FUNÇÕES AUXILIARES PDF (Arquivados) ---
  Future<void> _imprimirPdfArquivados(Uint8List pdfBytes) async {
    if(!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext dialogContext = context;

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator())),
    );
    try {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
      if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
         Navigator.of(dialogContext, rootNavigator: true).pop();
      }
    } catch (e) {
       if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
         Navigator.of(dialogContext, rootNavigator: true).pop();
      }
       if(mounted) {
         scaffoldMessenger.showSnackBar(
           SnackBar(content: Text('Erro ao preparar impressão: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }

  Future<void> _abrirPdfLocalmenteArquivados(Uint8List pdfBytes, String chamadoId) async {
     if (!mounted) return;
     final scaffoldMessenger = ScaffoldMessenger.of(context);
     BuildContext dialogContext = context;

     showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (_) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator())),
     );

     try {
        final outputDir = await getTemporaryDirectory();
        final filename = 'chamado_arq_${chamadoId.substring(0, min(6, chamadoId.length))}.pdf';
        final outputFile = File("${outputDir.path}/$filename");
        await outputFile.writeAsBytes(pdfBytes);

        if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
        }

        final result = await OpenFilex.open(outputFile.path);

        if (result.type != ResultType.done && mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Não foi possível abrir o PDF: ${result.message}')),
            );
        }
     } catch(e) {
         if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
         }
         if (mounted) {
           scaffoldMessenger.showSnackBar(
             SnackBar(content: Text('Erro ao abrir PDF localmente: $e'), backgroundColor: Colors.red),
           );
         }
     }
  }

  // --- FUNÇÃO PRINCIPAL PDF (Arquivados) ---
  Future<void> _gerarPdfEExibirOpcoesArquivados(String chamadoId, Map<String, dynamic> dadosChamado) async {
    if (!mounted) return;
    if (_isGeneratingOrHandlingPdfArquivados && _processingPdfIdArquivados == chamadoId) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContext = context;

    setState(() {
      _isGeneratingOrHandlingPdfArquivados = true;
      _processingPdfIdArquivados = chamadoId;
    });

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator())),
    );

    Uint8List? pdfBytes;
    try {
      pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
        chamadoId: chamadoId,
        dadosChamado: dadosChamado,
        adminSignatureUrl: null,
        requesterSignatureUrl: null,
      );
    } catch (e) {
        if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
          Navigator.of(currentContext, rootNavigator: true).pop();
        }
        if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
        if (mounted) {
            setState(() {
                _isGeneratingOrHandlingPdfArquivados = false;
                _processingPdfIdArquivados = null;
            });
        }
    }

    try {
        if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
            Navigator.of(currentContext, rootNavigator: true).pop();
        }
    } catch (_) { /* Ignora */ }

    if (pdfBytes != null && mounted) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Opções do PDF (Arquivado)'),
            content: const Text('O que você gostaria de fazer?'),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            actions: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir / Salvar'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _imprimirPdfArquivados(pdfBytes!);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Abrir / Visualizar'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _abrirPdfLocalmenteArquivados(pdfBytes!, chamadoId);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      );
    } else if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Falha ao gerar bytes do PDF.'), backgroundColor: Colors.orange),
      );
    }
  }
  // --- FIM DAS FUNÇÕES PDF ---


  void _showFilterBottomSheet() {
    // (Função permanece a mesma da sua versão anterior)
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
                                // --- CORREÇÃO: Definir isLoadingPdfItem corretamente ---
                                final bool isLoadingPdfItem = _isGeneratingOrHandlingPdfArquivados && _processingPdfIdArquivados == chamadoId;

                                final Timestamp? adminFinalizouTimestamp = data[kFieldAdminFinalizouData] as Timestamp?;
                                final String dataFinalizacaoKey = adminFinalizouTimestamp?.millisecondsSinceEpoch.toString() ?? data[kFieldDataCriacao]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

                                // --- CORREÇÃO: Passar onGerarPdfOpcoes em vez de onDownloadPdf ---
                                return ChamadoListItem(
                                  key: ValueKey("archived_${chamadoId}_$dataFinalizacaoKey"),
                                  chamadoId: chamadoId,
                                  chamadoData: data,
                                  currentUser: _currentUser,
                                  isAdmin: _isAdmin,
                                  onConfirmar: null,
                                  isLoadingConfirmation: false,
                                  onDelete: null,
                                  onNavigateToDetails: (id) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DetalhesChamadoScreen(chamadoId: id)),
                                    );
                                  },
                                  isLoadingPdfDownload: isLoadingPdfItem, // Passa o estado correto
                                  onGerarPdfOpcoes: _gerarPdfEExibirOpcoesArquivados, // Passa a função correta
                                  // onFinalizarArquivar e isLoadingFinalizarArquivar não são necessários aqui
                                  onFinalizarArquivar: null, // Passa null
                                  isLoadingFinalizarArquivar: false, // Passa false
                                );
                                // --- FIM DA CORREÇÃO ---
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