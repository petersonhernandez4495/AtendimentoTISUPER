import 'dart:io'; // Não usado diretamente, mas bom para contexto de I/O
import 'dart:typed_data'; // Não usado diretamente
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // IMPORTAÇÃO ADICIONADA para 'min'

// Removidas importações de path_provider, share_plus, open_filex se não usadas diretamente aqui
// Elas são usadas por pdf_generator.dart

import 'pdf_generator.dart' as pdfGen;
import 'agendamento_visita_screen.dart';
import 'config/theme/app_theme.dart';
import 'services/chamado_service.dart'; // Importa suas constantes e serviços

// TODO: PADRONIZE esta lista e a constante kStatusSolucionadoLocal com o resto do app.
//       O ideal é ter uma única fonte para estas constantes (ex: em chamado_service.dart ou app_theme.dart)
const List<String> kListaStatusChamadoLocal = [
  'Aberto', 'Em Andamento', 'Pendente', 'Aguardando Aprovação',
  'Aguardando Peça', 'Solucionado', 'Cancelado', 'Fechado',
  'Chamado Duplicado', 'Aguardando Equipamento', 'Atribuido para GSIOR',
  'Garantia Fabricante',
];
// TODO: PADRONIZE ESTE VALOR! Use a constante kStatusPadraoSolicionado de chamado_service.dart
const String kStatusSolucionadoLocal = kStatusPadraoSolicionado; // Usando a constante de ChamadoService

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
  bool _isFinalizandoAdmin = false;

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
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(const GetOptions(source: Source.cache));
          Map<String, dynamic>? userData;
          if (userDoc.exists && userDoc.data() != null) {
            userData = userDoc.data() as Map<String, dynamic>;
          } else {
            print("DetalhesChamadoScreen: Usuário não encontrado no cache, buscando do servidor...");
            userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(const GetOptions(source: Source.server));
            if(userDoc.exists && userDoc.data() != null) {
                userData = userDoc.data() as Map<String, dynamic>;
            }
          }
          
          if (userData != null) {
            if (userData.containsKey('role_temp')) {
              final roleValue = userData['role_temp'];
              isAdminResult = (roleValue == 'admin');
            }
          }
        } catch (e, s) {
          print("Erro fatal ao buscar role em DetalhesChamadoScreen: $e\n$s");
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

    String statusSelecionado = dadosAtuais[kFieldStatus] as String? ?? kListaStatusChamadoLocal.first;
    String prioridadeSelecionada = dadosAtuais[kFieldPrioridade] as String? ?? _listaPrioridades.first;
    String tecnicoResponsavel = dadosAtuais[kFieldTecnicoResponsavel] as String? ?? '';
    String tecnicoUid = dadosAtuais[kFieldTecnicoUid] as String? ?? ''; // Assumindo que você tenha kFieldTecnicoUid

    final solutionControllerDialog = TextEditingController(text: dadosAtuais[kFieldSolucao] as String? ?? '');
    bool showMandatoryFields = statusSelecionado.toLowerCase() == kStatusSolucionadoLocal.toLowerCase();
    DateTime? _selectedAtendimentoDate;
    final Timestamp? currentAtendimentoTs = dadosAtuais[kFieldDataAtendimento] as Timestamp?;
    if (currentAtendimentoTs != null) { _selectedAtendimentoDate = currentAtendimentoTs.toDate(); }

    if (!kListaStatusChamadoLocal.contains(statusSelecionado)) statusSelecionado = kListaStatusChamadoLocal.first;
    if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades.first;

    Future<void> _selectDate(BuildContext dlgContext, Function(DateTime?) onDateSelected) async { // Renomeado context para dlgContext
      final DateTime? picked = await showDatePicker( context: dlgContext, initialDate: _selectedAtendimentoDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)), locale: const Locale('pt', 'BR'), );
      if (picked != null && picked != _selectedAtendimentoDate) { onDateSelected(picked); }
    }

    bool? confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) { // Contexto do StatefulBuilder
            return AlertDialog(
              title: const Text('Editar Chamado'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<String>( value: statusSelecionado, items: kListaStatusChamadoLocal.map((String v) => DropdownMenuItem<String>( value: v, child: Text(v), )).toList(), onChanged: (newValue) { if (newValue != null) { setDialogState(() { statusSelecionado = newValue; showMandatoryFields = newValue.toLowerCase() == kStatusSolucionadoLocal.toLowerCase(); if (!showMandatoryFields) { solutionControllerDialog.clear(); _selectedAtendimentoDate = null;}}); }}, decoration: const InputDecoration(labelText: 'Status'), validator: (v) => v == null ? 'Selecione status' : null, ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>( value: prioridadeSelecionada, items: _listaPrioridades.map((String v) => DropdownMenuItem<String>( value: v, child: Text(v), )).toList(), onChanged: (newValue) { if (newValue != null) { setDialogState(() { prioridadeSelecionada = newValue; }); } }, decoration: const InputDecoration(labelText: 'Prioridade'), validator: (v) => v == null ? 'Selecione prioridade' : null, ),
                      const SizedBox(height: 15),
                      TextFormField( initialValue: tecnicoResponsavel, onChanged: (value) => tecnicoResponsavel = value, decoration: const InputDecoration(labelText: 'Técnico Responsável (Nome)'), ),
                      // TODO: Adicionar campo para UID do técnico se desejar editar/atribuir UID também.
                      // TextFormField( initialValue: tecnicoUid, onChanged: (value) => tecnicoUid = value, decoration: const InputDecoration(labelText: 'UID do Técnico (Opcional)'), ),
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
                    if (statusSelecionado.toLowerCase() == kStatusSolucionadoLocal.toLowerCase()) {
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
        final String? solucaoFinal = statusSelecionado.toLowerCase() == kStatusSolucionadoLocal.toLowerCase() ? solutionControllerDialog.text.trim() : null;
        final Timestamp? atendimentoTimestamp = _selectedAtendimentoDate != null ? Timestamp.fromDate(_selectedAtendimentoDate!) : null;

        await _chamadoService.atualizarDetalhesAdmin(
          chamadoId: widget.chamadoId,
          status: statusSelecionado,
          prioridade: prioridadeSelecionada,
          tecnicoResponsavel: tecnicoFinal.isEmpty ? null : tecnicoFinal,
          tecnicoUid: tecnicoUid.trim().isEmpty ? null : tecnicoUid.trim(), // Passa o UID do técnico
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
  
  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async { 
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    await pdfGen.generateAndSharePdfForTicket( context: context, chamadoId: widget.chamadoId, dadosChamado: currentData, ); 
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop(); 
    }
  }

  Future<void> _baixarPdf(Map<String, dynamic> dadosChamado) async { 
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    await pdfGen.generateAndOpenPdfForTicket( context: context, chamadoId: widget.chamadoId, dadosChamado: dadosChamado, ); 
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop(); 
    }
  }

  Future<void> _adicionarComentario() async { 
    final t = _comentarioController.text.trim(); 
    if (t.isEmpty) return; 
    final u = _auth.currentUser; 
    if (u == null) { 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faça login para adicionar um comentário.'))); 
        return; 
    } 
    setState(() { _isSendingComment = true; }); 
    try { 
        final a = u.displayName?.trim().isNotEmpty??false ? u.displayName!.trim() : (u.email??"Usuário Desconhecido"); 
        await FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('comentarios').add({ 
            'texto': t, 
            'autorNome': a, 
            'autorUid': u.uid, 
            'timestamp': FieldValue.serverTimestamp(), 
            'isSystemMessage': false, 
        }); 
        _comentarioController.clear(); 
        FocusScope.of(context).unfocus(); 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentário adicionado!'), backgroundColor: Colors.green,));
    } catch (e) { 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao adicionar comentário: $e'),backgroundColor: Colors.red,)); 
    } finally { 
        if(mounted) setState(() { _isSendingComment = false; }); 
    } 
  }

  Future<void> _toggleInatividadeAdmin(bool isInativoAtual) async { 
    if (!_isAdmin || _isUpdatingVisibility) return; 
    final bool deveAtivar = isInativoAtual; 
    final String acao = deveAtivar ? "Reativar" : "Inativar"; 
    final String labelFeedback = deveAtivar ? "Reativado" : "Inativo"; 
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final bool? confirmouAcao = await showDialog<bool>( 
        context: context, 
        barrierDismissible: false, 
        builder: (ctx) => AlertDialog( 
            title: Text('Confirmar $acao'), 
            content: Text('Deseja realmente "$acao" este chamado?\nO requerente ${deveAtivar ? "poderá" : "NÃO poderá"} visualizá-lo.'), 
            actions: [ 
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), 
                TextButton( 
                    onPressed: () => Navigator.of(ctx).pop(true), 
                    child: Text(acao, style: TextStyle(color: deveAtivar ? Colors.green : Colors.red)),
                ), 
            ], 
        ), 
    ); 

    if (confirmouAcao != true || !mounted) return; 

    setState(() { _isUpdatingVisibility = true; }); 
    try { 
        await _chamadoService.definirInatividadeAdministrativa(widget.chamadoId, !isInativoAtual); 
        if (mounted) { 
            scaffoldMessenger.showSnackBar(SnackBar( 
                content: Text('Chamado "$labelFeedback" administrativamente.'), 
                backgroundColor: Colors.green)
            ); 
        } 
    } catch (e) { 
        if (mounted) { 
            scaffoldMessenger.showSnackBar(SnackBar( 
                content: Text('Erro ao tentar $acao o chamado: $e'), 
                backgroundColor: Colors.red)
            ); 
        } 
        print("Erro ao chamar definirInatividadeAdministrativa: $e");
    } finally { 
        if (mounted) { 
            setState(() { _isUpdatingVisibility = false; }); 
        } 
    } 
  }

  Future<void> _adminFinalizarChamado(Map<String, dynamic> dadosChamadoExibido) async {
    if (!_isAdmin || !mounted) return;

    final User? adminUser = _auth.currentUser;
    if (adminUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário administrador não autenticado para esta ação.')));
      return;
    }

    final bool requerenteJaConfirmou = dadosChamadoExibido[kFieldRequerenteConfirmou] as bool? ?? false;
    if (!requerenteJaConfirmou) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguardando confirmação do requerente antes de finalizar.'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    final bool adminJaFinalizou = dadosChamadoExibido[kFieldAdminFinalizou] as bool? ?? false;
    if (adminJaFinalizou) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este chamado já foi finalizado pelo administrador.'), backgroundColor: Colors.blue)
      );
      return;
    }

    bool confirmarAdmin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Finalização Administrativa'),
        content: const Text('Você confirma a solução deste chamado e deseja finalizá-lo administrativamente? Esta ação registrará sua "assinatura" (identificação).'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(child: const Text('Confirmar e Finalizar'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (confirmarAdmin && mounted) {
      setState(() => _isFinalizandoAdmin = true );
      try {
        await _chamadoService.adminConfirmarSolucaoFinal(widget.chamadoId, adminUser);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chamado finalizado pelo administrador!'), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao finalizar chamado: ${e.toString()}'), backgroundColor: Colors.red)
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isFinalizandoAdmin = false );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdminStatusChecked) { 
      return Scaffold( 
        appBar: AppBar(title: Text('Chamado #${widget.chamadoId.substring(0, min(6, widget.chamadoId.length))}...')), 
        body: const Center(child: CircularProgressIndicator()), 
      ); 
    }
    return Scaffold(
      appBar: AppBar( 
        title: Text('Chamado #${widget.chamadoId.substring(0, min(6, widget.chamadoId.length))}...'), 
        actions: [ 
          StreamBuilder<DocumentSnapshot>( 
            stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).snapshots(), 
            builder: (context, snapshot) { 
              if (snapshot.hasData && snapshot.data!.exists) { 
                final currentData = snapshot.data!.data() as Map<String, dynamic>? ?? {}; 
                final bool isInativoAdmin = currentData[kFieldAdminInativo] ?? false; 
                bool podeInteragir = _isAdmin || !isInativoAdmin; 
                return Row( 
                  mainAxisSize: MainAxisSize.min, 
                  children: [ 
                    if (_isAdmin) 
                      IconButton( 
                        icon: const Icon(Icons.edit_note_outlined), 
                        tooltip: 'Editar Chamado (Admin)', 
                        onPressed: _isUpdatingVisibility ? null : () => _mostrarDialogoEdicao(currentData), 
                      ), 
                    if (podeInteragir) ...[ 
                      IconButton( 
                        icon: const Icon(Icons.share_outlined), 
                        tooltip: 'Compartilhar PDF do Chamado', 
                        onPressed: () => _handlePdfShare(currentData), 
                      ), 
                      IconButton( 
                        icon: const Icon(Icons.download_outlined), 
                        tooltip: 'Baixar/Abrir PDF do Chamado', 
                        onPressed: () => _baixarPdf(currentData), 
                      ), 
                    ]
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
              stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).snapshots(), 
              builder: (context, snapshotChamado) { 
                if (snapshotChamado.hasError) { return Center(child: Text('Erro ao carregar chamado: ${snapshotChamado.error}')); } 
                if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } 
                if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado.')); } 
                
                final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>; 
                final bool isInativoAdmin = data[kFieldAdminInativo] ?? false;
                
                return _ChamadoInfoBody( 
                  key: ValueKey(widget.chamadoId + (data[kFieldDataAtualizacao]?.toString() ?? '')), 
                  data: data, 
                  isAdmin: _isAdmin, 
                  isInativoAdmin: isInativoAdmin, 
                  isUpdatingVisibility: _isUpdatingVisibility,
                  isFinalizandoAdmin: _isFinalizandoAdmin, 
                  chamadoId: widget.chamadoId, 
                  onToggleInatividade: _toggleInatividadeAdmin, 
                  onAdminFinalizarChamado: () => _adminFinalizarChamado(data), 
                  buildAgendaSection: _buildAgendaSection, 
                  buildCommentsSection: _buildCommentsSection, 
                ); 
              }, 
            ), 
          ),
          StreamBuilder<DocumentSnapshot>( 
            stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).snapshots(), 
            builder: (context, snapshot) { 
              if (!snapshot.hasData || snapshot.hasError || !snapshot.data!.exists) { return const SizedBox.shrink(); } 
              final bool isInativoAdmin = (snapshot.data!.data() as Map<String, dynamic>?)?[kFieldAdminInativo] ?? false; 
              final bool podeComentar = _isAdmin || !isInativoAdmin; 
              return AnimatedSwitcher( 
                duration: const Duration(milliseconds: 300), 
                transitionBuilder: (Widget child, Animation<double> animation) { 
                  return SizeTransition(sizeFactor: animation, child: child); 
                }, 
                child: podeComentar 
                  ? _buildCommentInputArea() 
                  : Container( 
                      key: const ValueKey('comentario_inativo'), 
                      padding: const EdgeInsets.all(12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8), 
                      color: Theme.of(context).colorScheme.surfaceContainerLowest, 
                      child: Center( child: Text( 'Comentários desabilitados (Chamado Inativo)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),)),
                    ),
              ); 
            } 
          ), 
        ], 
      ), 
    );
  }

  Widget _buildAgendaSection() { 
    return StreamBuilder<QuerySnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('visitas_agendadas').orderBy('dataHoraAgendada', descending: false).limit(10).snapshots(), builder: (context, snapshotVisitas) { if (snapshotVisitas.hasError) { return Text("Erro ao carregar agenda: ${snapshotVisitas.error}"); } if (snapshotVisitas.connectionState == ConnectionState.waiting) { return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))); } if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhuma visita agendada para este chamado.")), ); } return Column( children: snapshotVisitas.data!.docs.map((docVisita) { final dataVisita = docVisita.data() as Map<String, dynamic>; final Timestamp? ts = dataVisita['dataHoraAgendada'] as Timestamp?; final String dtHr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(ts.toDate()) : 'Data Inválida'; final String tec = dataVisita['tecnicoNome'] as String? ?? 'N/D'; final String st = dataVisita['statusVisita'] as String? ?? 'N/I'; final String obs = dataVisita['observacoes'] as String? ?? ''; return Card( margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: ListTile( leading: Icon(_getVisitaStatusIcon(st), color: _getVisitaStatusColor(st), size: 32), title: Text("Agendado: $dtHr", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const SizedBox(height: 3), if (tec != 'N/D') Text("Técnico: $tec"), if (obs.isNotEmpty) Text("Obs: $obs", style: const TextStyle(fontStyle: FontStyle.italic)), Text("Status da Visita: $st", style: const TextStyle(fontWeight: FontWeight.w500)), ]), dense: true, ), ); }).toList(), ); }, ); 
  }
  IconData _getVisitaStatusIcon(String? s) { 
    switch (s?.toLowerCase()) { case 'agendada': return Icons.event_available_outlined; case 'realizada': return Icons.check_circle_outline; case 'cancelada': return Icons.cancel_outlined; case 'reagendada': return Icons.history_outlined; default: return Icons.help_outline; } 
  }
  Color _getVisitaStatusColor(String? s) { 
    switch (s?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; } 
  }
  Widget _buildCommentsSection() { 
    return StreamBuilder<QuerySnapshot>( stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('comentarios').orderBy('timestamp', descending: true).limit(50).snapshots(), builder: (context, snapshot) { if (snapshot.hasError) { return const Padding(padding: EdgeInsets.all(8.0), child: Text("Erro ao carregar comentários.")); } if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); } if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhum comentário ou histórico para este chamado."))); } return Column( children: snapshot.data!.docs.map((doc) { final d = doc.data() as Map<String, dynamic>; final t = d['texto'] ?? ''; final a = d['autorNome'] ?? 'Desconhecido'; final ts = d['timestamp'] as Timestamp?; final dtHr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(ts.toDate()) : '--'; final sys = d['isSystemMessage'] ?? false; return Card( margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), elevation: sys ? 0.2 : 0.5, 
  color: sys ? Colors.blueGrey.shade50.withOpacity(0.6) : Theme.of(context).cardTheme.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), child: ListTile( title: Text(t, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: sys ? FontStyle.italic : null, color: sys ? Colors.blueGrey.shade800 : null)), subtitle: Padding( padding: const EdgeInsets.only(top: 4.0), child: Text( sys ? "Sistema - $dtHr" : "$a - $dtHr", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sys ? Colors.blueGrey.shade700 : null))), dense: true, contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12), 
 ), ); }).toList(), ); }, ); 
  }
  Widget _buildCommentInputArea() { 
    final th = Theme.of(context); 
    final cs = th.colorScheme; 
    return Container( 
        key: const ValueKey('comentario_ativo'), 
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0), 
        decoration: BoxDecoration( 
            color: cs.surfaceContainerLowest, 
            boxShadow: [ 
                BoxShadow( 
                    color: th.shadowColor.withOpacity(0.1), 
                    spreadRadius: 0, 
                    blurRadius: 4, 
                    offset: const Offset(0, -1), 
                ), 
            ], 
        ), 
        child: Row( 
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [ 
                Expanded( 
                    child: TextField( 
                        controller: _comentarioController, 
                        decoration: InputDecoration( 
                            hintText: 'Adicionar comentário...', 
                            isDense: true, 
                            border: OutlineInputBorder( 
                                borderRadius: BorderRadius.circular(25.0), 
                                borderSide: BorderSide.none 
                            ), 
                            filled: true, 
                            fillColor: cs.surfaceContainerHighest, 
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0), 
                        ), 
                        textCapitalization: TextCapitalization.sentences, 
                        minLines: 1, 
                        maxLines: 4, 
                        enabled: !_isSendingComment, 
                        onSubmitted: (_) => _isSendingComment ? null : _adicionarComentario(), 
                        textInputAction: TextInputAction.send, 
                    ), 
                ), 
                const SizedBox(width: 8.0), 
                IconButton( 
                    icon: _isSendingComment 
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) 
                        : Icon(Icons.send_rounded, color: cs.primary), 
                    onPressed: _isSendingComment ? null : _adicionarComentario, 
                    tooltip: 'Enviar Comentário', 
                    style: IconButton.styleFrom( 
                        backgroundColor: cs.primaryContainer, 
                        disabledBackgroundColor: cs.onSurface.withOpacity(0.12), 
                    ), 
                ), 
            ]
        ), 
    ); 
  }
}

