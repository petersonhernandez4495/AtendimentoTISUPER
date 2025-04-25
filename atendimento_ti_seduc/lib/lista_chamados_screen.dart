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
import 'widgets/ticket_card.dart'; // <<< IMPORTA O NOVO WIDGET

class ListaChamadosScreen extends StatefulWidget {
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  // ... (Variáveis de estado, initState, _excluirChamado, _gerarECompartilharPdfLista,
  //      _buildFirestoreQuery - MANTIDAS IGUAIS) ...
    List<QueryDocumentSnapshot>? _currentDocs;
  String? _selectedStatusFilter;
  String _sortField = 'data_criacao';
  bool _sortDescending = true;
  final List<String> _statusOptions = ['Todos', 'aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': 'data_criacao', 'descending': true},
    {'label': 'Mais Antigos', 'field': 'data_criacao', 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0];
  }

   Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
     bool confirmarExclusao = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Exclusão'), content: const Text( 'Tem certeza que deseja excluir este chamado?\nEsta ação não pode ser desfeita.'), actions: <Widget>[ TextButton( child: const Text('Cancelar'), onPressed: () { Navigator.of(context).pop(false); }, ), TextButton( child: Text('Excluir', style: TextStyle(color: AppTheme.kErrorColor)), onPressed: () { Navigator.of(context).pop(true); }, ), ], ); } ) ?? false;
     if (!confirmarExclusao || !mounted) return;
     try {
       await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Chamado excluído com sucesso!')), ); }
     } catch (error) {
       print('Erro ao excluir chamado: $error');
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao excluir chamado: ${error.toString()}')), ); }
     }
   }

   Future<void> _gerarECompartilharPdfLista() async {
         if (_currentDocs == null || _currentDocs!.isEmpty) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Nenhum chamado na lista atual para gerar PDF.')) );
     return;
   }
   showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()) );
   try {
       final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!);
       final Directory tempDir = await getTemporaryDirectory();
       final String filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
       final File file = File(filePath);
       await file.writeAsBytes(pdfBytes);
       if (!mounted) return;
       Navigator.of(context, rootNavigator: true).pop(); // Fecha o loading
       final result = await Share.shareXFiles( [XFile(filePath)], text: 'Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}' );
       if (result.status == ShareResultStatus.success && mounted) { print("Compartilhamento da lista de chamados iniciado com sucesso.");
       } else if (mounted) { print("Compartilhamento cancelado ou falhou: ${result.status}"); }
   } catch (e) {
       if(mounted) Navigator.of(context, rootNavigator: true).pop();
       print("Erro ao gerar/compartilhar PDF da lista: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao gerar PDF da lista: ${e.toString()}')) );
   }
   }

   Query _buildFirestoreQuery() {
        Query query = FirebaseFirestore.instance.collection('chamados');
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'Todos') {
     query = query.where('status', isEqualTo: _selectedStatusFilter);
    }
    query = query.orderBy(_sortField, descending: _sortDescending);
    if (_sortField != 'data_criacao') { query = query.orderBy('data_criacao', descending: true); }
    return query;
   }

  @override
  Widget build(BuildContext context) {
    // ... (Obtenção de theme, colorScheme, textTheme mantida igual) ...
      final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    // final Color? textoSecundarioCor = textTheme.bodyMedium?.color; // Não precisa mais aqui

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Barra de Filtros e Ordenação (Mantida Igual) ---
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          color: theme.colorScheme.surfaceVariant,
          child: Row( /* ... Conteúdo da barra de filtros ... */
                   children: [
              Expanded( flex: 3, child: DropdownButtonFormField<String>( value: _selectedStatusFilter ?? 'Todos', items: _statusOptions.map((String status) => DropdownMenuItem<String>( value: status, child: Text(status, style: const TextStyle(fontSize: 12)), )).toList(), onChanged: (String? newValue) { setState(() { _selectedStatusFilter = (newValue == 'Todos') ? null : newValue; }); }, style: textTheme.bodySmall, decoration: InputDecoration( filled: true, fillColor: colorScheme.surface, prefixIcon: const Icon(Icons.filter_list, size: 16), contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), isDense: true, ), ), ),
              const SizedBox(width: 10),
              Expanded( flex: 4, child: DropdownButtonFormField<Map<String, dynamic>>( value: _selectedSortOption, items: _sortOptions.map((Map<String, dynamic> option) => DropdownMenuItem<Map<String, dynamic>>( value: option, child: Text(option['label'] as String, overflow: TextOverflow.ellipsis), )).toList(), onChanged: (Map<String, dynamic>? newValue) { if (newValue != null) { setState(() { _selectedSortOption = newValue; _sortField = newValue['field'] as String; _sortDescending = newValue['descending'] as bool; }); } }, style: textTheme.bodySmall, decoration: InputDecoration( filled: true, fillColor: colorScheme.surface, prefixIcon: const Icon(Icons.sort, size: 16), contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), isDense: true, ), isExpanded: true, ), ),
              IconButton( icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: _gerarECompartilharPdfLista, tooltip: 'Gerar PDF da Lista', iconSize: 20, visualDensity: VisualDensity.compact, color: theme.iconTheme.color ),
            ],
           )
        ),
        // --- Lista/Grade de Chamados ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildFirestoreQuery().snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              // ... (Tratamento de erro/loading/lista vazia - MANTIDO IGUAL) ...
                 if (snapshot.hasError) { return Center(child: Text('Erro ao carregar chamados: ${snapshot.error}'));}
                 if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator());}
                 _currentDocs = snapshot.data?.docs;
                  if (_currentDocs == null || _currentDocs!.isEmpty) { /* ... Mensagem lista vazia ... */
                     bool filtroEstaAtivo = (_selectedStatusFilter != null && _selectedStatusFilter != 'Todos');
                     String mensagem = filtroEstaAtivo ? 'Nenhum chamado encontrado com os filtros atuais.' : 'Nenhum chamado registrado no momento.';
                     IconData icone = filtroEstaAtivo ? Icons.filter_alt_off_outlined : Icons.inbox_outlined;
                     return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(icone, size: 50, color: Colors.grey[500]), const SizedBox(height: 16), Text( mensagem, textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(color: Colors.grey[600]), ), ] ), ), );
                 }


              // --- GridView com itemBuilder SIMPLIFICADO ---
              return GridView.builder(
                padding: const EdgeInsets.all(12.0),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200.0,
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
                  childAspectRatio: (1 / 1.5), // Mantido ajuste da altura
                ),
                itemCount: _currentDocs!.length,
                itemBuilder: (BuildContext context, int index) {
                  final DocumentSnapshot document = _currentDocs![index];
                  final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

                  // Extrai os dados
                  final String titulo = data['titulo'] ?? 'S/ Título';
                  final String prioridade = data['prioridade'] ?? 'S/P';
                  final String status = data['status'] ?? 'S/S';
                  final String creatorName = data['creatorName'] ?? 'Anônimo';
                  final Timestamp? dataCriacaoTimestamp = data['data_criacao'] as Timestamp?;
                  final String dataFormatada = dataCriacaoTimestamp != null
                      ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate())
                      : '--';

                  // --- CRIA O WIDGET TicketCard ---
                  // Passa os dados e os callbacks necessários
                  return TicketCard(
                    key: ValueKey(document.id), // Usa ID como chave para otimizações do Flutter
                    chamadoId: document.id,
                    titulo: titulo,
                    prioridade: prioridade,
                    status: status,
                    creatorName: creatorName,
                    dataFormatada: dataFormatada,
                    onTap: () { // Define a ação de clique aqui
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),
                        ),
                      );
                    },
                    onDelete: () { // Define a ação de exclusão aqui
                      _excluirChamado(context, document.id);
                    },
                  );
                  // ---------------------------------

                }, // Fim do itemBuilder
              ); // Fim GridView.builder
            }, // Fim builder StreamBuilder
          ), // Fim StreamBuilder
        ), // Fim Expanded
      ], // Fim Column principal
    ); // Fim Column
  } // Fim build
} // Fim State