// lib/lista_chamados_screen.dart

import 'dart:math';
import 'dart:typed_data'; // ADICIONADO
import 'dart:io';       // ADICIONADO
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // ADICIONADO
import 'package:open_filex/open_filex.dart';     // ADICIONADO
import 'package:printing/printing.dart';         // ADICIONADO
import 'package:pdf/pdf.dart' show PdfPageFormat;
import '../pdf_generator.dart' as pdfGen; // ADICIONADO
import '../detalhes_chamado_screen.dart' show DetalhesChamadoScreen;
import '../config/theme/app_theme.dart';
import '../widgets/chamado_list_item.dart';
import '../services/chamado_service.dart'; // Assumindo que as constantes de campo estão aqui ou são importadas por ele

// Se suas constantes de campo não estiverem acessíveis via chamado_service.dart,
// importe-as ou defina-as aqui para _getSignatureUrlFromFirestore e pdfGen.
// Exemplo:
// const String kFieldSolucaoPorUid = 'solucaoPorUid';
// const String kFieldRequerenteConfirmou = 'requerenteConfirmou';
// const String kFieldRequerenteConfirmouUid = 'requerenteConfirmouUid';
// const String kFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador'; // Usado no PDF

class ListaChamadosScreen extends StatefulWidget {
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  final ChamadoService _chamadoService = ChamadoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<QueryDocumentSnapshot>? _currentDocs;
  String? _selectedStatusFilter;

