import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_generator.dart' as pdfGen;
import 'detalhes_chamado_screen.dart';
import 'config/theme/app_theme.dart';
import 'widgets/ticket_card.dart';
import 'widgets/horizontal_date_selector.dart';
import 'services/chamado_service.dart';

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
  final List<String> _statusOptions = kListaStatusChamado;
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': kFieldDataCriacao, 'descending': true},
    {'label': 'Mais Antigos', 'field': kFieldDataCriacao, 'descending': false},
    {'label': 'Prioridade (Alta > Baixa)', 'field': kFieldPrioridade, 'descending': true},
    {'label': 'Status', 'field': kFieldStatus, 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  User? _currentUser;
  bool _isConfirmingAcceptance = false;
  String? _confirmingChamadoId;
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
    if (!mounted) return; if (!_isLoadingRole) return;
    bool isAdminResult = false;
    if (_currentUser != null) {
      final userId = _currentUser!.uid;
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp')) { isAdminResult = (userData['role_temp'] == 'admin'); }
        }
      } catch (e, s) { print("Erro buscar role ListaChamados: $e\n$s"); isAdminResult = false; }
    } else { isAdminResult = false; }
    if (mounted) { setState(() { _isAdmin = isAdminResult; _isLoadingRole = false; }); }
  }

  bool get _isFilterActive { return _selectedStatusFilter != null || _selectedDateFilter != null || _selectedSortOption['label'] != _sortOptions[0]['label']; }

  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection(kCollectionChamados);
    if (!_isLoadingRole && !_isAdmin) { if (_currentUser != null) { query = query.where(kFieldCreatorUid, isEqualTo: _currentUser!.uid); } else { query = query.where('__inexistente__', isEqualTo: '__sem_resultados__'); } } else if (_isLoadingRole) { query = query.where('__inexistente__', isEqualTo: '__aguardando_role__'); } if (_selectedStatusFilter != null) { query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter); } if (_selectedDateFilter != null) { final DateTime start = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0); final DateTime end = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59); query = query.where(kFieldDataCriacao, isGreaterThanOrEqualTo: Timestamp.fromDate(start)); query = query.where(kFieldDataCriacao, isLessThanOrEqualTo: Timestamp.fromDate(end)); } final String sortField = _selectedSortOption['field'] as String; final bool sortDescending = _selectedSortOption['descending'] as bool; if (sortField == kFieldPrioridade) { print("Aviso: Ordenando por prioridade (string)."); } query = query.orderBy(sortField, descending: sortDescending); if (sortField != kFieldDataCriacao) { query = query.orderBy(kFieldDataCriacao, descending: true); } return query;
  }

  Future<void> _excluirChamado(BuildContext context, String chamadoId) async { if (!_isAdmin || !mounted) return; bool confirmar = await showDialog<bool>( context: context, builder: (ctx) => AlertDialog( title: const Text('Confirmar Exclusão'), content: const Text('Deseja excluir?\nAção irreversível.'), actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error))), ], ), ) ?? false; if (!confirmar || !mounted) return; final scaffoldMessenger = ScaffoldMessenger.of(context); scaffoldMessenger.showSnackBar( const SnackBar(content: Text('Excluindo...'), duration: Duration(seconds: 1)), ); try { await FirebaseFirestore.instance.collection(kCollectionChamados).doc(chamadoId).delete(); if (mounted) { scaffoldMessenger.removeCurrentSnackBar(); scaffoldMessenger.showSnackBar( const SnackBar(content: Text('Chamado excluído!'), backgroundColor: Colors.green), ); } } catch (e) { if (mounted) { scaffoldMessenger.removeCurrentSnackBar(); scaffoldMessenger.showSnackBar( SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red), ); } } }

  Future<void> _handleRequerenteConfirmar(String chamadoId) async { final user = _currentUser; if (user == null || !mounted) return; setState(() { _isConfirmingAcceptance = true; _confirmingChamadoId = chamadoId; }); final scaffoldMessenger = ScaffoldMessenger.of(context); try { await _chamadoService.confirmarServicoRequerente(chamadoId, user); if(mounted) { scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Confirmação registrada!'), backgroundColor: Colors.green)); } } catch (e) { if(mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)); } } finally { if(mounted) { setState(() { _isConfirmingAcceptance = false; _confirmingChamadoId = null; }); } } }

  Future<void> _gerarECompartilharPdfLista() async { if (_currentDocs == null || _currentDocs!.isEmpty) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar( content: Text('Nenhum chamado para gerar PDF.'))); } return; } if (mounted) { showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator())); } try { final Uint8List pdfBytes = await pdfGen.generateTicketListPdf(_currentDocs!); final Directory tempDir = await getTemporaryDirectory(); final String filePath = '${tempDir.path}/lista_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'; final File file = File(filePath); await file.writeAsBytes(pdfBytes); if (mounted) Navigator.of(context, rootNavigator: true).pop(); final result = await Share.shareXFiles( [XFile(filePath)], text: 'Lista Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}' ); if (mounted) print("Share status: ${result.status}"); } catch (e, s) { if (mounted) Navigator.of(context, rootNavigator: true).pop(); print("Erro PDF Lista: $e\n$s"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Erro PDF: ${e.toString()}'), backgroundColor: Colors.red)); } } }

  Future<void> _handleDownloadPdf(String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Map<String, dynamic>? docData;
    QueryDocumentSnapshot? foundDoc;
    if (_currentDocs != null) {
      for (final doc in _currentDocs!) {
        if (doc.id == chamadoId) {
          foundDoc = doc; break;
        }
      }
    }
    if (foundDoc != null) {
       try { docData = foundDoc.data() as Map<String, dynamic>?; } catch (e) { print("Erro converter dados doc $chamadoId: $e"); docData = null; }
    }

    if (docData == null) { scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Erro: Dados não encontrados para PDF.'), backgroundColor: Colors.orange)); return; }

    setState(() { _isDownloadingPdf = true; _downloadingPdfId = chamadoId; });
    try {
      final result = await pdfGen.generateAndOpenPdfForTicket( context: context, chamadoId: chamadoId, dadosChamado: docData, );
      if (mounted && result != pdfGen.PdfOpenResult.success) { print("Falha ao abrir PDF $chamadoId ($result)"); }
    } catch (e) { print("Erro inesperado gerar/abrir PDF $chamadoId: $e"); if(mounted) { scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro PDF: $e'), backgroundColor: Colors.red)); }
    } finally { if(mounted) { setState(() { _isDownloadingPdf = false; _downloadingPdfId = null; }); } }
  }

  void _showFilterBottomSheet() { showModalBottomSheet( context: context, isScrollControlled: true, shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))), builder: (context) { return StatefulBuilder( builder: (BuildContext context, StateSetter sheetSetState) { final theme = Theme.of(context); final colorScheme = theme.colorScheme; return DraggableScrollableSheet( expand: false, initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, builder: (_, scrollController) { return SingleChildScrollView( controller: scrollController, padding: const EdgeInsets.all(16.0).copyWith(bottom: 32.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Filtros e Ordenação', style: theme.textTheme.titleLarge), TextButton( onPressed: () { setState(() { _selectedStatusFilter = null; _selectedDateFilter = null; _selectedSortOption = _sortOptions[0]; }); Navigator.pop(context); }, child: const Text('Limpar Tudo'), ), ], ), const Divider(height: 24), Text('Filtrar por Status:', style: theme.textTheme.titleMedium), const SizedBox(height: 8), Wrap( spacing: 8.0, runSpacing: 4.0, children: _statusOptions.map((status) { final bool isSelected = _selectedStatusFilter == status; return FilterChip( label: Text(status), selected: isSelected, onSelected: (selected) { setState(() { _selectedStatusFilter = selected ? status : null; }); sheetSetState(() {}); }, selectedColor: colorScheme.primaryContainer, checkmarkColor: colorScheme.onPrimaryContainer, labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, ), ); }).toList(), ), const SizedBox(height: 20), Text('Ordenar por:', style: theme.textTheme.titleMedium), const SizedBox(height: 8), Wrap( spacing: 8.0, runSpacing: 4.0, children: _sortOptions.map((option) { final bool isSelected = _selectedSortOption['label'] == option['label']; return ChoiceChip( label: Text(option['label'] as String), selected: isSelected, onSelected: (selected) { if (selected) { setState(() { _selectedSortOption = option; }); sheetSetState(() {}); } }, selectedColor: colorScheme.primaryContainer, labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal ), ); }).toList(), ), const SizedBox(height: 20), ], ), ); }); }); }, ); }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); final ColorScheme colorScheme = theme.colorScheme;
    return Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding( padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ IconButton( icon: Icon( Icons.filter_list, color: _isFilterActive ? colorScheme.primary : colorScheme.onSurfaceVariant, ), tooltip: 'Filtros e Ordenação', onPressed: _showFilterBottomSheet, ), if (!_isLoadingRole && _isAdmin) IconButton( icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Gerar PDF da Lista', color: colorScheme.onSurfaceVariant, onPressed: (_currentDocs == null || _currentDocs!.isEmpty) ? null : _gerarECompartilharPdfLista, ), ], ), ),
        HorizontalDateSelector( initialSelectedDate: _selectedDateFilter, onDateSelected: (date) { setState(() { _selectedDateFilter = (_selectedDateFilter == date) ? null : date; }); }, ),
        const Divider(height: 1, thickness: 1),
        Expanded( child: _isLoadingRole ? const Center(child: CircularProgressIndicator()) : StreamBuilder<QuerySnapshot>( stream: _buildFirestoreQuery().snapshots(), builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) { if (snapshot.hasError) { return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Text( 'Erro: ${snapshot.error}', textAlign: TextAlign.center), ) ); } if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } _currentDocs = snapshot.data?.docs; if (_currentDocs == null || _currentDocs!.isEmpty) { bool filtroAtivo = _isFilterActive; String msg = filtroAtivo ? 'Nenhum chamado com filtros.' : (_isAdmin ? 'Nenhum chamado registrado.' : 'Você não possui chamados.'); IconData icone = filtroAtivo ? Icons.filter_alt_off_outlined : (_isAdmin ? Icons.inbox_outlined : Icons.assignment_late_outlined); return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icone, size: 50, color: Colors.grey[500]), const SizedBox(height: 16), Text( msg, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),), if (filtroAtivo) ...[ const SizedBox(height: 20), ElevatedButton.icon( icon: const Icon(Icons.clear_all), label: const Text('Limpar Filtros'), onPressed: () { setState(() { _selectedStatusFilter = null; _selectedDateFilter = null; _selectedSortOption = _sortOptions[0]; }); }, style: ElevatedButton.styleFrom( foregroundColor: colorScheme.onSecondaryContainer, backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8) ), ) ] ], ), ), ); }
                  return GridView.builder( padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 12.0, bottom: 16.0), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent( maxCrossAxisExtent: 300.0, mainAxisSpacing: 8.0, crossAxisSpacing: 8.0, childAspectRatio: (2 / 2.5), ), itemCount: _currentDocs!.length, itemBuilder: (BuildContext context, int index) { final DocumentSnapshot document = _currentDocs![index]; final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {}; final chamadoId = document.id; final bool isLoadingConfirmation = _isConfirmingAcceptance && _confirmingChamadoId == chamadoId; final bool isLoadingPdf = _isDownloadingPdf && _downloadingPdfId == chamadoId;
                      return TicketCard( key: ValueKey(chamadoId + (data[kFieldDataAtualizacao]?.toString() ?? '')), chamadoId: chamadoId, chamadoData: data, currentUser: _currentUser, isAdmin: _isAdmin, onConfirmar: _handleRequerenteConfirmar, isLoadingConfirmation: isLoadingConfirmation, onDelete: _isAdmin ? () => _excluirChamado(context, chamadoId) : null, onNavigateToDetails: (id) { Navigator.push( context, MaterialPageRoute( builder: (_) => DetalhesChamadoScreen(chamadoId: id) ) ); }, onDownloadPdf: _handleDownloadPdf, isLoadingPdfDownload: isLoadingPdf, ); }, ); }, ), ), ], );
  }
}