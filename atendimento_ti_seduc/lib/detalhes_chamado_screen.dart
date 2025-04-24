// lib/detalhes_chamado_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar para pegar usuário logado
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'pdf_generator.dart'; // Para generateTicketPdf e generateAndSharePdfForTicket

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  // --- Controllers e Listas ---
  final List<String> _listaStatus = ['aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];
  final TextEditingController _comentarioController = TextEditingController();
  bool _isSendingComment = false; // Para feedback no botão
  // ---------------------------

  @override
  void dispose() {
    _comentarioController.dispose(); // Limpa o controller do comentário
    super.dispose();
  }

  // --- Função para mostrar diálogo de edição de Status/Prioridade ---
  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
    String statusSelecionado = dadosAtuais['status'] ?? 'aberto';
    String prioridadeSelecionada = dadosAtuais['prioridade'] ?? 'Baixa';
    String? tecnicoResponsavel = dadosAtuais['tecnico_responsavel'] as String? ?? ''; // Adicionado
    final tecnicoController = TextEditingController(text: tecnicoResponsavel); // Controller para técnico

    // Garante que o valor inicial exista nas listas
    if (!_listaStatus.contains(statusSelecionado)) statusSelecionado = _listaStatus[0];
    if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades[0];


    bool? confirmou = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // Usar StatefulBuilder para permitir atualização dentro do diálogo
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Chamado'),
              content: SingleChildScrollView( // Para evitar overflow se adicionar mais campos
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Para ocupar o mínimo de espaço vertical
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: statusSelecionado,
                      items: _listaStatus.map((String value) {
                        return DropdownMenuItem<String>( value: value, child: Text(value), );
                      }).toList(),
                      onChanged: (newValue) {
                         if(newValue != null) {
                           setStateDialog(() { statusSelecionado = newValue; }); // Atualiza estado do diálogo
                         }
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: prioridadeSelecionada,
                      items: _listaPrioridades.map((String value) {
                        return DropdownMenuItem<String>( value: value, child: Text(value), );
                      }).toList(),
                       onChanged: (newValue) {
                         if(newValue != null) {
                            setStateDialog(() { prioridadeSelecionada = newValue; });
                         }
                      },
                      decoration: const InputDecoration(labelText: 'Prioridade'),
                    ),
                     const SizedBox(height: 15), // Adicionado
                     TextFormField( // Adicionado
                       controller: tecnicoController, // Adicionado
                       decoration: const InputDecoration(labelText: 'Técnico Responsável (Opcional)'), // Adicionado
                     ), // Adicionado
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton( child: const Text('Cancelar'), onPressed: () { Navigator.of(context).pop(false); }, ),
                TextButton( child: const Text('Salvar'), onPressed: () {
                    // Atualiza o valor da variável local ANTES de fechar
                    tecnicoResponsavel = tecnicoController.text.trim();
                    Navigator.of(context).pop(true);
                 },
                ),
              ],
            );
          }
        );
      },
    );

     // Se o usuário confirmou as alterações
     if (confirmou == true) {
        try {
           await FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).update({
             'status': statusSelecionado,
             'prioridade': prioridadeSelecionada,
             'tecnico_responsavel': tecnicoResponsavel!.isEmpty ? null : tecnicoResponsavel, // Salva nulo se vazio
             'data_atualizacao': FieldValue.serverTimestamp(), // Atualiza data
           });
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chamado atualizado com sucesso!')));
         } catch (e) {
            print("Erro ao atualizar chamado: $e");
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar chamado.')));
        }
     }
      // Limpar o controller do técnico após sair do diálogo
      tecnicoController.dispose();
  }
  // --------------------------------------------------------------

  // --- Funções de Geração e Compartilhamento/Download de PDF ---
  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async {
    // Mostra loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // Chama a função externa do pdf_generator.dart para gerar e compartilhar
      final result = await generateAndSharePdfForTicket(
        context: context, // Passa o contexto
        chamadoId: widget.chamadoId,
        dadosChamado: currentData
      );

      // Feedback com base no resultado
      if (result == PdfShareResult.success && mounted) {
         print("Compartilhamento iniciado.");
         // Não precisa de SnackBar aqui, pois o Share já mostra a UI nativa
      } else if (result == PdfShareResult.error && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar/compartilhar PDF.'), backgroundColor: Colors.red));
      }
    } finally {
       // Garante que o loading seja fechado mesmo se generateAndSharePdfForTicket já o fez
       try { if(mounted) Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
    }
  }

  Future<void> _baixarPdf(Map<String, dynamic> dadosChamado) async {
      showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      String? savedFilePath;

      try {
        // 1. Gera PDF (usando a função de UM chamado)
        final Uint8List pdfBytes = await generateTicketPdf(dadosChamado);
        // 2. Define caminho e nome do arquivo
        final Directory? downloadsDir = await getDownloadsDirectory(); // Tenta pegar Downloads
        final Directory dir = downloadsDir ?? await getApplicationDocumentsDirectory(); // Fallback para docs do app
        final String fileName = 'chamado_${widget.chamadoId}_${DateFormat('yyyyMMddHHmm').format(DateTime.now())}.pdf';
        final String filePath = '${dir.path}/$fileName';
        savedFilePath = filePath;
        print("Salvando PDF em: $filePath");
        // 3. Escreve o arquivo
        final file = File(filePath); await file.writeAsBytes(pdfBytes);

        if(!mounted) return; Navigator.of(context, rootNavigator: true).pop(); // Fecha loading

        // 4. Mostra confirmação com opção de abrir
        ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text('PDF salvo em ${downloadsDir != null ? "Downloads" : "Documentos do App"}! ($fileName)'), duration: const Duration(seconds: 6), action: SnackBarAction( label: 'ABRIR', onPressed: () { OpenFilex.open(filePath); }, ), ), );
      } catch (e) {
         if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
         print("Erro ao baixar PDF: $e");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao baixar PDF: $e'), backgroundColor: Colors.red));
      }
  }
  // -----------------------------------------

  // --- Função para Adicionar Comentário ---
  Future<void> _adicionarComentario() async {
    final user = FirebaseAuth.instance.currentUser;
    final textoComentario = _comentarioController.text.trim();

    if (user == null) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Usuário não autenticado.')));
      return;
    }
    if (textoComentario.isEmpty) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um comentário.')));
      return;
    }

    setState(() { _isSendingComment = true; }); // Ativa loading no botão

    final novoComentario = {
      'texto': textoComentario,
      'autorNome': user.displayName?.isNotEmpty ?? false ? user.displayName! : "Usuário Desconhecido",
      'autorUid': user.uid,
      'timestamp': FieldValue.serverTimestamp(), // Usa timestamp do servidor
    };

    try {
      await FirebaseFirestore.instance
          .collection('chamados')
          .doc(widget.chamadoId)
          .collection('comentarios')
          .add(novoComentario);
      _comentarioController.clear();
       if(mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      print("Erro ao adicionar comentário: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar comentário.')));
    } finally {
       if(mounted) setState(() { _isSendingComment = false; }); // Desativa loading
    }
  }
  // --------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Chamado'),
        actions: [
          // StreamBuilder para habilitar/desabilitar botões com base nos dados
           StreamBuilder<DocumentSnapshot>(
             stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
             builder: (context, snapshot) {
               if (snapshot.hasData && snapshot.data!.exists) {
                 final currentData = snapshot.data!.data()! as Map<String, dynamic>;
                 return Row( // Agrupa os botões
                   mainAxisSize: MainAxisSize.min, // Para ocupar o mínimo de espaço
                   children: [
                     IconButton( icon: const Icon(Icons.edit_note), tooltip: 'Editar', onPressed: () => _mostrarDialogoEdicao(currentData), ),
                     IconButton( icon: const Icon(Icons.share), tooltip: 'Compartilhar PDF', onPressed: () => _handlePdfShare(currentData), ),
                     IconButton( icon: const Icon(Icons.download), tooltip: 'Baixar PDF', onPressed: () => _baixarPdf(currentData), ),
                   ],
                 );
               }
               // Se não há dados, não mostra os botões (ou mostra desabilitados)
               return const SizedBox.shrink(); // Ou Row com botões desabilitados
             }
           )
        ],
      ),
      body: Column( // Usa Column para empilhar Detalhes + Comentários + Input
        children: [
          Expanded( // O conteúdo principal (Detalhes + Comentários) ocupa o espaço disponível
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
              builder: (context, snapshotChamado) {
                if (snapshotChamado.hasError) { return Center(child: Text('Erro: ${snapshotChamado.error}')); }
                if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado')); }

                final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>;
                // Extração dos dados do chamado
                 final String titulo = data['titulo'] ?? 'N/I';
                 final String descricao = data['descricao'] ?? 'N/I';
                 final String status = data['status'] ?? 'N/I';
                 final String prioridade = data['prioridade'] ?? 'N/I';
                 final String categoria = data['categoria'] ?? 'N/I';
                 final String departamento = data['departamento'] ?? 'N/I';
                 final String equipamento = data['equipamento'] ?? 'N/I';
                 final String criadorNome = data['creatorName'] ?? 'N/I';
                 final String criadorPhone = data['creatorPhone'] ?? 'N/I'; // Telefone já salvo
                 final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?; // Técnico
                 final Timestamp? tsCriacao = data['data_criacao'] as Timestamp?;
                 final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
                 final Timestamp? tsUpdate = data['data_atualizacao'] as Timestamp?;
                 final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';

                return ListView( // Permite scroll para todo o conteúdo
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0), // Padding geral, sem embaixo para colar no input
                  children: <Widget>[
                    // Exibição dos detalhes
                    _buildDetailItem(context, 'Título', titulo),
                    _buildDetailItem(context, 'Descrição', descricao, isMultiline: true),
                    const Divider(height: 20, thickness: 0.5),
                     Row( children: [ Expanded(child: _buildDetailItem(context, 'Status', status)), Expanded(child: _buildDetailItem(context, 'Prioridade', prioridade)), ], ),
                     Row( children: [ Expanded(child: _buildDetailItem(context, 'Categoria', categoria)), Expanded(child: _buildDetailItem(context, 'Departamento', departamento)), ], ),
                    _buildDetailItem(context, 'Equipamento/Sistema', equipamento),
                    if(tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) // Mostra técnico se houver
                      _buildDetailItem(context, 'Técnico Responsável', tecnicoResponsavel),
                    const Divider(height: 20, thickness: 0.5),
                    _buildDetailItem(context, 'Criado por', criadorNome),
                    _buildDetailItem(context, 'Telefone Criador', criadorPhone),
                    _buildDetailItem(context, 'Criado em', dtCriacao),
                    _buildDetailItem(context, 'Última Atualização', dtUpdate),
                    const Divider(height: 30, thickness: 1, color: Colors.blueGrey),

                    // Seção de Comentários
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text("Comentários / Histórico", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey[800])),
                    ),
                    _buildCommentsSection(), // Chama o widget que constrói a lista de comentários
                    const SizedBox(height: 10), // Espaço antes da área de input
                  ],
                );
              },
            ),
          ), // Fim do Expanded

          // Área de INPUT para novo comentário (fixa embaixo)
          _buildCommentInputArea(),
        ],
      ),
    );
  }

  // --- Widget para construir a lista de comentários ---
  Widget _buildCommentsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chamados')
          .doc(widget.chamadoId)
          .collection('comentarios')
          .orderBy('timestamp', descending: true)
          .limit(50) // Limita o número de comentários carregados inicialmente
          .snapshots(),
      builder: (context, snapshotComentarios) {
        if (snapshotComentarios.hasError) { return const Text("Erro ao carregar comentários.", style: TextStyle(color: Colors.red)); }
        if (snapshotComentarios.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); }
        if (!snapshotComentarios.hasData || snapshotComentarios.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhum comentário ainda.", style: TextStyle(color: Colors.grey))), ); }

        // Usa Column em vez de ListView.builder para evitar scroll infinito dentro de ListView
        return Column(
          children: snapshotComentarios.data!.docs.map((docComentario) {
              final dataComentario = docComentario.data() as Map<String, dynamic>;
              final String texto = dataComentario['texto'] ?? '';
              final String autor = dataComentario['autorNome'] ?? 'Desconhecido';
              final Timestamp? timestamp = dataComentario['timestamp'] as Timestamp?;
              final String dataHora = timestamp != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestamp.toDate()) : '--:--';

              return Card(
                 margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), // Sem margem horizontal
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                 elevation: 0.5, // Menos elevação
                 child: ListTile(
                   title: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
                   subtitle: Padding( padding: const EdgeInsets.only(top: 4.0), child: Text("$autor - $dataHora", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])), ),
                   dense: true,
                 ),
              );
           }).toList(),
        );
      },
    );
  }
  // ---------------------------------------------------

  // --- Widget para a área de input de comentário ---
  Widget _buildCommentInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Padding ajustado
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer, // Cor de fundo diferente
        // border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)), // Linha superior sutil
        boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.08), spreadRadius: 0, blurRadius: 3, offset: const Offset(0, -1), ), ], // Sombra mais suave
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Alinha verticalmente
        children: [
          Expanded(
            child: TextField(
              controller: _comentarioController,
              decoration: InputDecoration(
                hintText: 'Adicionar comentário...',
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none ), // Mais arredondado
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface, // Fundo um pouco diferente
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1, maxLines: 4, // Permite um pouco mais de linhas
              enabled: !_isSendingComment,
              onSubmitted: (_) => _adicionarComentario(), // Envia com Enter no teclado (se aplicável)
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: _isSendingComment
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.send_rounded), // Ícone arredondado
            onPressed: _isSendingComment ? null : _adicionarComentario,
            tooltip: 'Enviar Comentário',
            color: Theme.of(context).colorScheme.primary,
            style: IconButton.styleFrom( // Estilo para botão ficar circular
              backgroundColor: _isSendingComment ? Colors.grey[300] : Theme.of(context).colorScheme.primaryContainer,
              // padding: EdgeInsets.all(10) // Se quiser aumentar a área de toque
            ),
          ),
        ],
      ),
    );
  }
  // ---------------------------------------------

  // --- Widget auxiliar para criar itens de detalhe (CORRIGIDO) ---
  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0), // Reduzi padding vertical
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120, // Largura fixa para o rótulo
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8), // Menor espaçamento
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4), // Altura da linha
              textAlign: isMultiline ? TextAlign.start : TextAlign.start, // Removi justify
            ),
          ),
        ],
      ),
    );
  }
  // ----------------------------------------------------------
} // Fim da classe _DetalhesChamadoScreenState