  final List<String> _statusOptions = [
    'Aberto', 'Em Andamento', 'Pendente', kStatusPadraoSolicionado,
    'Fechado', 'Cancelado', 'Aguardando Aprovação',
    'Aguardando Peça', 'Chamado Duplicado', 'Aguardando Equipamento',
    'Atribuido para GSIOR', 'Garantia Fabricante',
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': kFieldDataCriacao, 'descending': true},
    {'label': 'Mais Antigos', 'field': kFieldDataCriacao, 'descending': false},
    {'label': 'Prioridade', 'field': kFieldPrioridade, 'descending': true},
    {'label': 'Status', 'field': kFieldStatus, 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  User? _currentUser;
  bool _isConfirmingAcceptance = false;
  String? _confirmingChamadoId;

  String? _idChamadoGerandoPdf; // ADICIONADO: Para controlar o loading do PDF por item
  String? _idChamadoFinalizandoDaLista;
  bool _isLoadingFinalizarDaLista = false;

  final String valorStatusSolucionadoParaSort = kStatusPadraoSolicionado;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0];
    _currentUser = _auth.currentUser;
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    // ... (seu código existente)
    if (!mounted || !_isLoadingRole) return;
    bool isAdminResult = false;
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          isAdminResult = (userData['role_temp'] == 'admin');
        }
      } catch (e) {
        print("ListaChamadosScreen: Erro ao verificar role do usuário: $e");
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
    return _selectedStatusFilter != null ||
        _selectedDateFilter != null ||
        _selectedSortOption['field'] != kFieldDataCriacao;
  }

  Query _buildFirestoreQuery() {
    // ... (seu código existente)
    Query query = FirebaseFirestore.instance.collection(kCollectionChamados);

    if (!_isLoadingRole && !_isAdmin) {
      if (_currentUser != null) {
        query = query.where(kFieldCreatorUid, isEqualTo: _currentUser!.uid);
      } else {
        query = query.where('__inexistente__', isEqualTo: '__sem_resultados__');
      }
    } else if (_isLoadingRole) {
      query = query.where('__inexistente__', isEqualTo: '__aguardando_role__');
    }
    query = query.where(kFieldStatus, isNotEqualTo: kStatusFinalizado);
    if (_selectedStatusFilter != null) {
      query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
    }
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59, 999);
      query = query.where(kFieldDataCriacao, isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay), isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }
    final String sortField = _selectedSortOption['field'] as String;
    final bool sortDescending = _selectedSortOption['descending'] as bool;
    query = query.orderBy(sortField, descending: sortDescending);
    if (sortField != kFieldDataCriacao) {
      query = query.orderBy(kFieldDataCriacao, descending: true);
    }
    return query;
  }

  void _applyCustomClientSort(List<QueryDocumentSnapshot> docs) {
    // ... (seu código existente)
    docs.sort((aDoc, bDoc) {
      Map<String, dynamic> aData = aDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> bData = bDoc.data() as Map<String, dynamic>;

      String statusA = aData[kFieldStatus]?.toString().toLowerCase() ?? '';
      String statusB = bData[kFieldStatus]?.toString().toLowerCase() ?? '';
      String solvedForSortLower = valorStatusSolucionadoParaSort.toLowerCase();

      bool aIsSolved = (statusA == solvedForSortLower);
      bool bIsSolved = (statusB == solvedForSortLower);

      int getGroupOrder(bool isSolved) => isSolved ? 1 : 0; 

      int orderA = getGroupOrder(aIsSolved);
      int orderB = getGroupOrder(bIsSolved);

      if (orderA != orderB) return orderA.compareTo(orderB); 

      Timestamp? aTimestamp = aData[kFieldDataCriacao] as Timestamp?;
      Timestamp? bTimestamp = bData[kFieldDataCriacao] as Timestamp?;
      if (aTimestamp != null && bTimestamp != null) return bTimestamp.compareTo(aTimestamp);
      if (bTimestamp != null) return 1;
      if (aTimestamp != null) return -1;
      return 0;
    });
  }

  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    // ... (seu código existente)
    if (!_isAdmin || !mounted) return;
    bool confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Exclusão'),
            content: const Text('Deseja realmente excluir este chamado?\nEsta ação é irreversível.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ?? false;

    if (!confirmar || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Excluindo...')));
    try {
      await FirebaseFirestore.instance.collection(kCollectionChamados).doc(chamadoId).delete();
      if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Excluído!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleRequerenteConfirmar(String chamadoId) async {
    // ... (seu código existente)
    final user = _auth.currentUser;
    if (user == null || !mounted) return;
    setState(() { _isConfirmingAcceptance = true; _confirmingChamadoId = chamadoId; });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _chamadoService.confirmarServicoRequerente(chamadoId, user);
      if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Confirmado!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isConfirmingAcceptance = false; _confirmingChamadoId = null; });
    }
  }

  Future<void> _handleFinalizarArquivarChamado(String chamadoId) async {
    // ... (seu código existente)
     if (!_isAdmin || _currentUser == null || !mounted) return;
    setState(() { _isLoadingFinalizarDaLista = true; _idChamadoFinalizandoDaLista = chamadoId; });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _chamadoService.adminConfirmarSolucaoFinal(chamadoId, _currentUser!);
      if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Arquivado!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoadingFinalizarDaLista = false; _idChamadoFinalizandoDaLista = null; });
    }
  }

  // ============== INÍCIO DA LÓGICA DE PDF ==============

  // Mova esta função para uma classe de utilitário/serviço se for usada em mais lugares.
  Future<String?> _getSignatureUrlFromFirestore(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['assinatura_url'] as String?;
      }
    } catch (e) {
      print("ListaChamadosScreen: Erro ao buscar URL da assinatura para $userId: $e");
    }
    return null;
  }

  Future<void> _handleGerarPdfOpcoes(String chamadoId, Map<String, dynamic> chamadoData) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContext = context; // Salva o contexto para diálogos

    setState(() {
      _idChamadoGerandoPdf = chamadoId;
    });

    // Opcional: Diálogo de progresso global
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
          canPop: false,
          child: const Center(child: CircularProgressIndicator(backgroundColor: Colors.white,))), // Adicionado backgroundColor
    );

    Uint8List? pdfBytes;
    String? adminSigUrl;
    String? requesterSigUrl;

    try {
      // Certifique-se que as constantes kFieldSolucaoPorUid, kFieldRequerenteConfirmou, kFieldRequerenteConfirmouUid
      // estão disponíveis (importadas do chamado_service.dart ou definidas aqui)
      final String? adminSolucionouUid = chamadoData[kFieldSolucaoPorUid] as String?; // Adapte se o nome da constante for diferente
      if (adminSolucionouUid != null && adminSolucionouUid.isNotEmpty) {
        adminSigUrl = await _getSignatureUrlFromFirestore(adminSolucionouUid);
      }

      final bool requerenteConfirmou = chamadoData[kFieldRequerenteConfirmou] as bool? ?? false; // Adapte
      final String? uidDoRequerenteQueConfirmou = chamadoData[kFieldRequerenteConfirmouUid] as String?; // Adapte
      if (requerenteConfirmou && uidDoRequerenteQueConfirmou != null && uidDoRequerenteQueConfirmou.isNotEmpty) {
        requesterSigUrl = await _getSignatureUrlFromFirestore(uidDoRequerenteQueConfirmou);
      }

      pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
        chamadoId: chamadoId,
        dadosChamado: chamadoData,
        adminSignatureUrl: adminSigUrl,
        requesterSignatureUrl: requesterSigUrl,
      );

    } catch (e) {
      if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
        Navigator.of(currentContext, rootNavigator: true).pop(); // Fecha diálogo de progresso
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _idChamadoGerandoPdf = null;
      });
      return;
    }

    if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
       Navigator.of(currentContext, rootNavigator: true).pop(); // Fecha diálogo de progresso
    }
    
    // É importante resetar o estado ANTES de mostrar o próximo diálogo,
    // caso o usuário feche o diálogo de opções sem escolher uma.
    if (mounted) {
      setState(() {
        _idChamadoGerandoPdf = null;
      });
    }

    if (pdfBytes != null && mounted) {
      _mostrarOpcoesPdfDialog(pdfBytes, chamadoId);
    } else if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Falha ao gerar PDF.'), backgroundColor: Colors.orange),
      );
    }
  }

  void _mostrarOpcoesPdfDialog(Uint8List pdfBytes, String chamadoId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Opções do PDF'),
          content: const Text('O que você gostaria de fazer com o PDF do chamado?'),
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
                    _imprimirPdfLista(pdfBytes);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Abrir / Visualizar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _abrirPdfLocalmenteLista(pdfBytes, chamadoId);
                  },
                ),
                 const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _compartilharPdfLista(pdfBytes, chamadoId);
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
  }

  Future<void> _imprimirPdfLista(Uint8List pdfBytes) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao preparar impressão: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirPdfLocalmenteLista(Uint8List pdfBytes, String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContextForDialog = context;

    showDialog(
      context: currentContextForDialog,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator(backgroundColor: Colors.white))), // Adicionado backgroundColor
    );

    try {
      final outputDir = await getTemporaryDirectory();
      final filename = 'chamado_${chamadoId.substring(0, min(6, chamadoId.length))}.pdf';
      final outputFile = File("${outputDir.path}/$filename");
      await outputFile.writeAsBytes(pdfBytes);

      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
        Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }

      final result = await OpenFilex.open(outputFile.path);

      if (result.type != ResultType.done && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o PDF: ${result.message}')),
        );
      }
    } catch (e) {
      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
        Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao abrir PDF localmente: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _compartilharPdfLista(Uint8List pdfBytes, String chamadoId) async {
      if(!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: 'chamado_${chamadoId.substring(0,min(6, chamadoId.length))}.pdf');
      } catch (e) {
        if (mounted) {
            scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Erro ao compartilhar PDF: $e'), backgroundColor: Colors.red),
          );
        }
      }
  }

  // ============== FIM DA LÓGICA DE PDF ==============

  void _showFilterBottomSheet() {
    // ... (seu código existente)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (_, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Filtros e Ordenação', style: theme.textTheme.titleLarge),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatusFilter = null;
                                  _selectedDateFilter = null;
                                  _selectedSortOption = _sortOptions[0];
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Limpar Tudo'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text('Filtrar por Status:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _statusOptions
                              .where((status) => status != kStatusFinalizado)
                              .map((statusValue) {
                                final bool isSelected = _selectedStatusFilter == statusValue;
                                return FilterChip(
                                  label: Text(statusValue),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedStatusFilter = selected ? statusValue : null;
                                    });
                                    sheetSetState(() {});
                                  },
                                  selectedColor: colorScheme.primaryContainer,
                                  checkmarkColor: colorScheme.onPrimaryContainer,
                                  labelStyle: TextStyle(color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant),
                                );
                              }
                            ).toList(),
                        ),
                        const SizedBox(height: 20),
                        Text('Filtrar por Data de Criação:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _selectedDateFilter == null ? 'Selecionar Data do Chamado' : 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDateFilter!)}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDateFilter ?? DateTime.now(),
                                    firstDate: DateTime(DateTime.now().year - 5),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                    helpText: 'SELECIONE A DATA DO CHAMADO',
                                    cancelText: 'CANCELAR',
                                    confirmText: 'OK',
                                    locale: const Locale('pt', 'BR'),
                                  );
                                  if (pickedDate != null) {
                                    setState(() { _selectedDateFilter = pickedDate; });
                                    sheetSetState(() {});
                                  }
                                },
                              ),
                            ),
                            if (_selectedDateFilter != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                tooltip: 'Limpar Filtro de Data',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() { _selectedDateFilter = null; });
                                  sheetSetState(() {});
                                },
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 20),
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
                                  setState(() { _selectedSortOption = option; });
                                  sheetSetState(() {});
                                }
                              },
                              selectedColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              child: const Text('Aplicar Filtros'),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
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
                colors: [
                  AppTheme.kWinBackground,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.7],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          Icons.filter_list_alt,
                          color: _isFilterActive ? colorScheme.primary : AppTheme.kWinSecondaryText,
                          size: 20,
                        ),
                        label: Text('Filtros', style: TextStyle(color: _isFilterActive ? colorScheme.primary : AppTheme.kWinSecondaryText)),
                        onPressed: _showFilterBottomSheet,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
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
                              return Center(
                                  child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Ocorreu um erro: ${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                              ));
                            }
                            if (snapshot.connectionState == ConnectionState.waiting && _currentDocs == null) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasData) {
                              _currentDocs = snapshot.data?.docs;
                              if (_currentDocs != null && _currentDocs!.isNotEmpty) {
                                _applyCustomClientSort(_currentDocs!);
                              }
                            }

                            if (_currentDocs == null || _currentDocs!.isEmpty) {
                              bool filtroAtivoLocal = _selectedStatusFilter != null || _selectedDateFilter != null;
                              String msg = "Nenhum chamado encontrado.";
                              IconData icone = Icons.inbox_outlined;

                              if (filtroAtivoLocal) {
                                msg = 'Nenhum chamado encontrado com os filtros aplicados.';
                                icone = Icons.filter_alt_off_outlined;
                              } else {
                                msg = _isAdmin ? 'Nenhum chamado registrado no sistema.' : 'Você ainda não possui chamados registrados.';
                                icone = _isAdmin ? Icons.inbox_outlined : Icons.assignment_late_outlined;
                              }

                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(icone, size: 50, color: Colors.grey[500]),
                                      const SizedBox(height: 16),
                                      Text(msg, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                                      if (filtroAtivoLocal) ...[
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.clear_all),
                                          label: const Text('Limpar Filtros Aplicados'),
                                          onPressed: () {
                                            setState(() {
                                              _selectedStatusFilter = null;
                                              _selectedDateFilter = null;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(foregroundColor: colorScheme.onSecondaryContainer, backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8)),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 72.0),
                              itemCount: _currentDocs!.length,
                              itemBuilder: (BuildContext context, int index) {
                                final DocumentSnapshot document = _currentDocs![index];
                                final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};
                                final chamadoId = document.id;

                                final bool isLoadingConfirmation = _isConfirmingAcceptance && _confirmingChamadoId == chamadoId;
                                final bool isLoadingPdfItem = _idChamadoGerandoPdf == chamadoId; // ATUALIZADO
                                final bool isLoadingFinalizarItem = _isLoadingFinalizarDaLista && _idChamadoFinalizandoDaLista == chamadoId;
                                final String? dataAtualizacaoKey = data[kFieldDataAtualizacao]?.toString() ?? data[kFieldDataCriacao]?.toString();

                                return ChamadoListItem(
                                  key: ValueKey(chamadoId + (dataAtualizacaoKey ?? DateTime.now().millisecondsSinceEpoch.toString())),
                                  chamadoId: chamadoId,
                                  chamadoData: data,
                                  currentUser: _currentUser,
                                  isAdmin: _isAdmin,
                                  onConfirmar: _handleRequerenteConfirmar,
                                  isLoadingConfirmation: isLoadingConfirmation,
                                  onDelete: _isAdmin ? () => _excluirChamado(context, chamadoId) : null,
                                  onNavigateToDetails: (id) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DetalhesChamadoScreen(chamadoId: id)),
                                    ).then((_) { if (mounted) setState(() {}); });
                                  },
                                  isLoadingPdfDownload: isLoadingPdfItem,         // ATUALIZADO
                                  onGerarPdfOpcoes: _handleGerarPdfOpcoes,      // ATUALIZADO
                                  onFinalizarArquivar: _handleFinalizarArquivarChamado,
                                  isLoadingFinalizarArquivar: isLoadingFinalizarItem,
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