import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import 'pdf_generator.dart' as pdfGen;
import 'agendamento_visita_screen.dart';
import 'config/theme/app_theme.dart';
import 'services/chamado_service.dart';

const List<String> kListaStatusChamado = [
  'Aberto', 'Em Andamento', 'Pendente', 'Aguardando Aprovação',
  'Aguardando Peça', 'Solucionado', 'Cancelado', 'Fechado',
  'Chamado Duplicado', 'Aguardando Equipamento', 'Atribuido para GSIOR',
  'Garantia Fabricante',
];
const String kStatusSolucionado = 'Solucionado';

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  final ChamadoService _chamadoService = ChamadoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isAdmin = false;
  bool _isAdminStatusChecked = false;
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];
  final TextEditingController _comentarioController = TextEditingController();
  bool _isSendingComment = false;
  bool _isUpdatingVisibility = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    if (!_isAdminStatusChecked && mounted) {
      bool isAdminResult = false;
      if (_currentUser != null) {
        final userId = _currentUser!.uid;
        try {
          final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(const GetOptions(source: Source.cache));
          Map<String, dynamic>? userData;
          if (userDoc.exists && userDoc.data() != null) {
            userData = userDoc.data() as Map<String, dynamic>;
          } else {
            final DocumentSnapshot serverUserDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(const GetOptions(source: Source.server));
            if(serverUserDoc.exists && serverUserDoc.data() != null) {
               userData = serverUserDoc.data() as Map<String, dynamic>;
            }
          }
          if (userData != null) {
            if (userData.containsKey('role_temp')) {
              final roleValue = userData['role_temp'];
              isAdminResult = (roleValue == 'admin');
            }
          }
        } catch (e, s) {
          print("Erro fatal ao buscar role: $e\n$s");
          isAdminResult = false;
        }
      } else {
        isAdminResult = false;
      }
      if (mounted) {
        setState(() { _isAdmin = isAdminResult; _isAdminStatusChecked = true; });
      }
    }
  }


  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
    final ThemeData theme = Theme.of(context);
    final formKeyDialog = GlobalKey<FormState>();
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    String statusSelecionado = dadosAtuais[kFieldStatus] as String? ?? kListaStatusChamado.first;
    String prioridadeSelecionada = dadosAtuais[kFieldPrioridade] as String? ?? _listaPrioridades.first;
    String tecnicoResponsavel = dadosAtuais[kFieldTecnicoResponsavel] as String? ?? '';
    final solutionControllerDialog = TextEditingController(text: dadosAtuais[kFieldSolucao] as String? ?? '');
    bool showMandatoryFields = statusSelecionado == kStatusSolucionado;
    DateTime? _selectedAtendimentoDate;
    final Timestamp? currentAtendimentoTs = dadosAtuais[kFieldDataAtendimento] as Timestamp?;
    if (currentAtendimentoTs != null) { _selectedAtendimentoDate = currentAtendimentoTs.toDate(); }

    if (!kListaStatusChamado.contains(statusSelecionado)) statusSelecionado = kListaStatusChamado.first;
    if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades.first;

    Future<void> _selectDate(BuildContext context, Function(DateTime?) onDateSelected) async {
      final DateTime? picked = await showDatePicker( context: context, initialDate: _selectedAtendimentoDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)), locale: const Locale('pt', 'BR'), );
      if (picked != null && picked != _selectedAtendimentoDate) { onDateSelected(picked); }
    }

    bool? confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<String>( value: statusSelecionado, items: kListaStatusChamado.map((String v) => DropdownMenuItem<String>( value: v, child: Text(v), )).toList(), onChanged: (newValue) { if (newValue != null) { setDialogState(() { statusSelecionado = newValue; showMandatoryFields = newValue == kStatusSolucionado; if (!showMandatoryFields) { solutionControllerDialog.clear(); _selectedAtendimentoDate = null;}}); }}, decoration: const InputDecoration(labelText: 'Status'), validator: (v) => v == null ? 'Selecione status' : null, ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>( value: prioridadeSelecionada, items: _listaPrioridades.map((String v) => DropdownMenuItem<String>( value: v, child: Text(v), )).toList(), onChanged: (newValue) { if (newValue != null) { setDialogState(() { prioridadeSelecionada = newValue; }); } }, decoration: const InputDecoration(labelText: 'Prioridade'), validator: (v) => v == null ? 'Selecione prioridade' : null, ),
                      const SizedBox(height: 15),
                      TextFormField( initialValue: tecnicoResponsavel, onChanged: (value) => tecnicoResponsavel = value, decoration: const InputDecoration(labelText: 'Técnico Responsável (Opcional)'), ),
                      const SizedBox(height: 15),
                      Visibility(
                        visible: showMandatoryFields,
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              const Divider(height: 20),
                              Text("Detalhes da Solução (Obrigatório)", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              TextFormField( controller: solutionControllerDialog, decoration: const InputDecoration( labelText: 'Descrição da Solução', hintText: 'Digite os detalhes...', border: OutlineInputBorder(), alignLabelWithHint: true, ), maxLines: 3, validator: (value) { if (showMandatoryFields && (value == null || value.trim().isEmpty)) { return 'Descrição obrigatória para solucionar.'; } return null; },),
                              const SizedBox(height: 15),
                              Text("Data de Atendimento (Obrigatório)", style: theme.textTheme.labelMedium),
                              const SizedBox(height: 5),
                              Row( children: [
                                  Expanded( child: OutlinedButton.icon( icon: const Icon(Icons.calendar_today, size: 18), label: Text( _selectedAtendimentoDate == null ? 'Selecionar Data' : dateFormat.format(_selectedAtendimentoDate!), ), onPressed: () { _selectDate(dialogContext, (pickedDate) { setDialogState(() { _selectedAtendimentoDate = pickedDate; }); }); }, style: OutlinedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.centerLeft, foregroundColor: _selectedAtendimentoDate == null ? theme.hintColor : theme.textTheme.bodyLarge?.color, side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5))),),),
                                  if (_selectedAtendimentoDate != null) IconButton( icon: const Icon(Icons.clear, size: 20), tooltip: "Limpar Data", onPressed: () { setDialogState(() { _selectedAtendimentoDate = null; }); }, color: theme.colorScheme.error, ),],),
                              const SizedBox(height: 15),
                              const Divider(height: 20),
                           ]
                        )
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                 TextButton( child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop(false), ),
                 ElevatedButton(
                   child: const Text('Salvar'),
                   onPressed: () {
                     if (!formKeyDialog.currentState!.validate()) { return; }
                     if (statusSelecionado == kStatusSolucionado) {
                        final isDescriptionEmpty = solutionControllerDialog.text.trim().isEmpty;
                        final isDateMissing = _selectedAtendimentoDate == null;
                        if (isDescriptionEmpty || isDateMissing) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar( const SnackBar( content: Text('Para status "Solucionado", descrição e data são obrigatórias.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating, margin: EdgeInsets.all(10),) );
                            return;
                        }
                     }
                     Navigator.of(dialogContext).pop(true);
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
        final tecnicoFinal = tecnicoResponsavel.trim();
        final String? solucaoFinal = statusSelecionado == kStatusSolucionado ? solutionControllerDialog.text.trim() : null;
        final Timestamp? atendimentoTimestamp = _selectedAtendimentoDate != null ? Timestamp.fromDate(_selectedAtendimentoDate!) : null;

        await _chamadoService.atualizarDetalhesAdmin(
          chamadoId: widget.chamadoId,
          status: statusSelecionado,
          prioridade: prioridadeSelecionada,
          tecnicoResponsavel: tecnicoFinal.isEmpty ? null : tecnicoFinal,
          solucao: solucaoFinal,
          dataAtendimento: atendimentoTimestamp,
        );

        if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Chamado atualizado!'), backgroundColor: Colors.green,));

      } catch (e) {
        print("Erro ao atualizar: $e");
        if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao atualizar: ${e.toString()}'), backgroundColor: Colors.red,));
      }
    }
    solutionControllerDialog.dispose();
  }

  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async { await pdfGen.generateAndSharePdfForTicket( context: context, chamadoId: widget.chamadoId, dadosChamado: currentData, ); }
  Future<void> _baixarPdf(Map<String, dynamic> dadosChamado) async { await pdfGen.generateAndOpenPdfForTicket( context: context, chamadoId: widget.chamadoId, dadosChamado: dadosChamado, ); }
  Future<void> _adicionarComentario() async { final t = _comentarioController.text.trim(); if (t.isEmpty) return; final u = _auth.currentUser; if (u == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logue para comentar.'))); return; } setState(() { _isSendingComment = true; }); try { final a = u.displayName?.trim().isNotEmpty??false ? u.displayName!.trim() : (u.email??"User"); await FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('comentarios').add({ 'texto': t, 'autorNome': a, 'autorUid': u.uid, 'timestamp': FieldValue.serverTimestamp(), }); _comentarioController.clear(); FocusScope.of(context).unfocus(); } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'),backgroundColor: Colors.red,)); } finally { if(mounted) setState(() { _isSendingComment = false; }); } }
  Future<void> _toggleInatividadeAdmin(bool isInativo) async { if (!_isAdmin || _isUpdatingVisibility) return; final bool ativar = isInativo; final String acao = ativar ? "Reativar" : "Inativar"; final String label = ativar ? "Reativado" : "Inativo"; final c = await showDialog<bool>( context: context, barrierDismissible: false, builder: (ctx) => AlertDialog( title: const Text('Confirmar'), content: Text('Deseja "$acao" este chamado?\n(Req. ${ativar ? 'poderá' : 'NÃO poderá'} ver).'), actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), TextButton( onPressed: () => Navigator.of(ctx).pop(true), child: Text('Confirmar', style: TextStyle(color: ativar ? Colors.green : Colors.red))), ], ), ); if (c != true) return; setState(() { _isUpdatingVisibility = true; }); try { await _chamadoService.definirInatividadeAdministrativa(widget.chamadoId, !isInativo); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Chamado "$label" adm.'), backgroundColor: Colors.green)); } } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text('Erro inatividade: $e'), backgroundColor: Colors.red)); } } finally { if (mounted) { setState(() { _isUpdatingVisibility = false; }); } } }

  @override
  Widget build(BuildContext context) {
    if (!_isAdminStatusChecked) { return Scaffold( appBar: AppBar(title: const Text('Carregando...')), body: const Center(child: CircularProgressIndicator()), ); }
    return Scaffold(
      appBar: AppBar( title: Text('Chamado #${widget.chamadoId.substring(0, 6)}...'), actions: [ StreamBuilder<DocumentSnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).snapshots(), builder: (context, snapshot) { if (snapshot.hasData && snapshot.data!.exists) { final currentData = snapshot.data!.data() as Map<String, dynamic>? ?? {}; final bool isInativoAdmin = currentData[kFieldAdminInativo] ?? false; bool podeInteragir = _isAdmin || !isInativoAdmin; return Row( mainAxisSize: MainAxisSize.min, children: [ if (_isAdmin) IconButton( icon: const Icon(Icons.edit_note_outlined), tooltip: 'Editar Chamado', onPressed: _isUpdatingVisibility ? null : () => _mostrarDialogoEdicao(currentData), ), if (podeInteragir) ...[ IconButton( icon: const Icon(Icons.share_outlined), tooltip: 'Compartilhar PDF', onPressed: () => _handlePdfShare(currentData), ), IconButton( icon: const Icon(Icons.download_outlined), tooltip: 'Baixar/Abrir PDF', onPressed: () => _baixarPdf(currentData), ), ]],); } return const SizedBox.shrink(); })],),
      body: Column( children: [
          Expanded( child: StreamBuilder<DocumentSnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).snapshots(), builder: (context, snapshotChamado) { if (snapshotChamado.hasError) { return Center(child: Text('Erro: ${snapshotChamado.error}')); } if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado')); } final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>; final bool isInativoAdmin = data[kFieldAdminInativo] ?? false;
                 return _ChamadoInfoBody( key: ValueKey(widget.chamadoId + (data[kFieldDataAtualizacao]?.toString() ?? '')), data: data, isAdmin: _isAdmin, isInativoAdmin: isInativoAdmin, isUpdatingVisibility: _isUpdatingVisibility, chamadoId: widget.chamadoId, onToggleInatividade: _toggleInatividadeAdmin, buildAgendaSection: _buildAgendaSection, buildCommentsSection: _buildCommentsSection, ); }, ), ),
          StreamBuilder<DocumentSnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData || snapshot.hasError || !snapshot.data!.exists) { return const SizedBox.shrink(); } final bool isInativoAdmin = (snapshot.data!.data() as Map<String, dynamic>?)?[kFieldAdminInativo] ?? false; final bool podeComentar = _isAdmin || !isInativoAdmin; return AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (Widget child, Animation<double> animation) { return SizeTransition(sizeFactor: animation, child: child); }, child: podeComentar ? _buildCommentInputArea() : Container( key: const ValueKey('comentario_inativo'), padding: const EdgeInsets.all(12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8), color: Theme.of(context).colorScheme.surfaceContainerLowest, child: Center( child: Text( 'Comentários desabilitados (Chamado Inativo)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),)),),); } ), ], ), );
  }

  Widget _buildAgendaSection() { return StreamBuilder<QuerySnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('visitas_agendadas').orderBy('dataHoraAgendada', descending: false).limit(10).snapshots(), builder: (context, snapshotVisitas) { if (snapshotVisitas.hasError) { return Text("Erro agenda: ${snapshotVisitas.error}"); } if (snapshotVisitas.connectionState == ConnectionState.waiting) { return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))); } if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhuma visita agendada.")), ); } return Column( children: snapshotVisitas.data!.docs.map((docVisita) { final dataVisita = docVisita.data() as Map<String, dynamic>; final Timestamp? ts = dataVisita['dataHoraAgendada'] as Timestamp?; final String dtHr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(ts.toDate()) : 'Inválida'; final String tec = dataVisita['tecnicoNome'] as String? ?? 'N/D'; final String st = dataVisita['statusVisita'] as String? ?? 'N/I'; final String obs = dataVisita['observacoes'] as String? ?? ''; return Card( margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: ListTile( leading: Icon(_getVisitaStatusIcon(st), color: _getVisitaStatusColor(st), size: 32), title: Text("Agendado: $dtHr", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const SizedBox(height: 3), if (tec != 'N/D') Text("Técnico: $tec"), if (obs.isNotEmpty) Text("Obs: $obs", style: const TextStyle(fontStyle: FontStyle.italic)), Text("Status: $st", style: const TextStyle(fontWeight: FontWeight.w500)), ]), dense: true, ), ); }).toList(), ); }, ); }
  IconData _getVisitaStatusIcon(String? s) { switch (s?.toLowerCase()) { case 'agendada': return Icons.event_available_outlined; case 'realizada': return Icons.check_circle_outline; case 'cancelada': return Icons.cancel_outlined; case 'reagendada': return Icons.history_outlined; default: return Icons.help_outline; } }
  Color _getVisitaStatusColor(String? s) { switch (s?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; } }
  Widget _buildCommentsSection() { return StreamBuilder<QuerySnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('comentarios').orderBy('timestamp', descending: true).limit(50).snapshots(), builder: (context, snapshot) { if (snapshot.hasError) { return const Text("Erro comentários."); } if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); } if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhum comentário."))); } return Column( children: snapshot.data!.docs.map((doc) { final d = doc.data() as Map<String, dynamic>; final t = d['texto'] ?? ''; final a = d['autorNome'] ?? 'Desconhecido'; final ts = d['timestamp'] as Timestamp?; final dtHr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(ts.toDate()) : '--'; final sys = d['isSystemMessage'] ?? false; return Card( margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), elevation: 0.5, color: sys ? Colors.blueGrey.shade50.withOpacity(0.5) : null, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), child: ListTile( title: Text(t, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: sys ? FontStyle.italic : null)), subtitle: Padding( padding: const EdgeInsets.only(top: 4.0), child: Text( sys ? "Sistema - $dtHr" : "$a - $dtHr", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sys ? Colors.blueGrey : null))), dense: true, ), ); }).toList(), ); }, ); }
  Widget _buildCommentInputArea() { final th = Theme.of(context); final cs = th.colorScheme; return Container( key: const ValueKey('comentario_ativo'), padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0), decoration: BoxDecoration( color: cs.surfaceContainerLowest, boxShadow: [ BoxShadow( color: th.shadowColor.withOpacity(0.1), spreadRadius: 0, blurRadius: 4, offset: const Offset(0, -1), ), ], ), child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [ Expanded( child: TextField( controller: _comentarioController, decoration: InputDecoration( hintText: 'Adicionar comentário...', isDense: true, border: OutlineInputBorder( borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none ), filled: true, fillColor: cs.surfaceContainerHighest, contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0), ), textCapitalization: TextCapitalization.sentences, minLines: 1, maxLines: 4, enabled: !_isSendingComment, onSubmitted: (_) => _isSendingComment ? null : _adicionarComentario(), textInputAction: TextInputAction.send, ), ), const SizedBox(width: 8.0), IconButton( icon: _isSendingComment ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Icon(Icons.send_rounded, color: cs.primary), onPressed: _isSendingComment ? null : _adicionarComentario, tooltip: 'Enviar', style: IconButton.styleFrom( backgroundColor: cs.primaryContainer, disabledBackgroundColor: cs.onSurface.withOpacity(0.12), ), ), ]), ); }

}

