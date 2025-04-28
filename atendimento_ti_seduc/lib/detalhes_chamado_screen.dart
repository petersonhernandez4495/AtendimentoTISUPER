// lib/detalhes_chamado_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'pdf_generator.dart'; // <<< IMPORT ADICIONADO/VERIFICADO
import 'agendamento_visita_screen.dart'; // Verifique o caminho

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  final List<String> _listaStatus = ['aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  // --- Verifique se Prioridade ainda existe e é editável ---
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica']; // Mantenha se for relevante
  // -------------------------------------------------------
  final TextEditingController _comentarioController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  // --- Função para mostrar diálogo de edição ---
  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
    String statusSelecionado = dadosAtuais['status'] ?? 'aberto';
    // --- VERIFIQUE SE O CAMPO 'prioridade' AINDA EXISTE ---
    String prioridadeSelecionada = dadosAtuais['prioridade'] ?? 'Baixa'; // Assumindo que ainda existe
    // ---------------------------------------------------
    String tecnicoResponsavel = dadosAtuais['tecnico_responsavel'] as String? ?? '';
    final tecnicoController = TextEditingController(text: tecnicoResponsavel);
    final formKeyDialog = GlobalKey<FormState>();

    if (!_listaStatus.contains(statusSelecionado)) statusSelecionado = _listaStatus[0];
    // --- VERIFIQUE SE PRIORIDADE EXISTE ---
    if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades[0]; // Apenas se prioridade for usada
    // -----------------------------------

    bool? confirmou = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Chamado'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        value: statusSelecionado,
                        items: _listaStatus.map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        )).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setDialogState(() { statusSelecionado = newValue; });
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Status'),
                        validator: (value) => value == null ? 'Selecione um status' : null,
                      ),
                      const SizedBox(height: 15),

                      // --- Dropdown Prioridade (REMOVER SE NÃO FOR MAIS USADO) ---
                      DropdownButtonFormField<String>(
                        value: prioridadeSelecionada,
                        items: _listaPrioridades.map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        )).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setDialogState(() { prioridadeSelecionada = newValue; });
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Prioridade'),
                        validator: (value) => value == null ? 'Selecione uma prioridade' : null,
                      ),
                      const SizedBox(height: 15),
                      // -----------------------------------------------------------------------

                      TextFormField(
                        controller: tecnicoController,
                        decoration: const InputDecoration(labelText: 'Técnico Responsável (Opcional)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                ElevatedButton(
                  child: const Text('Salvar'),
                  onPressed: () {
                    if (formKeyDialog.currentState!.validate()) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                ),
              ],
            );
          }
        );
      },
    );

    if (confirmou == true && mounted) {
      try {
        final tecnicoFinal = tecnicoController.text.trim();
        final Map<String, dynamic> updateData = {
          'status': statusSelecionado,
          'tecnico_responsavel': tecnicoFinal.isEmpty ? null : tecnicoFinal,
          'data_atualizacao': FieldValue.serverTimestamp(),
          // --- Adiciona prioridade apenas se ainda for relevante ---
           'prioridade': prioridadeSelecionada, // << REMOVER SE NÃO EXISTIR MAIS
          // -----------------------------------------------------
        };

        await FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).update(updateData);

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chamado atualizado!'), backgroundColor: Colors.green,));
      } catch (e) {
        print("Erro ao atualizar: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: ${e.toString()}'), backgroundColor: Colors.red,));
      }
    }
    tecnicoController.dispose();
  }

  // --- Funções de PDF ---
  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      // <<< CORRIGIDO: Chamada direta da função top-level >>>
      final Uint8List pdfBytes = await generateTicketPdf(currentData);

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/chamado_${widget.chamadoId}.pdf';
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await Share.shareXFiles([XFile(tempPath)], text: 'Detalhes do Chamado ${widget.chamadoId}');

    } catch (e) {
       if (mounted) Navigator.of(context, rootNavigator: true).pop();
       print("Erro ao gerar/compartilhar PDF: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao gerar/compartilhar PDF: ${e.toString()}'), backgroundColor: Colors.red,) );
    }
  }

  Future<void> _baixarPdf(Map<String, dynamic> dadosChamado) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
        // <<< CORRIGIDO: Chamada direta da função top-level >>>
        final Uint8List pdfBytes = await generateTicketPdf(dadosChamado);

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/chamado_${widget.chamadoId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        if (mounted) Navigator.of(context, rootNavigator: true).pop();

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
            throw Exception('Não foi possível abrir o arquivo PDF: ${result.message}');
        }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('PDF baixado e aberto: ${file.path.split('/').last}')) );

    } catch (e) {
         if (mounted) Navigator.of(context, rootNavigator: true).pop();
         print("Erro ao baixar/abrir PDF: $e");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao baixar/abrir PDF: ${e.toString()}'), backgroundColor: Colors.red,) );
    }
  }

  // --- Função para Adicionar Comentário ---
  Future<void> _adicionarComentario() async {
     final textoComentario = _comentarioController.text.trim();
     if (textoComentario.isEmpty) return;

     final user = FirebaseAuth.instance.currentUser;
     if (user == null) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa estar logado para comentar.')));
         return;
     }
     setState(() { _isSendingComment = true; });

     try {
         final autorNome = user.displayName?.isNotEmpty ?? false ? user.displayName! : "Usuário Desconhecido";
         final autorUid = user.uid;

         await FirebaseFirestore.instance
             .collection('chamados')
             .doc(widget.chamadoId)
             .collection('comentarios')
             .add({
                 'texto': textoComentario,
                 'autorNome': autorNome,
                 'autorUid': autorUid,
                 'timestamp': FieldValue.serverTimestamp(),
             });
         _comentarioController.clear();
     } catch (e) {
         print("Erro ao adicionar comentário: $e");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar comentário.'), backgroundColor: Colors.red,));
     } finally {
         if(mounted) setState(() { _isSendingComment = false; });
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Chamado'),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final currentData = snapshot.data!.data()! as Map<String, dynamic>;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton( icon: const Icon(Icons.edit_note), tooltip: 'Editar Status/Técnico', onPressed: () => _mostrarDialogoEdicao(currentData), ),
                    IconButton( icon: const Icon(Icons.share), tooltip: 'Compartilhar PDF', onPressed: () => _handlePdfShare(currentData), ),
                    IconButton( icon: const Icon(Icons.download), tooltip: 'Baixar PDF', onPressed: () => _baixarPdf(currentData), ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
              builder: (context, snapshotChamado) {
                if (snapshotChamado.hasError) { return Center(child: Text('Erro: ${snapshotChamado.error}')); }
                if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado')); }

                final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>;
                final String tipoSolicitante = data['tipo_solicitante'] ?? 'N/I';
                final String nomeSolicitante = data['nome_solicitante'] ?? 'N/I';
                final String celularContato = data['celular_contato'] ?? 'N/I';
                final String equipamentoSolicitacao = data['equipamento_solicitacao'] ?? 'N/I';
                final String conectadoInternet = data['equipamento_conectado_internet'] ?? 'N/I';
                final String marcaModelo = data['marca_modelo_equipamento'] ?? '';
                final String patrimonio = data['numero_patrimonio'] ?? 'N/I';
                final String problemaOcorre = data['problema_ocorre'] ?? 'N/I';
                final String? escola = data['escola'] as String?;
                final String? cargoFuncao = data['cargo_funcao'] as String?;
                final String? atendimentoPara = data['atendimento_para'] as String?;
                final String? setorSuper = data['setor_superintendencia'] as String?;
                final String status = data['status'] ?? 'N/I';
                // --- Verifique se prioridade existe ---
                final String prioridade = data['prioridade'] ?? 'N/I'; // Mantenha se existir
                // -----------------------------------
                final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?;
                final String? authUserDisplay = data['authUserDisplayName'] as String?;
                final Timestamp? tsCriacao = data['data_criacao'] as Timestamp?;
                final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
                final Timestamp? tsUpdate = data['data_atualizacao'] as Timestamp?;
                final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                  children: <Widget>[
                    _buildDetailItem(context, 'Solicitante', nomeSolicitante),
                    _buildDetailItem(context, 'Contato', celularContato),
                    _buildDetailItem(context, 'Tipo', tipoSolicitante),
                    if (tipoSolicitante == 'Escola') ...[
                      if (escola != null) _buildDetailItem(context, 'Escola', escola),
                      if (cargoFuncao != null) _buildDetailItem(context, 'Cargo/Função', cargoFuncao),
                      if (atendimentoPara != null) _buildDetailItem(context, 'Atendimento Para', atendimentoPara),
                    ],
                    if (tipoSolicitante == 'Superintendência') ...[
                      if (setorSuper != null) _buildDetailItem(context, 'Setor SUPER', setorSuper),
                    ],
                    const Divider(height: 20, thickness: 0.5),
                    _buildDetailItem(context, 'Problema Relatado', problemaOcorre, isMultiline: true),
                    _buildDetailItem(context, 'Equipamento', equipamentoSolicitacao),
                    if (marcaModelo.isNotEmpty) _buildDetailItem(context, 'Marca/Modelo', marcaModelo),
                    _buildDetailItem(context, 'Patrimônio', patrimonio),
                    _buildDetailItem(context, 'Conectado à Internet', conectadoInternet),
                    const Divider(height: 20, thickness: 0.5),
                    Row( children: [
                        Expanded(child: _buildDetailItem(context, 'Status', status)),
                        // --- Exibir Prioridade apenas se ainda for usada ---
                        Expanded(child: _buildDetailItem(context, 'Prioridade', prioridade)), // << REMOVER SE NÃO EXISTIR MAIS
                        // ----------------------------------------------------
                      ],
                    ),
                    if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty)
                      _buildDetailItem(context, 'Técnico Responsável', tecnicoResponsavel),
                    const Divider(height: 20, thickness: 0.5),
                    _buildDetailItem(context, 'Criado em', dtCriacao),
                    _buildDetailItem(context, 'Última Atualização', dtUpdate),
                    if (authUserDisplay != null && authUserDisplay.isNotEmpty)
                      _buildDetailItem(context, 'Registrado por', authUserDisplay),
                    const Divider(height: 30, thickness: 1, color: Colors.teal),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: const Text('Agendar Nova Visita'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AgendamentoVisitaScreen(chamadoId: widget.chamadoId),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12) ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0, bottom: 8.0),
                      child: Text("Agenda de Visitas", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.teal[800])),
                    ),
                    _buildAgendaSection(),
                    const Divider(height: 30, thickness: 1.5, color: Colors.blueGrey),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text("Comentários / Histórico", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey[800])),
                    ),
                    _buildCommentsSection(),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
          _buildCommentInputArea(),
        ],
      ),
    );
  }

  // --- Widget para construir a SEÇÃO DE AGENDA ---
  Widget _buildAgendaSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chamados')
          .doc(widget.chamadoId)
          .collection('visitas_agendadas')
          .orderBy('dataHoraAgendada', descending: false)
          .limit(10)
          .snapshots(),
      builder: (context, snapshotVisitas) {
          if (snapshotVisitas.hasError) { return Text("Erro ao carregar agenda: ${snapshotVisitas.error}", style: const TextStyle(color: Colors.red)); } if (snapshotVisitas.connectionState == ConnectionState.waiting) { return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))); } if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhuma visita agendada.", style: TextStyle(color: Colors.grey))), ); } return Column( children: snapshotVisitas.data!.docs.map((docVisita) { final dataVisita = docVisita.data() as Map<String, dynamic>; final Timestamp? timestampAgendado = dataVisita['dataHoraAgendada'] as Timestamp?; final String dataHoraAgendada = timestampAgendado != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestampAgendado.toDate()) : 'Data Inválida'; final String tecnico = dataVisita['tecnicoNome'] as String? ?? 'Não definido'; final String status = dataVisita['statusVisita'] as String? ?? 'N/I'; final String obs = dataVisita['observacoes'] as String? ?? ''; return Card( margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0), elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: ListTile( leading: Icon(_getVisitaStatusIcon(status), color: _getVisitaStatusColor(status), size: 32), title: Text("Agendado: $dataHoraAgendada", style: const TextStyle(fontWeight: FontWeight.w500)), subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const SizedBox(height: 3), if (tecnico != 'Não definido') Text("Técnico: $tecnico"), if (obs.isNotEmpty) Text("Obs: $obs", style: const TextStyle(fontStyle: FontStyle.italic)), Text("Status: $status", style: const TextStyle(fontWeight: FontWeight.w500)), ], ), dense: true, ), ); }).toList(), );
      },
    );
  }
  IconData _getVisitaStatusIcon(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Icons.event_available; case 'realizada': return Icons.check_circle; case 'cancelada': return Icons.cancel; case 'reagendada': return Icons.history_toggle_off; default: return Icons.help_outline; } }
  Color _getVisitaStatusColor(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; } }

  // --- Widget para construir a lista de comentários ---
  Widget _buildCommentsSection() {
     return StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance
           .collection('chamados')
           .doc(widget.chamadoId)
           .collection('comentarios')
           .orderBy('timestamp', descending: true)
           .limit(50)
           .snapshots(),
       builder: (context, snapshotComentarios) {
         if (snapshotComentarios.hasError) { return const Text("Erro ao carregar comentários.", style: TextStyle(color: Colors.red)); } if (snapshotComentarios.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); } if (!snapshotComentarios.hasData || snapshotComentarios.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhum comentário ainda.", style: TextStyle(color: Colors.grey))), ); } return Column( children: snapshotComentarios.data!.docs.map((docComentario) { final dataComentario = docComentario.data() as Map<String, dynamic>; final String texto = dataComentario['texto'] ?? ''; final String autor = dataComentario['autorNome'] ?? 'Desconhecido'; final Timestamp? timestamp = dataComentario['timestamp'] as Timestamp?; final String dataHora = timestamp != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestamp.toDate()) : '--:--'; return Card( margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0.5, child: ListTile( title: Text(texto, style: Theme.of(context).textTheme.bodyMedium), subtitle: Padding( padding: const EdgeInsets.only(top: 4.0), child: Text("$autor - $dataHora", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])), ), dense: true, ), ); }).toList(), );
       },
     );
  }

  // --- Widget para a área de input de comentário ---
  Widget _buildCommentInputArea() {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
       decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surfaceContainer,
         boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.08), spreadRadius: 0, blurRadius: 3, offset: const Offset(0, -1), ), ],
       ),
       child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [
         Expanded(
           child: TextField(
             controller: _comentarioController,
             decoration: InputDecoration(
               hintText: 'Adicionar comentário...',
               border: OutlineInputBorder( borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none ),
               filled: true, fillColor: Theme.of(context).colorScheme.surface,
               contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
               isDense: true,
             ),
             textCapitalization: TextCapitalization.sentences,
             minLines: 1, maxLines: 4, enabled: !_isSendingComment,
             onSubmitted: (_) => _adicionarComentario(),
           ),
         ),
         const SizedBox(width: 8.0),
         IconButton(
           icon: _isSendingComment
               ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
               : const Icon(Icons.send_rounded),
           onPressed: _isSendingComment ? null : _adicionarComentario,
           tooltip: 'Enviar Comentário', color: Theme.of(context).colorScheme.primary,
           style: IconButton.styleFrom(
             backgroundColor: _isSendingComment ? Colors.grey[300] : Theme.of(context).colorScheme.primaryContainer,
           ),
         ),
       ],
       ),
     );
  }

  // --- Widget auxiliar para criar itens de detalhe ---
  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

} // Fim da classe _DetalhesChamadoScreenState