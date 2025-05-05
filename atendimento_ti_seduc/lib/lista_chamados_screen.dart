// lib/lista_chamados_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // Para PDF
import 'dart:typed_data'; // Para PDF
import 'package:path_provider/path_provider.dart'; // Para PDF
import 'package:share_plus/share_plus.dart'; // Para PDF Share

// Importações locais (AJUSTE OS CAMINHOS CONFORME SUA ESTRUTURA)
import 'pdf_generator.dart'; // Verifique se existe ou comente se não usar PDF
import 'detalhes_chamado_screen.dart'; // Import da tela de detalhes
import 'config/theme/app_theme.dart'; // Import do seu tema
import 'widgets/ticket_card.dart'; // Import do card
import 'widgets/horizontal_date_selector.dart'; // Import do seletor de data
// Descomente se a formatação de data pt_BR não estiver globalmente configurada
// import 'package:intl/date_symbol_data_local.dart';

class ListaChamadosScreen extends StatefulWidget {
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  List<QueryDocumentSnapshot>? _currentDocs; // Guarda os documentos atuais para PDF
  String? _selectedStatusFilter; // null representa 'Todos'
  final List<String> _statusOptions = [ // Lista de status para filtro
    'aberto',
    'em andamento',
    'pendente',
    'resolvido',
    'fechado',
    'cancelado',
  ];
  final List<Map<String, dynamic>> _sortOptions = [ // Opções de ordenação
    {'label': 'Mais Recentes', 'field': 'data_criacao', 'descending': true},
    {'label': 'Mais Antigos', 'field': 'data_criacao', 'descending': false},
    {'label': 'Prioridade (Alta > Baixa)', 'field': 'prioridade', 'descending': true},
    {'label': 'Status', 'field': 'status', 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption; // Opção de ordenação selecionada
  DateTime? _selectedDateFilter; // Filtro de data selecionada

  // Estado para controle de Role Admin
  bool _isAdmin = false;
  bool _isLoadingRole = true; // Começa carregando a role
  User? _currentUser; // Guarda o usuário logado

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Inicia com 'Mais Recentes'
    _currentUser = FirebaseAuth.instance.currentUser; // Pega o usuário atual
    _checkUserRole(); // Chama a verificação de role
    // initializeDateFormatting('pt_BR', null); // Descomente se necessário
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- Função para verificar Role Admin (usando role_temp do Firestore) ---
  Future<void> _checkUserRole() async {
    if (!_isLoadingRole && mounted) return; // Evita re-checagem

    bool isAdminResult = false;
    if (_currentUser != null) {
      final userId = _currentUser!.uid;
      print("--- [ListaChamadosScreen] Iniciando Verificação de Role para UID: $userId ---");
      try {
        print("Firestore Check: Tentando ler /users/$userId"); // Ajuste 'users' se sua coleção for outra
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users') // <<< CONFIRME O NOME DA SUA COLEÇÃO DE USUÁRIOS
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          print("Firestore Check: Documento encontrado. Dados: $userData");
          // Verifica se o campo 'role_temp' existe
          if (userData.containsKey('role_temp')) {
             final roleValue = userData['role_temp'];
             print("Firestore Check: Campo 'role_temp' encontrado. Valor: '$roleValue' (Tipo: ${roleValue.runtimeType})");
             // <<< COMPARAÇÃO COM 'admin' >>>
             isAdminResult = (roleValue == 'admin'); // Comparação exata (case-sensitive)
             print("Firestore Check: Comparação (roleValue == 'admin') resultou em: $isAdminResult");
          } else {
             print("Firestore Check: Campo 'role_temp' NÃO encontrado no documento.");
             isAdminResult = false;
          }
        } else {
          print("Firestore Check: Documento /users/$userId NÃO encontrado ou vazio.");
          isAdminResult = false;
        }

      } catch (e, s) {
        print("ListaChamadosScreen: ERRO FATAL ao buscar role do usuário: $e");
        print(s);
        isAdminResult = false; // Assume não-admin em caso de erro
      }
    } else {
      print("ListaChamadosScreen: Nenhum usuário logado para verificar a role.");
      isAdminResult = false;
    }

    // Atualiza o estado APENAS se o widget ainda estiver montado
    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false; // Marca a verificação como concluída
      });
      print("--- [ListaChamadosScreen] Fim Verificação de Role --- _isAdmin definido como: $_isAdmin ---");
    }
  }


  // Verifica se algum filtro está ativo (para feedback visual no botão)
  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
        _selectedDateFilter != null ||
        _selectedSortOption['label'] != _sortOptions[0]['label'];
  }

  // Constrói a query do Firestore com filtros e ordenação
  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('chamados');

    // Aplica filtro de criador APENAS se não for admin (e role já checada)
    if (!_isLoadingRole && !_isAdmin) {
      if (_currentUser != null) {
        query = query.where('creatorUid', isEqualTo: _currentUser!.uid);
        print("Query: Aplicando filtro de requisitante para UID: ${_currentUser!.uid}");
      } else {
        print("Query: Usuário não admin sem UID! Retornando query vazia.");
        query = query.where('__inexistente__', isEqualTo: '__sem_resultados__');
      }
      // Requisitantes NÃO filtram por 'isAdministrativamenteInativo' aqui
    } else if (_isAdmin) {
       print("Query: Admin logado, buscando todos os chamados.");
       // Admin NÃO tem filtro por creatorUid ou inatividade aqui
    } else {
       // Ainda carregando a role, retorna query vazia para evitar erros
       print("Query: Aguardando verificação de role...");
       query = query.where('__inexistente__', isEqualTo: '__aguardando_role__');
    }

    // Aplica outros filtros (Status, Data)
    if (_selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
      print("Query: Aplicando filtro de status: $_selectedStatusFilter");
    }
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59);
      // Garante que o Timestamp do Firestore seja usado para comparação
      query = query.where('data_criacao', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      query = query.where('data_criacao', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      print("Query: Aplicando filtro de data: $_selectedDateFilter");
    }

    // Aplica ordenação
    final String sortField = _selectedSortOption['field'] as String;
    final bool sortDescending = _selectedSortOption['descending'] as bool;
    // Valida os campos de ordenação para evitar erros com tipos mistos se 'prioridade' não for string consistente
    if (sortField == 'prioridade') {
        // A ordenação por prioridade como string pode não ser ideal ('Alta' > 'Baixa' ?).
        // Considere usar um campo numérico para prioridade se precisar de ordenação precisa.
        print("Aviso: Ordenando por prioridade como string. Resultados podem variar.");
    }
    query = query.orderBy(sortField, descending: sortDescending);
    print("Query: Ordenando por '$sortField' ${sortDescending ? 'DESC' : 'ASC'}");

    // Adiciona ordenação secundária pela data de criação se a ordenação principal
    // não for a própria data, para garantir uma ordem consistente.
    if (sortField != 'data_criacao') {
       query = query.orderBy('data_criacao', descending: true); // Mais recentes como secundário
       print("Query: Ordenação secundária por 'data_criacao' DESC");
    }

    return query;
  }

  // Função para excluir chamado (SOMENTE ADMIN)
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
     if (!_isAdmin || !mounted) return;

     bool confirmarExclusao = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         // Código do AlertDialog restaurado
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
               child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
               onPressed: () => Navigator.of(context).pop(true),
             ),
           ],
         );
       },
     ) ?? false; // Retorna false se o diálogo for dispensado

     if (!confirmarExclusao || !mounted) return;

     // Mostra loading temporário
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Excluindo chamado...'), duration: Duration(seconds: 1)),
     );

     try {
       // TODO: Considerar excluir subcoleções (comentários, visitas) ANTES de excluir o documento principal, se elas existirem.
       // Exemplo:
       // WriteBatch batch = FirebaseFirestore.instance.batch();
       // QuerySnapshot commentsSnapshot = await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).collection('comentarios').get();
       // for (DocumentSnapshot doc in commentsSnapshot.docs) { batch.delete(doc.reference); }
       // QuerySnapshot visitasSnapshot = await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).collection('visitas_agendadas').get();
       // for (DocumentSnapshot doc in visitasSnapshot.docs) { batch.delete(doc.reference); }
       // batch.delete(FirebaseFirestore.instance.collection('chamados').doc(chamadoId)); // Adiciona a exclusão do principal
       // await batch.commit(); // Executa todas as exclusões atomicamente

       // Exclusão simples do documento principal:
       await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();

       if (mounted) {
         ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove 'Excluindo...'
         // SnackBar de Sucesso restaurado
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Chamado excluído com sucesso!'), backgroundColor: Colors.green),
         );
       }
     } catch (error) {
       print('Erro ao excluir chamado $chamadoId: $error');
       if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          // SnackBar de Erro restaurado
          ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao excluir chamado: ${error.toString()}'), backgroundColor: Colors.red),
         );
       }
     }
  }

  // Função para gerar e compartilhar PDF da lista atual
  Future<void> _gerarECompartilharPdfLista() async {
      if (_currentDocs == null || _currentDocs!.isEmpty) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('Nenhum chamado na lista atual para gerar PDF.')));
       }
       return;
     }
     if (mounted) {
       showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
     }
     try {
       // Certifique-se que a função generateTicketListPdf existe e está correta
       final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!);
       final Directory tempDir = await getTemporaryDirectory();
       final String filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
       final File file = File(filePath);
       await file.writeAsBytes(pdfBytes);
       if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha o loading

       final result = await Share.shareXFiles(
           [XFile(filePath)],
           text: 'Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'
        );
       if (result.status == ShareResultStatus.success && mounted) { print("Compartilhamento da lista de chamados iniciado com sucesso."); }
       else if (mounted) { print("Compartilhamento cancelado ou falhou: ${result.status}"); }
     } catch (e, s) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha o loading em caso de erro
        print("Erro ao gerar/compartilhar PDF da lista: $e");
        print(s);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Erro ao gerar PDF da lista: ${e.toString()}'), backgroundColor: Colors.red)); }
     }
  }

  // Função para mostrar o BottomSheet de filtros e ordenação
  void _showFilterBottomSheet() {
      showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
       builder: (context) {
         return StatefulBuilder( builder: (BuildContext context, StateSetter sheetSetState) {
           final theme = Theme.of(context);
           final colorScheme = theme.colorScheme;
           return DraggableScrollableSheet(
               expand: false, initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9,
               builder: (_, scrollController) {
                 return SingleChildScrollView(
                   controller: scrollController,
                   padding: const EdgeInsets.all(16.0).copyWith(bottom: 32.0),
                   child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                     children: [
                       Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Filtros e Ordenação', style: theme.textTheme.titleLarge), TextButton( onPressed: () { setState(() { _selectedStatusFilter = null; _selectedDateFilter = null; _selectedSortOption = _sortOptions[0]; }); Navigator.pop(context); }, child: const Text('Limpar Tudo'), ), ], ),
                       const Divider(height: 24),
                       Text('Filtrar por Status:', style: theme.textTheme.titleMedium),
                       const SizedBox(height: 8),
                       Wrap( spacing: 8.0, runSpacing: 4.0,
                         children: _statusOptions.map((status) { final bool isSelected = _selectedStatusFilter == status; return FilterChip( label: Text(status), selected: isSelected, onSelected: (selected) { setState(() { _selectedStatusFilter = selected ? status : null; }); sheetSetState(() {}); }, selectedColor: colorScheme.primaryContainer, checkmarkColor: colorScheme.onPrimaryContainer, labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, ), ); }).toList(),
                       ),
                       const SizedBox(height: 20),
                       Text('Ordenar por:', style: theme.textTheme.titleMedium),
                       const SizedBox(height: 8),
                       Wrap( spacing: 8.0, runSpacing: 4.0,
                         children: _sortOptions.map((option) { final bool isSelected = _selectedSortOption['label'] == option['label']; return ChoiceChip( label: Text(option['label'] as String), selected: isSelected, onSelected: (selected) { if (selected) { setState(() { _selectedSortOption = option; }); sheetSetState(() {}); } }, selectedColor: colorScheme.primaryContainer, labelStyle: TextStyle( color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal ), ); }).toList(),
                       ),
                       const SizedBox(height: 20),
                     ],
                   ),
                 );
               });
         });
       },
     );
  }


  // --- MÉTODO BUILD PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    // Retorna Column diretamente (assumindo que faz parte de outra tela com Scaffold/AppBar)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Barra Superior com Botões de Filtro e PDF ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon( Icons.filter_list, color: _isFilterActive ? colorScheme.primary : colorScheme.onSurfaceVariant, ),
                tooltip: 'Abrir Filtros e Ordenação',
                onPressed: _showFilterBottomSheet,
              ),
              // Só mostra botão PDF se a role foi carregada e talvez se for admin
              if (!_isLoadingRole /* && _isAdmin */) // Descomente && _isAdmin se só admin puder gerar PDF
                 IconButton(
                   icon: const Icon(Icons.picture_as_pdf_outlined),
                   tooltip: 'Gerar PDF da Lista Atual',
                   color: colorScheme.onSurfaceVariant,
                   // Desabilita se a lista estiver vazia
                   onPressed: (_currentDocs == null || _currentDocs!.isEmpty) ? null : _gerarECompartilharPdfLista,
                 ),
            ],
          ),
        ),

        // --- Seletor de Data Horizontal ---
        HorizontalDateSelector(
          initialSelectedDate: _selectedDateFilter,
          onDateSelected: (date) {
            setState(() {
              _selectedDateFilter = (_selectedDateFilter == date) ? null : date;
            });
          },
        ),
        const Divider(height: 1, thickness: 1), // Linha divisória

        // --- Conteúdo principal: Lista ou Loading ---
        Expanded(
          child: _isLoadingRole // Mostra loading ENQUANTO verifica a role
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: _buildFirestoreQuery().snapshots(), // Usa a query com lógica de role corrigida
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    // Tratamento de Erro
                    if (snapshot.hasError) {
                      print("Erro no StreamBuilder ListaChamados: ${snapshot.error}");
                      return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Text( 'Erro ao carregar chamados.\nVerifique sua conexão ou tente novamente mais tarde.\n(${snapshot.error})', textAlign: TextAlign.center), ) );
                    }

                    // Indicador de Carregamento da Query
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Se a role já carregou, mas os dados ainda estão vindo, mostra loading
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Atualiza a lista de documentos atual (para PDF)
                    _currentDocs = snapshot.data?.docs;

                    // Mensagem de Lista Vazia ou Nenhum Resultado com Filtro
                    if (_currentDocs == null || _currentDocs!.isEmpty) {
                      bool filtroAtivo = _isFilterActive;
                      String mensagem = filtroAtivo ? 'Nenhum chamado encontrado com os filtros atuais.' : (_isAdmin ? 'Nenhum chamado registrado no momento.' : 'Você não possui chamados registrados.');
                      IconData icone = filtroAtivo ? Icons.filter_alt_off_outlined : (_isAdmin ? Icons.inbox_outlined : Icons.assignment_late_outlined);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icone, size: 50, color: Colors.grey[500]),
                              const SizedBox(height: 16),
                              Text( mensagem, textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: Colors.grey[600]),),
                              if (filtroAtivo) ...[
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.clear_all), label: const Text('Limpar Filtros'),
                                  onPressed: () { setState(() { _selectedStatusFilter = null; _selectedDateFilter = null; _selectedSortOption = _sortOptions[0]; }); },
                                  style: ElevatedButton.styleFrom( foregroundColor: colorScheme.onSecondaryContainer, backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8) ),
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
                        maxCrossAxisExtent: 300.0,
                        mainAxisSpacing: 8.0,
                        crossAxisSpacing: 8.0,
                        childAspectRatio: (2 / 2.2), // Ajuste conforme necessário
                      ),
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
                          cidade: cidade,
                          instituicao: instituicao,
                          tipoSolicitante: tipoSolicitante,
                          setorSuperintendencia: setorSuperintendencia,
                          cidadeSuperintendencia: cidadeSuperintendencia,
                          chamadoData: data, // Passa o mapa completo
                          currentUser: _currentUser, // Passa o usuário atual
                          isAdmin: _isAdmin, // Passa a flag de admin
                          // O onTap é tratado dentro do TicketCard
                          onDelete: _isAdmin ? () => _excluirChamado(context, document.id) : null, // Excluir só para admin
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