class _ChamadoInfoBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  final bool isInativoAdmin;
  final bool isUpdatingVisibility;
  final bool isFinalizandoAdmin;
  final String chamadoId;
  final Function(bool) onToggleInatividade;
  final VoidCallback onAdminFinalizarChamado;
  final Widget Function() buildAgendaSection;
  final Widget Function() buildCommentsSection;

  const _ChamadoInfoBody({ 
    super.key, 
    required this.data, 
    required this.isAdmin, 
    required this.isInativoAdmin, 
    required this.isUpdatingVisibility,
    required this.isFinalizandoAdmin,
    required this.chamadoId, 
    required this.onToggleInatividade, 
    required this.onAdminFinalizarChamado,
    required this.buildAgendaSection, 
    required this.buildCommentsSection, 
  });

  Widget _buildStatusChips(BuildContext context, {required String status, required String prioridade}) {
    final ThemeData t = Theme.of(context); 
    final TextTheme tt = t.textTheme; 
    Color c(Color bc){ return bc.computeLuminance() > 0.5 ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9); } 
    final Color sc = AppTheme.getStatusColor(status) ?? t.colorScheme.surfaceVariant; 
    final Color pc = AppTheme.getPriorityColor(prioridade) ?? t.colorScheme.secondary; 
    return Wrap( spacing: 8.0, runSpacing: 6.0, children: [ 
        Chip( label: Text(status.toUpperCase()), labelStyle: tt.labelMedium?.copyWith( color: c(sc), fontWeight: FontWeight.w600, letterSpacing: 0.5, ), backgroundColor: sc, avatar: Icon(Icons.flag_outlined, size: 16, color: c(sc).withOpacity(0.8)), padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0), visualDensity: VisualDensity.compact, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), ), 
        Chip( label: Text(prioridade), labelStyle: tt.labelMedium?.copyWith( color: c(pc), fontWeight: FontWeight.w600, ), backgroundColor: pc, avatar: Icon(Icons.priority_high_rounded, size: 16, color: c(pc).withOpacity(0.8)), padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0), visualDensity: VisualDensity.compact, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), ), 
    ], ); 
  }
  Widget _buildModernInfoTile(BuildContext context, {required IconData icon, required String label, required String value, bool isValueMultiline = false}) {
    final ThemeData t = Theme.of(context); 
    final TextTheme tt = t.textTheme; 
    final ColorScheme cs = t.colorScheme; 
    final dVal = value.trim().isEmpty ? '--' : value.trim(); 
    return Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ SizedBox( width: 32, child: Padding( padding: const EdgeInsets.only(top: 1.0), child: Icon( icon, color: cs.primary, size: 20, ), ) ), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ Text( label, style: tt.bodySmall?.copyWith( color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.1 ), ), SelectableText( dVal, style: tt.bodyLarge?.copyWith( height: 1.2 ), maxLines: isValueMultiline ? null : 5, textAlign: TextAlign.start, ), ], ), ), ], ), ); 
  }
  String formatTimestampSafe(Timestamp? ts, {String format = 'dd/MM/yyyy HH:mm'}) { 
    return ts != null ? DateFormat(format, 'pt_BR').format(ts.toDate()) : '--'; 
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); 
    final ColorScheme colorScheme = theme.colorScheme; 
    final TextTheme textTheme = theme.textTheme;
    
    final String tipoSolicitante = data[kFieldTipoSolicitante]?.toString() ?? 'N/I'; 
    final String nomeSolicitante = data[kFieldNomeSolicitante]?.toString() ?? 'N/I'; 
    final String celularContato = data[kFieldCelularContato]?.toString() ?? 'N/I'; 
    final String equipamentoSolicitacao = data[kFieldEquipamentoSolicitacao]?.toString() ?? 'N/I'; 
    final String conectadoInternet = data[kFieldConectadoInternet]?.toString() ?? 'N/I'; 
    final String marcaModelo = data[kFieldMarcaModelo]?.toString() ?? ''; 
    final String patrimonio = data[kFieldPatrimonio]?.toString() ?? 'N/I'; 
    final String problemaOcorre = data[kFieldProblemaOcorre]?.toString() ?? 'N/I'; 
    final String status = data[kFieldStatus]?.toString() ?? 'N/I'; 
    final String prioridade = data[kFieldPrioridade]?.toString() ?? 'N/I'; 
    final String? tecnicoResponsavel = data[kFieldTecnicoResponsavel] as String?; 
    final String? authUserDisplay = data[kFieldAuthUserDisplay] as String?; 
    final String dtCriacao = formatTimestampSafe(data[kFieldDataCriacao] as Timestamp?); 
    final Timestamp? tsAtendimento = data[kFieldDataAtendimento] as Timestamp?; 
    final String dtAtendimento = formatTimestampSafe(tsAtendimento, format: 'dd/MM/yyyy'); 
    final String? cidade = data[kFieldCidade] as String?; 
    final String? instituicao = data[kFieldInstituicao] as String?; 
    final String? cargoFuncao = data[kFieldCargoFuncao] as String?; 
    final String? atendimentoPara = data[kFieldAtendimentoPara] as String?; 
    final String? setorSuper = data[kFieldSetorSuper] as String?; 
    final String? cidadeSuperintendencia = data[kFieldCidadeSuperintendencia] as String?; 
    final String? instituicaoManual = data[kFieldInstituicaoManual] as String?; 
    final String? equipamentoOutroDesc = data[kFieldEquipamentoOutro] as String?; 
    final String? problemaOutroDesc = data[kFieldProblemaOutro] as String?;
    final String? solucao = data[kFieldSolucao] as String?;
    final bool requerenteConfirmou = data[kFieldRequerenteConfirmou] as bool? ?? false;
    final String dtConfirmacaoReq = formatTimestampSafe(data[kFieldRequerenteConfirmouData] as Timestamp?);
    // Tenta buscar o nome do requerente que confirmou (você precisaria salvar isso no Firestore)
    // Por enquanto, um placeholder se não tiver essa informação extra.
    final String? nomeRequerenteConfirmador = data['nomeRequerenteConfirmador'] as String? ?? 
                                           (data[kFieldRequerenteConfirmouUid] != null ? 'Solicitante (UID: ${ (data[kFieldRequerenteConfirmouUid] as String).substring(0, min(6, (data[kFieldRequerenteConfirmouUid] as String).length)) }...)' : null);

    final bool adminFinalizou = data[kFieldAdminFinalizou] as bool? ?? false;
    final String? adminFinalizouNome = data[kFieldAdminFinalizouNome] as String?;
    final String adminFinalizouDataStr = formatTimestampSafe(data[kFieldAdminFinalizouData] as Timestamp?);

    String displayInstituicao = instituicao ?? 'N/I'; 
    if (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) { displayInstituicao = instituicaoManual; } 
    String displayEquipamento = equipamentoSolicitacao; 
    if (equipamentoSolicitacao == "OUTRO" && equipamentoOutroDesc != null && equipamentoOutroDesc.isNotEmpty) { displayEquipamento = "OUTRO: $equipamentoOutroDesc"; } 
    String displayProblema = problemaOcorre; 
    if (problemaOcorre == "OUTRO" && problemaOutroDesc != null && problemaOutroDesc.isNotEmpty) { displayProblema = "OUTRO: $problemaOutroDesc"; }

    final bool podeAdminFinalizar = isAdmin && 
                                  status.toLowerCase() == kStatusSolucionadoLocal.toLowerCase() && 
                                  requerenteConfirmou && 
                                  !adminFinalizou &&
                                  !isInativoAdmin;

    return SingleChildScrollView( 
      padding: const EdgeInsets.all(16.0), 
      child: Column( 
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: <Widget>[
          if (isInativoAdmin) Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Center( child: Chip( label: Text('CHAMADO INATIVO (APENAS ADMINS VÊEM)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), ), ), ),
          _buildStatusChips(context, status: status, prioridade: prioridade), 
          const SizedBox(height: 20.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Solicitação', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                    const SizedBox(height: 8.0),
                    _buildModernInfoTile(context, icon: Icons.person_outline, label: 'Solicitante', value: nomeSolicitante),
                    _buildModernInfoTile(context, icon: Icons.phone_outlined, label: 'Contato', value: celularContato),
                    _buildModernInfoTile(context, icon: Icons.business_center_outlined, label: 'Tipo', value: tipoSolicitante),
                    if (tipoSolicitante == 'ESCOLA') ...[
                      if (cidade != null) _buildModernInfoTile(context, icon: Icons.location_city_outlined, label: 'Cidade/Distrito', value: cidade),
                      _buildModernInfoTile(context, icon: Icons.account_balance_outlined, label: 'Instituição', value: displayInstituicao),
                      if (cargoFuncao != null) _buildModernInfoTile(context, icon: Icons.work_outline, label: 'Cargo/Função', value: cargoFuncao),
                      if (atendimentoPara != null) _buildModernInfoTile(context, icon: Icons.support_agent_outlined, label: 'Atendimento Para', value: atendimentoPara),
                    ],
                    if (tipoSolicitante == 'SUPERINTENDENCIA') ...[
                      if (setorSuper != null) _buildModernInfoTile(context, icon: Icons.meeting_room_outlined, label: 'Setor SUPER', value: setorSuper),
                      if (cidadeSuperintendencia != null) _buildModernInfoTile(context, icon: Icons.location_city_rounded, label: 'Cidade SUPER', value: cidadeSuperintendencia),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detalhes Técnicos', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                    const SizedBox(height: 8.0),
                    _buildModernInfoTile(context, icon: Icons.report_problem_outlined, label: 'Problema Relatado', value: displayProblema, isValueMultiline: true),
                    _buildModernInfoTile(context, icon: Icons.devices_other_outlined, label: 'Equipamento', value: displayEquipamento),
                    if (marcaModelo.isNotEmpty) _buildModernInfoTile(context, icon: Icons.info_outline, label: 'Marca/Modelo', value: marcaModelo),
                    _buildModernInfoTile(context, icon: Icons.qr_code_scanner_outlined, label: 'Patrimônio', value: patrimonio),
                    _buildModernInfoTile(context, icon: Icons.wifi_tethering_outlined, label: 'Conectado à Internet', value: conectadoInternet),
                    if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) _buildModernInfoTile(context, icon: Icons.engineering_outlined, label: 'Técnico Responsável', value: tecnicoResponsavel),
                    const SizedBox(height: 16.0),
                    Text('Datas', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                    const SizedBox(height: 8.0),
                    _buildModernInfoTile(context, icon: Icons.calendar_today_outlined, label: 'Criado em', value: dtCriacao),
                    _buildModernInfoTile(context, icon: Icons.event_available_outlined, label: 'Data de Atendimento', value: dtAtendimento),
                    if (authUserDisplay != null && authUserDisplay.isNotEmpty) _buildModernInfoTile(context, icon: Icons.person_pin_outlined, label: 'Registrado por', value: authUserDisplay),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (solucao != null && solucao.isNotEmpty) ...[
            Text('Solução Apresentada', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: SelectableText(solucao, style: textTheme.bodyMedium),
            ),
            const SizedBox(height: 16.0),
          ],

          if (requerenteConfirmou) ...[
            Text('Confirmação do Requerente', style: textTheme.titleMedium?.copyWith(color: Colors.green.shade700)),
            const SizedBox(height: 8.0),
            _buildModernInfoTile(context, icon: Icons.check_circle_outline, label: 'Status', value: 'Solução Aceita pelo Requerente'),
            if (nomeRequerenteConfirmador != null)
                 _buildModernInfoTile(context, icon: Icons.how_to_reg_outlined, label: 'Confirmado por', value: nomeRequerenteConfirmador),
            _buildModernInfoTile(context, icon: Icons.event_note_outlined, label: 'Data da Confirmação', value: dtConfirmacaoReq), // Ícone alternativo
            const SizedBox(height: 16.0),
          ],
          
          if (isAdmin) ...[
            if (podeAdminFinalizar) ...[
              const Divider(height: 25, thickness: 1),
              Center(
                child: isFinalizandoAdmin 
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
                      label: const Text('Finalizar Chamado (Admin)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: onAdminFinalizarChamado,
                    ),
              ),
              const SizedBox(height: 10),
            ] else if (adminFinalizou) ...[
              const Divider(height: 25, thickness: 1),
              Text('Finalização Administrativa', style: textTheme.titleMedium?.copyWith(color: Colors.blue.shade800)),
              const SizedBox(height: 8.0),
               _buildModernInfoTile(context, icon: Icons.verified_user_rounded, label: 'Status', value: 'Chamado Finalizado pelo Admin'),
              if (adminFinalizouNome != null)
                 _buildModernInfoTile(context, icon: Icons.person_search_rounded, label: 'Finalizado por', value: adminFinalizouNome),
              _buildModernInfoTile(context, icon: Icons.event_note_outlined, label: 'Data da Finalização', value: adminFinalizouDataStr), // Ícone alternativo
              const SizedBox(height: 16.0),
            ],
          ],
          
          if (isAdmin && !isUpdatingVisibility) ...[ // Botão de inativar/reativar
            const Divider(height: 35, thickness: 1), 
            Center( 
              child: ElevatedButton.icon( 
                icon: Icon(isInativoAdmin ? Icons.visibility_outlined : Icons.visibility_off_outlined), 
                label: Text(isInativoAdmin ? "Reativar p/ Req." : "Inativar p/ Req."), 
                style: ElevatedButton.styleFrom( 
                    backgroundColor: isInativoAdmin ? Colors.blue.shade700 : Colors.orange.shade800, 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
                ), 
                onPressed: () => onToggleInatividade(isInativoAdmin), 
              ), 
            ), 
          ] else if (isUpdatingVisibility) ... [
             const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          ],
          
          Divider(height: 35, thickness: 1, color: colorScheme.primary.withOpacity(0.3)), 
          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [ Text("Agenda de Visitas", style: textTheme.titleMedium), if (isAdmin || !isInativoAdmin) ElevatedButton.icon( icon: const Icon(Icons.edit_calendar_outlined, size: 18), label: const Text('Agendar'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onPressed: () { Navigator.push( context, MaterialPageRoute( builder: (context) => AgendamentoVisitaScreen(chamadoId: chamadoId),),); }, ), ], ), 
          const SizedBox(height: 10), 
          buildAgendaSection(),
          Divider(height: 35, thickness: 1, color: colorScheme.primary.withOpacity(0.3)), 
          Padding( padding: const EdgeInsets.only(bottom: 10.0), child: Text("Comentários / Histórico", style: textTheme.titleMedium), ), 
          buildCommentsSection(), 
          const SizedBox(height: 20), 
        ], 
      ), 
    );
  }
}