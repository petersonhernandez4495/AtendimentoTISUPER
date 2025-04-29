// lib/detalhes_chamado_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Para formatação de data
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

// Importações locais (verifique os caminhos)
import 'pdf_generator.dart';
import 'agendamento_visita_screen.dart';
import 'config/theme/app_theme.dart'; // Importa o tema

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  // Listas para o diálogo de edição (podem vir do AppTheme ou config se preferir)
  final List<String> _listaStatus = ['aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica']; // Mantenha se usar prioridade editável

  final TextEditingController _comentarioController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  // --- Função para mostrar diálogo de edição (InputDecoration removido) ---
  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
    // Usa o tema atual para o diálogo
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    String statusSelecionado = dadosAtuais['status'] ?? _listaStatus.first;
    String prioridadeSelecionada = dadosAtuais['prioridade'] ?? _listaPrioridades.first;
    String tecnicoResponsavel = dadosAtuais['tecnico_responsavel'] as String? ?? '';
    final tecnicoController = TextEditingController(text: tecnicoResponsavel);
    final formKeyDialog = GlobalKey<FormState>();

    // Garante que os valores selecionados existam nas listas
    if (!_listaStatus.contains(statusSelecionado)) statusSelecionado = _listaStatus.first;
    if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades.first;

    bool? confirmou = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Usar Theme para garantir que o diálogo use o tema correto,
        // especialmente se o contexto raiz for diferente.
        return Theme(
          data: theme, // Aplica o tema ao diálogo
          child: StatefulBuilder(
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
                          items: _listaStatus.map((String value) => DropdownMenuItem<String>( value: value, child: Text(value), )).toList(),
                          onChanged: (newValue) { if (newValue != null) { setDialogState(() { statusSelecionado = newValue; }); } },
                          // Removido InputDecoration manual para usar o tema
                          decoration: const InputDecoration(labelText: 'Status'),
                          validator: (value) => value == null ? 'Selecione um status' : null,
                        ),
                        const SizedBox(height: 15),

                        // --- Dropdown Prioridade (REMOVER SE NÃO USAR) ---
                        DropdownButtonFormField<String>(
                          value: prioridadeSelecionada,
                          items: _listaPrioridades.map((String value) => DropdownMenuItem<String>( value: value, child: Text(value), )).toList(),
                          onChanged: (newValue) { if (newValue != null) { setDialogState(() { prioridadeSelecionada = newValue; }); } },
                           // Removido InputDecoration manual para usar o tema
                          decoration: const InputDecoration(labelText: 'Prioridade'),
                          validator: (value) => value == null ? 'Selecione uma prioridade' : null,
                        ),
                        const SizedBox(height: 15),
                        // ------------------------------------------------

                        TextFormField(
                          controller: tecnicoController,
                           // Removido InputDecoration manual para usar o tema
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
                  // Botão usa o ElevatedButtonTheme do AppTheme
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
          ),
        );
      },
    );

    // Atualiza no Firestore se confirmado
    if (confirmou == true && mounted) {
      try {
        final tecnicoFinal = tecnicoController.text.trim();
        final Map<String, dynamic> updateData = {
          'status': statusSelecionado,
          'tecnico_responsavel': tecnicoFinal.isEmpty ? null : tecnicoFinal,
          'data_atualizacao': FieldValue.serverTimestamp(),
           // Adiciona prioridade apenas se ainda for relevante
           'prioridade': prioridadeSelecionada, // << REMOVER SE NÃO EXISTIR MAIS
        };
        await FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).update(updateData);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chamado atualizado!'), backgroundColor: Colors.green,));
      } catch (e) {
        print("Erro ao atualizar: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: ${e.toString()}'), backgroundColor: Colors.red,));
      }
    }
    tecnicoController.dispose(); // Dispose do controller do diálogo
  }

  // --- Funções de PDF (sem alterações na lógica, apenas contexto de tema) ---
  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final Uint8List pdfBytes = await generateTicketPdf(currentData); // Assumindo que pdf_generator está ok
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/chamado_${widget.chamadoId}.pdf';
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes);
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha progresso
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
        final Uint8List pdfBytes = await generateTicketPdf(dadosChamado);
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/chamado_${widget.chamadoId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha progresso
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) { throw Exception('Não foi possível abrir o arquivo PDF: ${result.message}'); }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('PDF baixado e aberto: ${file.path.split('/').last}')) );
     } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        print("Erro ao baixar/abrir PDF: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao baixar/abrir PDF: ${e.toString()}'), backgroundColor: Colors.red,) );
     }
  }

  // --- Função para Adicionar Comentário (sem alterações na lógica) ---
  Future<void> _adicionarComentario() async {
     final textoComentario = _comentarioController.text.trim();
     if (textoComentario.isEmpty) return;
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa estar logado para comentar.'))); return; }
     setState(() { _isSendingComment = true; });
     try {
        final autorNome = user.displayName?.isNotEmpty ?? false ? user.displayName! : "Usuário Desconhecido";
        final autorUid = user.uid;
        await FirebaseFirestore.instance .collection('chamados') .doc(widget.chamadoId) .collection('comentarios') .add({ 'texto': textoComentario, 'autorNome': autorNome, 'autorUid': autorUid, 'timestamp': FieldValue.serverTimestamp(), });
        _comentarioController.clear();
     } catch (e) { print("Erro ao adicionar comentário: $e"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar comentário.'), backgroundColor: Colors.red,));
     } finally { if(mounted) setState(() { _isSendingComment = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    // Pega o tema definido no MaterialApp
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      // AppBar usa appBarTheme do AppTheme
      appBar: AppBar(
        title: const Text('Detalhes do Chamado'),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final currentData = snapshot.data!.data()! as Map<String, dynamic>;
                // IconButtons usarão o iconTheme do AppTheme
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton( icon: const Icon(Icons.edit_note), tooltip: 'Editar Status/Técnico', onPressed: () => _mostrarDialogoEdicao(currentData), ),
                    IconButton( icon: const Icon(Icons.share), tooltip: 'Compartilhar PDF', onPressed: () => _handlePdfShare(currentData), ),
                    IconButton( icon: const Icon(Icons.download), tooltip: 'Baixar PDF', onPressed: () => _baixarPdf(currentData), ),
                  ],
                );
              }
              return const SizedBox.shrink(); // Retorna widget vazio se não há dados
            }
          )
        ],
      ),
      // O fundo do Scaffold é transparente por padrão no seu AppTheme,
      // então o gradiente do widget pai (se houver) aparecerá.
      // Se precisar de um fundo sólido aqui, defina theme.scaffoldBackgroundColor.
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
              builder: (context, snapshotChamado) {
                if (snapshotChamado.hasError) { return Center(child: Text('Erro: ${snapshotChamado.error}', style: TextStyle(color: colorScheme.error))); }
                if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado')); }

                final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>;
                // Extração de dados (mantida)
                 final String tipoSolicitante = data['tipo_solicitante'] ?? 'N/I';
                 final String nomeSolicitante = data['nome_solicitante'] ?? 'N/I';
                 final String celularContato = data['celular_contato'] ?? 'N/I';
                 final String equipamentoSolicitacao = data['equipamento_solicitacao'] ?? 'N/I';
                 final String conectadoInternet = data['equipamento_conectado_internet'] ?? 'N/I';
                 final String marcaModelo = data['marca_modelo_equipamento'] ?? '';
                 final String patrimonio = data['numero_patrimonio'] ?? 'N/I';
                 final String problemaOcorre = data['problema_ocorre'] ?? 'N/I';
                 final String? escola = data['instituicao'] as String?; // Corrigido para 'instituicao'? Verifique seu campo
                 final String? cargoFuncao = data['cargo_funcao'] as String?;
                 final String? atendimentoPara = data['atendimento_para'] as String?;
                 final String? setorSuper = data['setor_superintendencia'] as String?;
                 final String status = data['status'] ?? 'N/I';
                 final String prioridade = data['prioridade'] ?? 'N/I'; // Mantenha se existir
                 final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?;
                 final String? authUserDisplay = data['authUserDisplayName'] as String?;
                 final Timestamp? tsCriacao = data['data_criacao'] as Timestamp?;
                 final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
                 final Timestamp? tsUpdate = data['data_atualizacao'] as Timestamp?;
                 final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';

                // ListView para exibir os detalhes
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0), // Padding geral
                  children: <Widget>[
                    _buildDetailItem(context, 'Solicitante', nomeSolicitante),
                    _buildDetailItem(context, 'Contato', celularContato),
                    _buildDetailItem(context, 'Tipo', tipoSolicitante),
                    if (tipoSolicitante == 'Escola') ...[
                      if (escola != null) _buildDetailItem(context, 'Instituição', escola), // Nome do campo corrigido para Instituição?
                      if (cargoFuncao != null) _buildDetailItem(context, 'Cargo/Função', cargoFuncao),
                      if (atendimentoPara != null) _buildDetailItem(context, 'Atendimento Para', atendimentoPara),
                    ],
                    if (tipoSolicitante == 'Superintendência') ...[
                      if (setorSuper != null) _buildDetailItem(context, 'Setor SUPER', setorSuper),
                    ],
                    Divider(height: 25, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)), // Usa cor do tema
                    _buildDetailItem(context, 'Problema Relatado', problemaOcorre, isMultiline: true),
                    _buildDetailItem(context, 'Equipamento', equipamentoSolicitacao),
                    if (marcaModelo.isNotEmpty) _buildDetailItem(context, 'Marca/Modelo', marcaModelo),
                    _buildDetailItem(context, 'Patrimônio', patrimonio),
                    _buildDetailItem(context, 'Conectado à Internet', conectadoInternet),
                    Divider(height: 25, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)), // Usa cor do tema
                    Row( children: [
                      Expanded(child: _buildDetailItem(context, 'Status', status)),
                      // --- Exibir Prioridade apenas se ainda for usada ---
                      Expanded(child: _buildDetailItem(context, 'Prioridade', prioridade)), // << REMOVER SE NÃO EXISTIR MAIS
                      // ----------------------------------------------------
                    ]),
                    if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty)
                      _buildDetailItem(context, 'Técnico Responsável', tecnicoResponsavel),
                    Divider(height: 25, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)), // Usa cor do tema
                    _buildDetailItem(context, 'Criado em', dtCriacao),
                    _buildDetailItem(context, 'Última Atualização', dtUpdate),
                    if (authUserDisplay != null && authUserDisplay.isNotEmpty)
                      _buildDetailItem(context, 'Registrado por', authUserDisplay),

                    // Seção Agenda
                    Divider(height: 40, thickness: 1, color: colorScheme.primary.withOpacity(0.3)), // Usa cor do tema
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: const Text('Agendar Nova Visita'),
                        onPressed: () {
                          Navigator.push( context, MaterialPageRoute( builder: (context) => AgendamentoVisitaScreen(chamadoId: widget.chamadoId),),);
                        },
                        // Estilo vem do ElevatedButtonTheme do AppTheme
                        // style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12) ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0, bottom: 8.0),
                      // Usar estilo de título do tema
                      child: Text("Agenda de Visitas", style: textTheme.titleMedium),
                    ),
                    _buildAgendaSection(), // Constrói lista de visitas

                    // Seção Comentários
                    Divider(height: 40, thickness: 1, color: colorScheme.primary.withOpacity(0.3)), // Usa cor do tema
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                       // Usar estilo de título do tema
                      child: Text("Comentários / Histórico", style: textTheme.titleMedium),
                    ),
                    _buildCommentsSection(), // Constrói lista de comentários
                    const SizedBox(height: 20), // Espaço extra no final do scroll
                  ],
                );
              },
            ),
          ),
          // Área de input de comentário (ajustada para usar tema)
          _buildCommentInputArea(),
        ],
      ),
    );
  }

  // --- Widget para construir a SEÇÃO DE AGENDA ---
  Widget _buildAgendaSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance .collection('chamados') .doc(widget.chamadoId) .collection('visitas_agendadas') .orderBy('dataHoraAgendada', descending: false) .limit(10) .snapshots(),
      builder: (context, snapshotVisitas) {
         if (snapshotVisitas.hasError) { return Text("Erro ao carregar agenda: ${snapshotVisitas.error}", style: TextStyle(color: Theme.of(context).colorScheme.error)); }
         if (snapshotVisitas.connectionState == ConnectionState.waiting) { return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))); }
         if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhuma visita agendada.")), ); } // Usa estilo padrão

         return Column( children: snapshotVisitas.data!.docs.map((docVisita) {
            final dataVisita = docVisita.data() as Map<String, dynamic>;
            final Timestamp? timestampAgendado = dataVisita['dataHoraAgendada'] as Timestamp?;
            final String dataHoraAgendada = timestampAgendado != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestampAgendado.toDate()) : 'Data Inválida';
            final String tecnico = dataVisita['tecnicoNome'] as String? ?? 'Não definido';
            final String status = dataVisita['statusVisita'] as String? ?? 'N/I';
            final String obs = dataVisita['observacoes'] as String? ?? '';

            // Usa CardTheme definido no AppTheme
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
              // elevation: 1.5, // Removido para usar CardTheme
              // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Removido para usar CardTheme
              child: ListTile(
                leading: Icon(_getVisitaStatusIcon(status), color: _getVisitaStatusColor(status), size: 32), // Cores de status mantidas
                title: Text("Agendado: $dataHoraAgendada", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), // Ajuste o estilo se necessário
                subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 3),
                    if (tecnico != 'Não definido') Text("Técnico: $tecnico", style: Theme.of(context).textTheme.bodySmall), // Usa estilo do tema
                    if (obs.isNotEmpty) Text("Obs: $obs", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)), // Usa estilo do tema
                    Text("Status: $status", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)), // Usa estilo do tema
                ]),
                dense: true,
              ),
            );
         }).toList(), );
      },
    );
  }
  // Funções _getVisitaStatusIcon e _getVisitaStatusColor mantidas como antes, pois são específicas de status
  IconData _getVisitaStatusIcon(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Icons.event_available; case 'realizada': return Icons.check_circle; case 'cancelada': return Icons.cancel; case 'reagendada': return Icons.history_toggle_off; default: return Icons.help_outline; } }
  Color _getVisitaStatusColor(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; } }


  // --- Widget para construir a lista de comentários ---
  Widget _buildCommentsSection() {
     return StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance .collection('chamados') .doc(widget.chamadoId) .collection('comentarios') .orderBy('timestamp', descending: true) .limit(50) .snapshots(),
       builder: (context, snapshotComentarios) {
         if (snapshotComentarios.hasError) { return Text("Erro ao carregar comentários.", style: TextStyle(color: Theme.of(context).colorScheme.error)); }
         if (snapshotComentarios.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); }
         if (!snapshotComentarios.hasData || snapshotComentarios.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhum comentário ainda.")), ); } // Usa estilo padrão

         return Column( children: snapshotComentarios.data!.docs.map((docComentario) {
            final dataComentario = docComentario.data() as Map<String, dynamic>;
            final String texto = dataComentario['texto'] ?? '';
            final String autor = dataComentario['autorNome'] ?? 'Desconhecido';
            final Timestamp? timestamp = dataComentario['timestamp'] as Timestamp?;
            final String dataHora = timestamp != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestamp.toDate()) : '--:--';

            // Usa CardTheme definido no AppTheme
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
              // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // Removido para usar CardTheme
              // elevation: 0.5, // Removido para usar CardTheme (que pode ser 0 ou outro valor)
              child: ListTile(
                title: Text(texto, style: Theme.of(context).textTheme.bodyMedium), // Usa estilo do tema
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  // Usa cor secundária do tema para o subtítulo
                  child: Text("$autor - $dataHora", style: Theme.of(context).textTheme.bodySmall),
                ),
                dense: true,
              ),
            );
         }).toList(), );
       },
     );
  }

  // --- Widget para a área de input de comentário (MODIFICADO) ---
  Widget _buildCommentInputArea() {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;

     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0), // Adapta ao bottom safe area
       // Usa cores do tema para fundo e sombra
       decoration: BoxDecoration(
         color: colorScheme.surfaceContainerLowest, // Cor de fundo sutil do tema Material 3
         boxShadow: [
           BoxShadow(
             color: theme.shadowColor.withOpacity(0.1), // Sombra do tema
             spreadRadius: 0, blurRadius: 4, offset: const Offset(0, -1),
           ),
         ],
       ),
       child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [
         Expanded(
           child: TextField(
             controller: _comentarioController,
             // Usa InputDecorationTheme do AppTheme
             decoration: InputDecoration(
               hintText: 'Adicionar comentário...',
               // Ajustes específicos podem ser feitos aqui, se necessário,
               // mas a base vem do tema (fillColor, border, contentPadding)
               isDense: true, // Mantém denso para menor altura
               // Exemplo de override se o tema não definir borda/fill:
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none ),
                filled: true, // Garante que use fillColor do tema
                fillColor: colorScheme.surface, // Pode especificar uma cor ligeiramente diferente se quiser
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
             ),
             textCapitalization: TextCapitalization.sentences,
             minLines: 1, maxLines: 4, enabled: !_isSendingComment,
             onSubmitted: (_) => _isSendingComment ? null : _adicionarComentario(), // Envia com Enter
           ),
         ),
         const SizedBox(width: 8.0),
         // IconButton estilizado com o tema
         IconButton(
           icon: _isSendingComment
               ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
               : Icon(Icons.send_rounded, color: colorScheme.primary), // Usa cor primária para o ícone
           onPressed: _isSendingComment ? null : _adicionarComentario,
           tooltip: 'Enviar Comentário',
           // Estilo do botão baseado no tema
           style: IconButton.styleFrom(
             // Usa cor do container primário para o fundo
             backgroundColor: colorScheme.primaryContainer,
             // Cor para o ícone quando desabilitado
             disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
           ).copyWith(
              // Garante contraste para o ícone (se necessário, mas geralmente handled by theme)
              // foregroundColor: MaterialStateProperty.resolveWith<Color?>(
              //   (Set<MaterialState> states) {
              //      if (states.contains(MaterialState.disabled)) return colorScheme.onSurface.withOpacity(0.38);
              //      return colorScheme.onPrimaryContainer; // Ícone sobre o container primário
              //   },
              // ),
           ),
         ),
       ]),
     );
  }

  // --- Widget auxiliar para criar itens de detalhe (MODIFICADO) ---
  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isMultiline = false}) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 0), // Ajuste fino no padding vertical
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120, // Largura fixa para o label (ajuste se necessário)
            child: Text(
              '$label:',
              style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  // Usa cor do tema com opacidade para label secundário
                  color: colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ),
          const SizedBox(width: 10), // Espaço entre label e valor
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value, // Mostra '-' se valor vazio
              style: textTheme.bodyMedium?.copyWith(height: 1.4), // Usa estilo do tema (mantém ajuste de altura)
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

} // Fim da classe _DetalhesChamadoScreenState