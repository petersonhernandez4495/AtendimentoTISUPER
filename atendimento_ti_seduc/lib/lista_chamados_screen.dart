import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <<< Certifique-se que está importado
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
    // Adicione outras opções de ordenação aqui (ex: por prioridade, status)
    // Lembre-se que ordenações diferentes podem exigir índices compostos no Firestore.
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;

  // Estado para controle de Role Admin
  bool _isAdmin = false;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Inicia com 'Mais Recentes'
    _checkUserRole(); // Chama a verificação de role
    // initializeDateFormatting('pt_BR', null); // Descomente se necessário
  }

  // Função para verificar Role Admin
  Future<void> _checkUserRole() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    bool isAdminResult = false;

    if (currentUser != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        } else {
          print("ListaChamados: Documento do usuário ${currentUser.uid} não encontrado.");
        }
      } catch (e) {
        print("ListaChamados: Erro ao buscar role do usuário: $e");
      }
    } else {
      print("ListaChamados: Nenhum usuário logado para verificar a role.");
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false; // Marca a verificação como concluída
      });
    }
  }


  // Verifica se algum filtro está ativo
  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
           _selectedDateFilter != null ||
           _selectedSortOption['label'] != _sortOptions[0]['label'];
  }

  // Constrói a query do Firestore com filtro de role
  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('chamados');
    final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    // --- LÓGICA DE FILTRO POR ROLE ---
    if (!_isLoadingRole && !_isAdmin) {
      if (currentUserUid != null) {
        query = query.where('creatorUid', isEqualTo: currentUserUid);
        print("Aplicando filtro de requester para UID: $currentUserUid");
      } else {
        print("AVISO: Usuário não admin sem UID na construção da query!");
        query = query.where('__inexistente__', isEqualTo: '__sem_resultados__');
      }
    }
    // --- FIM DA LÓGICA DE FILTRO POR ROLE ---

    // --- APLICA OUTROS FILTROS (Status, Data) ---
    if (_selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59);
      query = query.where('data_criacao', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      query = query.where('data_criacao', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      // Lembrete ÍNDICES!
    }

    // --- APLICA ORDENAÇÃO ---
    query = query.orderBy(_sortField, descending: _sortDescending);
    // Ordenação secundária
    if (_sortField != 'data_criacao' && _sortField != 'creatorUid') {
       query = query.orderBy('data_criacao', descending: true);
    } else if (_sortField == 'creatorUid' && _sortField != 'data_criacao') {
       query = query.orderBy('data_criacao', descending: true);
    }

    return query;
  }


  // Função para excluir chamado
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    bool confirmarExclusao = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Exclusão'), content: const Text( 'Tem certeza que deseja excluir este chamado?\nEsta ação não pode ser desfeita.', ), actions: <Widget>[ TextButton( child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(false), ), TextButton( child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(context).pop(true), ), ], ); }, ) ?? false; if (!confirmarExclusao || !mounted) return; try { await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete(); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Chamado excluído com sucesso!'), duration: Duration(seconds: 2)), ); } } catch (error) { print('Erro ao excluir chamado $chamadoId: $error'); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao excluir chamado: ${error.toString()}')), ); } }
  }

  // Função para gerar e compartilhar PDF
  Future<void> _gerarECompartilharPdfLista() async {
     if (_currentDocs == null || _currentDocs!.isEmpty) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar( content: Text('Nenhum chamado na lista atual para gerar PDF.'))); } return; } if (mounted) { showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator())); } try { final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!); final Directory tempDir = await getTemporaryDirectory(); final String filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'; final File file = File(filePath); await file.writeAsBytes(pdfBytes); if (mounted) Navigator.of(context, rootNavigator: true).pop(); final result = await Share.shareXFiles( [XFile(filePath)], text: 'Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'); if (result.status == ShareResultStatus.success && mounted) { print("Compartilhamento da lista de chamados iniciado com sucesso."); } else if (mounted) { print("Compartilhamento cancelado ou falhou: ${result.status}"); } } catch (e) { if (mounted) Navigator.of(context, rootNavigator: true).pop(); print("Erro ao gerar/compartilhar PDF da lista: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Erro ao gerar PDF da lista: ${e.toString()}'))); } }
  }

  // Função para mostrar o BottomSheet de filtros
  void _showFilterBottomSheet() {
    showModalBottomSheet( context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))), builder: (context) { return StatefulBuilder( builder: (BuildContext context, StateSetter sheetSetState) { final theme = Theme.of(context); final colorScheme = theme.colorScheme; return DraggableScrollableSheet( expand: false, initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, builder: (_, scrollController) { return SingleChildScrollView( controller: scrollController, padding: const EdgeInsets.all(16.0).copyWith(bottom: 32.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Filtros e Ordenação', style: theme.textTheme.titleLarge), TextButton( onPressed: () { setState(() { _selectedStatusFilter = null; _selectedSortOption = _sortOptions[0]; _sortField = _selectedSortOption['field']; _sortDescending = _selectedSortOption['descending']; }); sheetSetState(() {}); }, child: const Text('Limpar'), ), ], ), const Divider(height: 24), Text('Filtrar por Status:', style: theme.textTheme.titleMedium), const SizedBox(height: 8), Wrap( spacing: 8.0, runSpacing: 4.0, children: _statusOptions.map((status) { final bool isSelected = _selectedStatusFilter == status; return FilterChip( label: Text(status), selected: isSelected, onSelected: (selected) { setState(() { _selectedStatusFilter = selected ? status : null; }); sheetSetState(() {}); }, selectedColor: colorScheme.primaryContainer, checkmarkColor: colorScheme.onPrimaryContainer, labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant ), ); }).toList(), ), const SizedBox(height: 20), Text('Ordenar por:', style: theme.textTheme.titleMedium), const SizedBox(height: 8), Wrap( spacing: 8.0, runSpacing: 4.0, children: _sortOptions.map((option) { final bool isSelected = _selectedSortOption['label'] == option['label']; return ChoiceChip( label: Text(option['label'] as String), selected: isSelected, onSelected: (selected) { if (selected) { setState(() { _selectedSortOption = option; _sortField = option['field'] as String; _sortDescending = option['descending'] as bool; }); sheetSetState(() {}); } }, selectedColor: colorScheme.primaryContainer, labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal ), ); }).toList(), ), const SizedBox(height: 20), ], ), ); } ); }, ); }, );
  }


  // --- MÉTODO BUILD PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botões de Filtro e PDF
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon( Icons.filter_list, color: _isFilterActive ? colorScheme.primary : colorScheme.onSurfaceVariant,),
                tooltip: 'Abrir Filtros',
                onPressed: _showFilterBottomSheet,
              ),
              // Se precisar restringir PDF a admin, adicione a condição aqui:
              // if(!_isLoadingRole && _isAdmin)
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
            setState(() { _selectedDateFilter = (_selectedDateFilter == date) ? null : date; });
          },
        ),
        const Divider(height: 1, thickness: 1),

        // Conteúdo principal: A lista de chamados
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildFirestoreQuery().snapshots(), // Usa a query MODIFICADA
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasError) {
                 print("Erro no StreamBuilder ListaChamados: ${snapshot.error}");
                 // Mostrar um erro mais amigável
                 return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Erro ao carregar chamados.\nVerifique sua conexão ou tente novamente mais tarde.\n(${snapshot.error})', textAlign: TextAlign.center),
                    )
                 );
              }
              // Espera a role carregar ANTES de tentar exibir a lista
              if (snapshot.connectionState == ConnectionState.waiting || _isLoadingRole) {
                return const Center(child: CircularProgressIndicator());
              }

              _currentDocs = snapshot.data?.docs;

              if (_currentDocs == null || _currentDocs!.isEmpty) {
                  bool filtroAtivo = _isFilterActive; String mensagem = filtroAtivo ? 'Nenhum chamado encontrado com os filtros atuais.' : 'Nenhum chamado registrado no momento.'; IconData icone = filtroAtivo ? Icons.filter_alt_off_outlined : Icons.inbox_outlined; return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icone, size: 50, color: Colors.grey[500]), const SizedBox(height: 16), Text( mensagem, textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: Colors.grey[600]),), if (filtroAtivo) ...[ const SizedBox(height: 20), ElevatedButton.icon( icon: const Icon(Icons.clear_all), label: const Text('Limpar Filtros'), onPressed: () { setState(() { _selectedStatusFilter = null; _selectedDateFilter = null; _selectedSortOption = _sortOptions[0]; _sortField = _selectedSortOption['field']; _sortDescending = _selectedSortOption['descending']; }); }, style: ElevatedButton.styleFrom( foregroundColor: colorScheme.onSecondaryContainer, backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8) ), ) ] ], ), ), );
               }

              // --- Construção da Grade de Chamados ---
              return GridView.builder(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 12.0, bottom: 16.0),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent( maxCrossAxisExtent: 300.0, mainAxisSpacing: 8.0, crossAxisSpacing: 8.0, childAspectRatio: (2 / 2.1),),
                  itemCount: _currentDocs!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final DocumentSnapshot document = _currentDocs![index];
                    final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};

                    // Extração segura de dados
                      final String titulo = data['problema_ocorre'] as String? ?? data['titulo'] as String? ?? 'Problema não descrito';
                      final String prioridade = data['prioridade'] as String? ?? 'Normal';
                      final String status = data['status'] as String? ?? 'aberto';
                      final String creatorName = data['creatorName'] as String? ?? data['nome_solicitante'] as String? ?? 'Anônimo';
                      final String? creatorPhone = data['celular_contato'] as String? ?? data['creatorPhone'] as String?;
                      final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?;
                      final Timestamp? dataCriacaoTimestamp = data['data_criacao'] as Timestamp?;
                      final String dataFormatada = dataCriacaoTimestamp != null ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate()) : '--';
                      final String cidade = data['cidade'] as String? ?? '';
                      final String instituicao = data['instituicao'] as String? ?? '';
                      final String? tipoSolicitante = data['tipo_solicitante'] as String?;
                      final String? setorSuperintendencia = data['setor_superintendencia'] as String?;
                      final String? cidadeSuperintendencia = data['cidade_superintendencia'] as String?;

                    // Cria e retorna o widget TicketCard para cada chamado
                    return TicketCard(
                      key: ValueKey(document.id), // Chave única
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
                      onTap: () { Navigator.push( context, MaterialPageRoute( builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),),); },
                      // Passa a função de exclusão SOMENTE se for Admin
                      onDelete: _isAdmin ? () => _excluirChamado(context, document.id) : null,
                    );
                  },
                );
            },
          ),
        ),
      ],
    );
  }

  // --- Método dispose ---
  @override
  void dispose() {
    super.dispose();
  }
}