class _ChamadoInfoBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  final bool isInativoAdmin;
  final bool isUpdatingVisibility;
  final String chamadoId;
  final Function(bool) onToggleInatividade;
  final Widget Function() buildAgendaSection;
  final Widget Function() buildCommentsSection;

  const _ChamadoInfoBody({ super.key, required this.data, required this.isAdmin, required this.isInativoAdmin, required this.isUpdatingVisibility, required this.chamadoId, required this.onToggleInatividade, required this.buildAgendaSection, required this.buildCommentsSection, });

  Widget _buildStatusChips(BuildContext context, {required String status, required String prioridade}) { final ThemeData t = Theme.of(context); final TextTheme tt = t.textTheme; Color c(Color bc){ return bc.computeLuminance() > 0.5 ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9); } final Color sc = AppTheme.getStatusColor(status) ?? t.colorScheme.surfaceVariant; final Color pc = AppTheme.getPriorityColor(prioridade) ?? t.colorScheme.secondary; return Wrap( spacing: 8.0, runSpacing: 6.0, children: [ Chip( label: Text(status.toUpperCase()), labelStyle: tt.labelMedium?.copyWith( color: c(sc), fontWeight: FontWeight.w600, letterSpacing: 0.5, ), backgroundColor: sc, avatar: Icon(Icons.flag_outlined, size: 16, color: c(sc).withOpacity(0.8)), padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0), visualDensity: VisualDensity.compact, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), ), Chip( label: Text(prioridade), labelStyle: tt.labelMedium?.copyWith( color: c(pc), fontWeight: FontWeight.w600, ), backgroundColor: pc, avatar: Icon(Icons.priority_high_rounded, size: 16, color: c(pc).withOpacity(0.8)), padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0), visualDensity: VisualDensity.compact, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), ), ], ); }
  Widget _buildModernInfoTile(BuildContext context, {required IconData icon, required String label, required String value, bool isValueMultiline = false}) { final ThemeData t = Theme.of(context); final TextTheme tt = t.textTheme; final ColorScheme cs = t.colorScheme; final dVal = value.trim().isEmpty ? '-' : value.trim(); return Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ SizedBox( width: 32, child: Padding( padding: const EdgeInsets.only(top: 1.0), child: Icon( icon, color: cs.primary, size: 20, ), ) ), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ Text( label, style: tt.bodySmall?.copyWith( color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.1 ), ), SelectableText( dVal, style: tt.bodyLarge?.copyWith( height: 1.2 ), maxLines: isValueMultiline ? null : 5, textAlign: TextAlign.start, ), ], ), ), ], ), ); }
  String formatTimestampSafe(Timestamp? ts, {String format = 'dd/MM/yyyy HH:mm'}) { return ts != null ? DateFormat(format, 'pt_BR').format(ts.toDate()) : '--'; }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); final ColorScheme colorScheme = theme.colorScheme; final TextTheme textTheme = theme.textTheme;
    final String tipoSolicitante = data[kFieldTipoSolicitante] ?? 'N/I'; final String nomeSolicitante = data[kFieldNomeSolicitante] ?? 'N/I'; final String celularContato = data[kFieldCelularContato] ?? 'N/I'; final String equipamentoSolicitacao = data[kFieldEquipamentoSolicitacao] ?? 'N/I'; final String conectadoInternet = data[kFieldConectadoInternet] ?? 'N/I'; final String marcaModelo = data[kFieldMarcaModelo] ?? ''; final String patrimonio = data[kFieldPatrimonio] ?? 'N/I'; final String problemaOcorre = data[kFieldProblemaOcorre] ?? 'N/I'; final String status = data[kFieldStatus] ?? 'N/I'; final String prioridade = data[kFieldPrioridade] ?? 'N/I'; final String? tecnicoResponsavel = data[kFieldTecnicoResponsavel] as String?; final String? authUserDisplay = data[kFieldAuthUserDisplay] as String?; final String dtCriacao = formatTimestampSafe(data[kFieldDataCriacao] as Timestamp?); final Timestamp? tsAtendimento = data[kFieldDataAtendimento] as Timestamp?; final String dtAtendimento = formatTimestampSafe(tsAtendimento, format: 'dd/MM/yyyy'); final String? cidade = data[kFieldCidade] as String?; final String? instituicao = data[kFieldInstituicao] as String?; final String? cargoFuncao = data[kFieldCargoFuncao] as String?; final String? atendimentoPara = data[kFieldAtendimentoPara] as String?; final String? setorSuper = data[kFieldSetorSuper] as String?; final String? cidadeSuperintendencia = data[kFieldCidadeSuperintendencia] as String?; final String? instituicaoManual = data[kFieldInstituicaoManual] as String?; final String? equipamentoOutroDesc = data[kFieldEquipamentoOutro] as String?; final String? problemaOutroDesc = data[kFieldProblemaOutro] as String?;
    String displayInstituicao = instituicao ?? 'N/I'; if (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) { displayInstituicao = instituicaoManual; } String displayEquipamento = equipamentoSolicitacao; if (equipamentoSolicitacao == "OUTRO" && equipamentoOutroDesc != null && equipamentoOutroDesc.isNotEmpty) { displayEquipamento = "OUTRO: $equipamentoOutroDesc"; } String displayProblema = problemaOcorre; if (problemaOcorre == "OUTRO" && problemaOutroDesc != null && problemaOutroDesc.isNotEmpty) { displayProblema = "OUTRO: $problemaOutroDesc"; }

    return SingleChildScrollView( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          if (isInativoAdmin) Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Center( child: Chip( label: Text('INATIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), ), ), ),
          _buildStatusChips(context, status: status, prioridade: prioridade), const SizedBox(height: 20.0),
          Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Solicitação', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)), const SizedBox(height: 8.0), _buildModernInfoTile(context, icon: Icons.person_outline, label: 'Solicitante', value: nomeSolicitante), _buildModernInfoTile(context, icon: Icons.phone_outlined, label: 'Contato', value: celularContato), _buildModernInfoTile(context, icon: Icons.business_center_outlined, label: 'Tipo', value: tipoSolicitante), if (tipoSolicitante == 'ESCOLA') ...[ if (cidade != null) _buildModernInfoTile(context, icon: Icons.location_city_outlined, label: 'Cidade/Distrito', value: cidade), _buildModernInfoTile(context, icon: Icons.account_balance_outlined, label: 'Instituição', value: displayInstituicao), if (cargoFuncao != null) _buildModernInfoTile(context, icon: Icons.work_outline, label: 'Cargo/Função', value: cargoFuncao), if (atendimentoPara != null) _buildModernInfoTile(context, icon: Icons.support_agent_outlined, label: 'Atendimento Para', value: atendimentoPara), ], if (tipoSolicitante == 'SUPERINTENDENCIA') ...[ if (setorSuper != null) _buildModernInfoTile(context, icon: Icons.meeting_room_outlined, label: 'Setor SUPER', value: setorSuper), if (cidadeSuperintendencia != null) _buildModernInfoTile( context, icon: Icons.location_city_rounded, label: 'Cidade SUPER', value: cidadeSuperintendencia ), ], ], ), ), const SizedBox(width: 16.0),
              Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Detalhes Técnicos', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)), const SizedBox(height: 8.0), _buildModernInfoTile(context, icon: Icons.report_problem_outlined, label: 'Problema Relatado', value: displayProblema, isValueMultiline: true), _buildModernInfoTile(context, icon: Icons.devices_other_outlined, label: 'Equipamento', value: displayEquipamento), if (marcaModelo.isNotEmpty) _buildModernInfoTile(context, icon: Icons.info_outline, label: 'Marca/Modelo', value: marcaModelo), _buildModernInfoTile(context, icon: Icons.qr_code_scanner_outlined, label: 'Patrimônio', value: patrimonio), _buildModernInfoTile(context, icon: Icons.wifi_tethering_outlined, label: 'Conectado à Internet', value: conectadoInternet), if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) _buildModernInfoTile(context, icon: Icons.engineering_outlined, label: 'Técnico Responsável', value: tecnicoResponsavel), const SizedBox(height: 16.0), Text('Datas', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)), const SizedBox(height: 8.0), _buildModernInfoTile(context, icon: Icons.calendar_today_outlined, label: 'Criado em', value: dtCriacao),
                    _buildModernInfoTile(context, icon: Icons.event_available_outlined, label: 'Data de Atendimento', value: dtAtendimento),
                    if (authUserDisplay != null && authUserDisplay.isNotEmpty) _buildModernInfoTile(context, icon: Icons.person_pin_outlined, label: 'Registrado por', value: authUserDisplay), ], ), ), ], ),
          if (isAdmin) ...[ const Divider(height: 35, thickness: 1), Center( child: ElevatedButton.icon( icon: isUpdatingVisibility ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isInativoAdmin ? Icons.visibility_outlined : Icons.visibility_off_outlined), label: Text(isInativoAdmin ? "Reativar p/ Req." : "Inativar p/ Req."), style: ElevatedButton.styleFrom( backgroundColor: isInativoAdmin ? Colors.blue.shade700 : Colors.orange.shade800, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), ), onPressed: isUpdatingVisibility ? null : () => onToggleInatividade(isInativoAdmin), ), ), ],
          Divider(height: 35, thickness: 1, color: colorScheme.primary.withOpacity(0.3)), Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [ Text("Agenda de Visitas", style: textTheme.titleMedium), if (isAdmin || !isInativoAdmin) ElevatedButton.icon( icon: const Icon(Icons.edit_calendar_outlined, size: 18), label: const Text('Agendar'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onPressed: () { Navigator.push( context, MaterialPageRoute( builder: (context) => AgendamentoVisitaScreen(chamadoId: chamadoId),),); }, ), ], ), const SizedBox(height: 10), buildAgendaSection(),
          Divider(height: 35, thickness: 1, color: colorScheme.primary.withOpacity(0.3)), Padding( padding: const EdgeInsets.only(bottom: 10.0), child: Text("Comentários / Histórico", style: textTheme.titleMedium), ), buildCommentsSection(), const SizedBox(height: 20), ], ), );
  }
}