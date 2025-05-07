// lib/detalhes_chamado_screen.dart (Código Completo Corrigido - v2)

import 'dart:math';
import 'dart:typed_data';
import 'dart:io'; // Para File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Para getTemporaryDirectory
import 'package:open_filex/open_filex.dart'; // Para OpenFilex
import 'package:pdf/pdf.dart'; // Para PdfPageFormat
import 'package:printing/printing.dart'; // Para Printing

import 'agendamento_visita_screen.dart';
import '../pdf_generator.dart' as pdfGen;
import '../config/theme/app_theme.dart';
import '../services/chamado_service.dart';

const String kFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador';

const double kSpacingXXSmall = 2.0;
const double kSpacingXSmall = 4.0;
const double kSpacingSmall = 8.0;
const double kSpacingMedium = 12.0;
const double kSpacingLarge = 16.0;
const double kSpacingXLarge = 20.0;

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
  final List<String> _listaStatusEdicao = [
    'Aberto', 'Em Andamento', 'Pendente', 'Aguardando Aprovação',
    'Aguardando Peça', kStatusPadraoSolicionado, 'Cancelado', 'Fechado',
    'Chamado Duplicado', 'Aguardando Equipamento', 'Atribuido para GSIOR',
    'Garantia Fabricante',
  ];

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
      print("DetalhesChamadoScreen: Erro ao buscar URL da assinatura para $userId: $e");
    }
    return null;
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
            userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(const GetOptions(source: Source.server));
            if(userDoc.exists && userDoc.data() != null) {
                userData = userDoc.data() as Map<String, dynamic>;
            }
          }
          if (userData != null && userData.containsKey('role_temp')) {
              isAdminResult = (userData['role_temp'] == 'admin');
          }
        } catch (e) { /* erro */ }
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

    String statusSelecionado = dadosAtuais[kFieldStatus] as String? ?? _listaStatusEdicao.first;
    String prioridadeSelecionada = dadosAtuais[kFieldPrioridade] as String? ?? _listaPrioridades.first;
    String tecnicoResponsavel = dadosAtuais[kFieldTecnicoResponsavel] as String? ?? '';
    String tecnicoUid = dadosAtuais[kFieldTecnicoUid] as String? ?? '';

    final solutionControllerDialog = TextEditingController(text: dadosAtuais[kFieldSolucao] as String? ?? '');
    bool showMandatoryFields = statusSelecionado.toLowerCase() == kStatusPadraoSolicionado.toLowerCase();
    DateTime? _selectedAtendimentoDate;
    final Timestamp? currentAtendimentoTs = dadosAtuais[kFieldDataAtendimento] as Timestamp?;
    if (currentAtendimentoTs != null) { _selectedAtendimentoDate = currentAtendimentoTs.toDate(); }

    if (!_listaStatusEdicao.contains(statusSelecionado)) statusSelecionado = _listaStatusEdicao.first;
    if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades.first;

    Future<void> _selectDate(BuildContext dlgContext, Function(DateTime?) onDateSelected) async {
      final DateTime? picked = await showDatePicker( context: dlgContext, initialDate: _selectedAtendimentoDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)), locale: const Locale('pt', 'BR'), );
      if (picked != null && picked != _selectedAtendimentoDate) {
        onDateSelected(picked);
      }
    }

    bool? confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Chamado'),
              contentPadding: const EdgeInsets.all(kSpacingMedium),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<String>( value: statusSelecionado, items: _listaStatusEdicao.map((String v) => DropdownMenuItem<String>( value: v, child: Text(v), )).toList(), onChanged: (newValue) { if (newValue != null) { setDialogState(() { statusSelecionado = newValue; showMandatoryFields = newValue.toLowerCase() == kStatusPadraoSolicionado.toLowerCase(); if (!showMandatoryFields) { solutionControllerDialog.clear(); _selectedAtendimentoDate = null;}}); }}, decoration: const InputDecoration(labelText: 'Status', isDense: true), validator: (v) => v == null ? 'Selecione status' : null, ),
                      const SizedBox(height: kSpacingSmall),
                      DropdownButtonFormField<String>( value: prioridadeSelecionada, items: _listaPrioridades.map((String v) => DropdownMenuItem<String>( value: v, child: Text(v), )).toList(), onChanged: (newValue) { if (newValue != null) { setDialogState(() { prioridadeSelecionada = newValue; }); } }, decoration: const InputDecoration(labelText: 'Prioridade', isDense: true), validator: (v) => v == null ? 'Selecione prioridade' : null, ),
                      const SizedBox(height: kSpacingSmall),
                      TextFormField( initialValue: tecnicoResponsavel, onChanged: (value) => tecnicoResponsavel = value, decoration: const InputDecoration(labelText: 'Técnico Responsável (Nome)', isDense: true), ),
                      const SizedBox(height: kSpacingXSmall),
                      TextFormField( initialValue: tecnicoUid, onChanged: (value) => tecnicoUid = value, decoration: const InputDecoration(labelText: 'UID do Técnico (Opcional)', isDense: true), ),
                      const SizedBox(height: kSpacingSmall),
                      Visibility(
                        visible: showMandatoryFields,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: kSpacingMedium),
                            Text("Detalhes da Solução (Obrigatório)", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: kSpacingXSmall),
                            TextFormField( controller: solutionControllerDialog, decoration: const InputDecoration( labelText: 'Descrição da Solução', hintText: 'Digite os detalhes...', border: OutlineInputBorder(), alignLabelWithHint: true, isDense: true ), maxLines: 3, validator: (value) { if (showMandatoryFields && (value == null || value.trim().isEmpty)) { return 'Descrição obrigatória para solucionar.'; } return null; },),
                            const SizedBox(height: kSpacingSmall),
                            Text("Data de Atendimento (Obrigatório)", style: theme.textTheme.labelMedium),
                            const SizedBox(height: kSpacingXSmall/2),
                            Row( children: [
                              Expanded( child: OutlinedButton.icon( icon: const Icon(Icons.calendar_today, size: 18), label: Text( _selectedAtendimentoDate == null ? 'Selecionar Data' : dateFormat.format(_selectedAtendimentoDate!), ), onPressed: () { _selectDate(dialogContext, (pickedDate) { setDialogState(() { _selectedAtendimentoDate = pickedDate; }); }); }, style: OutlinedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.centerLeft, foregroundColor: _selectedAtendimentoDate == null ? theme.hintColor : theme.textTheme.bodyLarge?.color, side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5))),),),
                              if (_selectedAtendimentoDate != null) IconButton( icon: const Icon(Icons.clear, size: 20), tooltip: "Limpar Data", onPressed: () { setDialogState(() { _selectedAtendimentoDate = null; }); }, color: theme.colorScheme.error, constraints: const BoxConstraints(), padding: const EdgeInsets.all(kSpacingXSmall),),
                            ],),
                            const SizedBox(height: kSpacingSmall),
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
                    if (statusSelecionado.toLowerCase() == kStatusPadraoSolicionado.toLowerCase()) {
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
      final User? usuarioLogado = _auth.currentUser;
      if (usuarioLogado == null) {
        if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Erro: Sessão de usuário inválida.'), backgroundColor: Colors.red,));
        solutionControllerDialog.dispose();
        return;
      }

      try {
        final tecnicoFinal = tecnicoResponsavel.trim();
        final String? solucaoFinal = statusSelecionado.toLowerCase() == kStatusPadraoSolicionado.toLowerCase() ? solutionControllerDialog.text.trim() : null;
        final Timestamp? atendimentoTimestamp = _selectedAtendimentoDate != null ? Timestamp.fromDate(_selectedAtendimentoDate!) : null;

        await _chamadoService.atualizarDetalhesAdmin(
          chamadoId: widget.chamadoId,
          status: statusSelecionado,
          adminUser: usuarioLogado,
          prioridade: prioridadeSelecionada,
          tecnicoResponsavel: tecnicoFinal.isEmpty ? null : tecnicoFinal,
          tecnicoUid: tecnicoUid.trim().isEmpty ? null : tecnicoUid.trim(),
          solucao: solucaoFinal,
          dataAtendimento: atendimentoTimestamp,
        );
        if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Chamado atualizado!'), backgroundColor: Colors.green,));
      } catch (e) {
        if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao atualizar: ${e.toString()}'), backgroundColor: Colors.red,));
      }
    }
    solutionControllerDialog.dispose();
  }

  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Usar um BuildContext que sabemos que ainda estará válido para o diálogo
    BuildContext currentContext = context;

    showDialog(
      context: currentContext, // Usar o contexto salvo
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
          canPop: false,
          child: const Center(child: CircularProgressIndicator())
      ),
    );

    String? adminSigUrl;
    final String? adminSolucionouUid = currentData[kFieldSolucaoPorUid] as String?;
    if (adminSolucionouUid != null && adminSolucionouUid.isNotEmpty) {
      adminSigUrl = await _getSignatureUrlFromFirestore(adminSolucionouUid);
    }

    String? requesterSigUrl;
    final bool requerenteConfirmou = currentData[kFieldRequerenteConfirmou] as bool? ?? false;
    final String? uidDoRequerenteQueConfirmou = currentData[kFieldRequerenteConfirmouUid] as String?;
    if (requerenteConfirmou && uidDoRequerenteQueConfirmou != null && uidDoRequerenteQueConfirmou.isNotEmpty) {
      requesterSigUrl = await _getSignatureUrlFromFirestore(uidDoRequerenteQueConfirmou);
    }

    Uint8List? pdfBytes;
    try {
      pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
        chamadoId: widget.chamadoId,
        dadosChamado: currentData,
        adminSignatureUrl: adminSigUrl,
        requesterSignatureUrl: requesterSigUrl,
      );
    } catch (e) {
      // Fecha diálogo de progresso em caso de erro
      if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
        Navigator.of(currentContext, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF para compartilhamento: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Fecha diálogo de progresso ANTES de compartilhar
    if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
      Navigator.of(currentContext, rootNavigator: true).pop();
    }

    if (pdfBytes != null && mounted) {
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: 'chamado_${widget.chamadoId.substring(0,6)}.pdf');
      } catch (e) {
         if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Erro ao compartilhar PDF: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else if (mounted) {
       scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Falha ao gerar PDF para compartilhamento.'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _baixarPdf(Map<String, dynamic> dadosChamado) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContext = context; // Salva o contexto

    // Mostrar indicador de progresso
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator())),
    );

    Uint8List? pdfBytes;
    try {
      String? adminSigUrl;
      final String? adminSolucionouUid = dadosChamado[kFieldSolucaoPorUid] as String?;
      if (adminSolucionouUid != null && adminSolucionouUid.isNotEmpty) {
        adminSigUrl = await _getSignatureUrlFromFirestore(adminSolucionouUid);
      }

      String? requesterSigUrl;
      final bool requerenteConfirmou = dadosChamado[kFieldRequerenteConfirmou] as bool? ?? false;
      final String? uidDoRequerenteQueConfirmou = dadosChamado[kFieldRequerenteConfirmouUid] as String?;
      if (requerenteConfirmou && uidDoRequerenteQueConfirmou != null && uidDoRequerenteQueConfirmou.isNotEmpty) {
        requesterSigUrl = await _getSignatureUrlFromFirestore(uidDoRequerenteQueConfirmou);
      }

      pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
        chamadoId: widget.chamadoId,
        dadosChamado: dadosChamado,
        adminSignatureUrl: adminSigUrl,
        requesterSignatureUrl: requesterSigUrl,
      );

    } catch (e) {
       // Fecha diálogo de progresso em caso de erro
      if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
         Navigator.of(currentContext, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

     // Fecha diálogo de progresso APÓS geração bem-sucedida
    if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
       Navigator.of(currentContext, rootNavigator: true).pop();
    }

    // Mostra diálogo de opções
    if (pdfBytes != null && mounted) {
      showDialog(
        context: context, // Usa o contexto original do State para mostrar o novo diálogo
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Opções do PDF'),
            content: const Text('O que você gostaria de fazer?'),
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
                      _imprimirPdf(pdfBytes!);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Abrir / Visualizar'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _abrirPdfLocalmente(pdfBytes!, widget.chamadoId);
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
    } else if (mounted) {
       scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Falha ao gerar PDF.'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _imprimirPdf(Uint8List pdfBytes) async {
    if(!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Adicionado para mostrar erros
    try {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
    } catch (e) {
      if(mounted) {
        scaffoldMessenger.showSnackBar( // Usa o scaffoldMessenger
          SnackBar(content: Text('Erro ao preparar impressão: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirPdfLocalmente(Uint8List pdfBytes, String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContextForDialog = context; // Salva contexto para diálogo de progresso

    showDialog(
      context: currentContextForDialog,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator())),
    );

    try {
      final outputDir = await getTemporaryDirectory();
      final filename = 'chamado_${chamadoId.substring(0, min(6, chamadoId.length))}.pdf';
      final outputFile = File("${outputDir.path}/$filename");
      await outputFile.writeAsBytes(pdfBytes);

      // Fecha diálogo de progresso ANTES de tentar abrir
      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
          Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }

      final result = await OpenFilex.open(outputFile.path);

      if (result.type != ResultType.done && mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Não foi possível abrir o PDF: ${result.message}')),
          );
      }
    } catch(e) {
        // Fecha diálogo de progresso em caso de erro
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
        const SnackBar(content: Text('Aguardando confirmação do requerente antes de arquivar.'), backgroundColor: Colors.orange)
      );
      return;
    }
    final String statusAtual = dadosChamadoExibido[kFieldStatus] as String? ?? '';
    if (statusAtual.toLowerCase() != kStatusPadraoSolicionado.toLowerCase()){
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('O chamado precisa estar "$kStatusPadraoSolicionado" para ser arquivado.'), backgroundColor: Colors.orange)
      );
      return;
    }
    final bool adminJaFinalizou = dadosChamadoExibido[kFieldAdminFinalizou] as bool? ?? false;
    if (adminJaFinalizou) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este chamado já foi arquivado.'), backgroundColor: Colors.blue)
      );
      return;
    }
    bool confirmarAdmin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Arquivamento do Chamado'),
        content: const Text('Deseja mover este chamado para o arquivo? Esta ação registrará sua identificação como o responsável pelo arquivamento.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(child: const Text('Confirmar e Arquivar'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (confirmarAdmin && mounted) {
      setState(() => _isFinalizandoAdmin = true );
      try {
        await _chamadoService.adminConfirmarSolucaoFinal(widget.chamadoId, adminUser);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chamado arquivado com sucesso!'), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao arquivar chamado: ${e.toString()}'), backgroundColor: Colors.red)
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
                        onPressed: _isUpdatingVisibility || _isFinalizandoAdmin ? null : () => _mostrarDialogoEdicao(currentData),
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
                if (snapshotChamado.hasError) { return Center(child: Text('Erro: ${snapshotChamado.error}')); }
                if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado.')); }

                final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>;
                final bool isInativoAdmin = data[kFieldAdminInativo] ?? false;

                return _ChamadoInfoBody(
                  key: ValueKey(widget.chamadoId + (data[kFieldDataAtualizacao]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString())),
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
                        padding: const EdgeInsets.all(kSpacingSmall).copyWith(bottom: MediaQuery.of(context).padding.bottom + kSpacingXSmall),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('visitas_agendadas').orderBy('dataHoraAgendada', descending: false).limit(10).snapshots(),
      builder: (context, snapshotVisitas) {
        if (snapshotVisitas.hasError) { return Padding(padding: const EdgeInsets.all(kSpacingSmall), child: Text("Erro: ${snapshotVisitas.error}")); }
        if (snapshotVisitas.connectionState == ConnectionState.waiting) { return const Padding(padding: EdgeInsets.all(kSpacingXSmall), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))); }
        if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: kSpacingSmall),
            child: Center(child: Text("Nenhuma visita agendada.", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13))),
          );
        }
        return Column(
          children: snapshotVisitas.data!.docs.map((docVisita) {
            final dataVisita = docVisita.data() as Map<String, dynamic>;
            final Timestamp? ts = dataVisita['dataHoraAgendada'] as Timestamp?;
            final String dtHr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(ts.toDate()) : 'Data Inválida';
            final String tec = dataVisita['tecnicoNome'] as String? ?? 'N/D';
            final String st = dataVisita['statusVisita'] as String? ?? 'N/I';
            final String obs = dataVisita['observacoes'] as String? ?? '';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: kSpacingXSmall, horizontal: 0),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              child: ListTile(
                leading: Icon(_getVisitaStatusIcon(st), color: _getVisitaStatusColor(st), size: 26),
                title: Text("Agendado: $dtHr", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: kSpacingXXSmall),
                      if (tec != 'N/D') Text("Técnico: $tec", style: Theme.of(context).textTheme.bodySmall),
                      if (obs.isNotEmpty) Text("Obs: $obs", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      Text("Status da Visita: $st", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                    ]),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: kSpacingXSmall, horizontal: kSpacingSmall),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getVisitaStatusIcon(String? s) {
    switch (s?.toLowerCase()) { case 'agendada': return Icons.event_available_outlined; case 'realizada': return Icons.check_circle_outline; case 'cancelada': return Icons.cancel_outlined; case 'reagendada': return Icons.history_outlined; default: return Icons.help_outline; }
  }
  Color _getVisitaStatusColor(String? s) {
    switch (s?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; }
  }

  Widget _buildCommentsSection() {
     return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(kCollectionChamados).doc(widget.chamadoId).collection('comentarios').orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) { return const Padding(padding: EdgeInsets.all(kSpacingSmall), child: Text("Erro ao carregar comentários.")); }
        if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: kSpacingSmall),
            child: Center(child: Text("Nenhum comentário ou histórico.", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13))),
          );
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final t = d['texto'] ?? '';
            final a = d['autorNome'] ?? 'Desconhecido';
            final ts = d['timestamp'] as Timestamp?;
            final dtHr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(ts.toDate()) : '--';
            final sys = d['isSystemMessage'] ?? false;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: kSpacingXSmall, horizontal: 0),
              elevation: sys ? 0.3 : 0.8,
              color: sys ? Theme.of(context).colorScheme.surfaceContainerLowest.withOpacity(0.7) : Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              child: ListTile(
                title: Text(t, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: sys ? FontStyle.italic : null,
                  color: sys ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.9) : null,
                  height: 1.3,
                )),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: kSpacingXXSmall),
                  child: Text( sys ? "Sistema - $dtHr" : "$a - $dtHr", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sys ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8) : null, fontSize: 11))),
                dense: true,
                contentPadding: EdgeInsets.symmetric(vertical: kSpacingXSmall -2, horizontal: kSpacingSmall),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCommentInputArea() {
    final th = Theme.of(context);
    final cs = th.colorScheme;
    return Container(
        key: const ValueKey('comentario_ativo'),
        padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall, vertical: kSpacingXSmall).copyWith(bottom: MediaQuery.of(context).padding.bottom + kSpacingXSmall),
        decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            boxShadow: [
                BoxShadow(
                    color: th.shadowColor.withOpacity(0.08),
                    spreadRadius: 0,
                    blurRadius: 3,
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
                                borderRadius: BorderRadius.circular(20.0),
                                borderSide: BorderSide.none
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainer,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 3,
                        enabled: !_isSendingComment,
                        onSubmitted: (_) => _isSendingComment ? null : _adicionarComentario(),
                        textInputAction: TextInputAction.send,
                    ),
                ),
                const SizedBox(width: kSpacingXSmall),
                IconButton(
                    icon: _isSendingComment
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))
                        : Icon(Icons.send_rounded, color: cs.primary, size: 22),
                    onPressed: _isSendingComment ? null : _adicionarComentario,
                    tooltip: 'Enviar Comentário',
                    style: IconButton.styleFrom(
                        backgroundColor: cs.primaryContainer,
                        disabledBackgroundColor: cs.onSurface.withOpacity(0.12),
                        padding: const EdgeInsets.all(kSpacingSmall - 2),
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

  Widget _buildSectionTitle(BuildContext context, String title, {Color? titleColor, bool addTopPadding = true}) {
     final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: kSpacingSmall,
        top: addTopPadding ? kSpacingMedium : kSpacingXSmall,
      ),
      child: Text(
        title,
        style: textTheme.titleSmall?.copyWith(
            color: titleColor ?? colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 0.1),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpacingSmall),
      child: Divider(height: 1, thickness: 0.5, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required String label, String? value, Widget? valueWidget, bool isValueSelectable = true, int valueMaxLines = 2, double labelWidth = 120.0}) {
     final ThemeData t = Theme.of(context);
    final TextTheme tt = t.textTheme;
    final ColorScheme cs = t.colorScheme;
    final String displayValue = value?.trim().isEmpty ?? true ? '--' : value!.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpacingXSmall / 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: labelWidth,
            child: Text(
              '$label:',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.95),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: kSpacingSmall),
          Expanded(
            child: valueWidget ?? (isValueSelectable
                ? SelectableText(
                    displayValue,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.25,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: valueMaxLines,
                  )
                : Text(
                    displayValue,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.25,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: valueMaxLines,
                    overflow: TextOverflow.ellipsis,
                  )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(BuildContext context, {required String status, required String prioridade}) {
    final ThemeData t = Theme.of(context);
    final TextTheme tt = t.textTheme;
    Color getChipTextColor(Color backgroundColor) {
      return backgroundColor.computeLuminance() > 0.5
          ? Colors.black.withOpacity(0.8)
          : Colors.white;
    }

    final Color statusColor = AppTheme.getStatusColor(status) ?? t.colorScheme.surfaceVariant;
    final Color priorityColor = AppTheme.getPriorityColor(prioridade) ?? t.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(top:kSpacingXSmall - 2, bottom: kSpacingSmall),
      child: Wrap(
        spacing: kSpacingSmall,
        runSpacing: kSpacingXSmall,
        alignment: WrapAlignment.start,
        children: [
          Chip(
            label: Text(status.toUpperCase(), style: tt.labelSmall?.copyWith(color: getChipTextColor(statusColor), fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            backgroundColor: statusColor,
            avatar: Icon(Icons.flag_circle_outlined, size: 15, color: getChipTextColor(statusColor).withOpacity(0.85)),
            padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall -2 , vertical: kSpacingXXSmall + 1),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          Chip(
            label: Text(prioridade, style: tt.labelSmall?.copyWith(color: getChipTextColor(priorityColor), fontWeight: FontWeight.bold)),
            backgroundColor: priorityColor,
            avatar: Icon(Icons.label_important_outline_rounded, size: 15, color: getChipTextColor(priorityColor).withOpacity(0.85)),
            padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall -2, vertical: kSpacingXXSmall + 1),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ],
      ),
    );
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
    final String? nomeRequerenteConfirmador = data[kFieldNomeRequerenteConfirmador] as String? ??
                                          (data[kFieldRequerenteConfirmouUid] != null ? 'Solicitante (UID: ${ (data[kFieldRequerenteConfirmouUid] as String).substring(0, min(6, (data[kFieldRequerenteConfirmouUid] as String).length)) }...)' : null);
    final bool adminFinalizou = data[kFieldAdminFinalizou] as bool? ?? false;
    final String? adminFinalizouNome = data[kFieldAdminFinalizouNome] as String?;
    final String adminFinalizouDataStr = formatTimestampSafe(data[kFieldAdminFinalizouData] as Timestamp?);

    final String? solucionadoPorNome = data[kFieldSolucaoPorNome] as String?;
    final String dataDaSolucaoStr = formatTimestampSafe(data[kFieldDataDaSolucao] as Timestamp?);


    String displayInstituicao = instituicao ?? 'N/I';
    if (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) { displayInstituicao = instituicaoManual; }
    String displayEquipamento = equipamentoSolicitacao;
    if (equipamentoSolicitacao == "OUTRO" && equipamentoOutroDesc != null && equipamentoOutroDesc.isNotEmpty) { displayEquipamento = "OUTRO: $equipamentoOutroDesc"; }
    String displayProblema = problemaOcorre;
    if (problemaOcorre == "OUTRO" && problemaOutroDesc != null && problemaOutroDesc.isNotEmpty) { displayProblema = "OUTRO: $problemaOutroDesc"; }

    final bool podeAdminFinalizar = isAdmin &&
                                  status.toLowerCase() == kStatusPadraoSolicionado.toLowerCase() &&
                                  requerenteConfirmou &&
                                  !adminFinalizou &&
                                  !isInativoAdmin;

    Widget solicitacaoSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Dados da Solicitação', addTopPadding: false),
        _buildInfoRow(context, label: 'Solicitante', value: nomeSolicitante),
        _buildInfoRow(context, label: 'Contato', value: celularContato),
        _buildInfoRow(context, label: 'Tipo', value: tipoSolicitante),
        if (tipoSolicitante == 'ESCOLA') ...[
          if (cidade != null) _buildInfoRow(context, label: 'Cidade/Distrito', value: cidade),
          _buildInfoRow(context, label: 'Instituição', value: displayInstituicao, valueMaxLines: 3),
          if (cargoFuncao != null) _buildInfoRow(context, label: 'Cargo/Função', value: cargoFuncao),
          if (atendimentoPara != null) _buildInfoRow(context, label: 'Atendimento Para', value: atendimentoPara),
        ],
        if (tipoSolicitante == 'SUPERINTENDENCIA') ...[
          if (setorSuper != null) _buildInfoRow(context, label: 'Setor SUPER', value: setorSuper, valueMaxLines: 3),
          if (cidadeSuperintendencia != null) _buildInfoRow(context, label: 'Cidade SUPER', value: cidadeSuperintendencia),
        ],
      ],
    );

    Widget problemaDatasSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Detalhes do Problema', addTopPadding: false),
        _buildInfoRow(context, label: 'Problema', value: displayProblema, valueMaxLines: 4),
        _buildInfoRow(context, label: 'Equipamento', value: displayEquipamento, valueMaxLines: 3),
        if (marcaModelo.isNotEmpty) _buildInfoRow(context, label: 'Marca/Modelo', value: marcaModelo),
        _buildInfoRow(context, label: 'Patrimônio', value: patrimonio),
        _buildInfoRow(context, label: 'Internet', value: conectadoInternet),
        if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) _buildInfoRow(context, label: 'Técnico Resp.', value: tecnicoResponsavel),

        _buildSectionTitle(context, 'Datas e Registro'),
        _buildInfoRow(context, label: 'Criado em', value: dtCriacao),
        _buildInfoRow(context, label: 'Dt. Atendimento', value: dtAtendimento),
        if (authUserDisplay != null && authUserDisplay.isNotEmpty) _buildInfoRow(context, label: 'Registrado por', value: authUserDisplay),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingMedium, vertical: kSpacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isInativoAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: kSpacingSmall),
              child: Center(
                child: Chip(
                  label: Text('CHAMADO INATIVO (APENAS ADMINS VÊEM)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall, vertical: kSpacingXSmall -2),
                ),
              ),
            ),
          _buildStatusChips(context, status: status, prioridade: prioridade),

          LayoutBuilder(
            builder: (context, constraints) {
              bool useSingleColumn = constraints.maxWidth < 680;
              if (useSingleColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    solicitacaoSection,
                    problemaDatasSection,
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: solicitacaoSection,
                    ),
                    const SizedBox(width: kSpacingMedium),
                    Expanded(
                      flex: 3,
                      child: problemaDatasSection,
                    ),
                  ],
                );
              }
            }
          ),

          if (solucao != null && solucao.isNotEmpty) ...[
            _buildSectionTitle(context, 'Solução Registrada'),
            if (solucionadoPorNome != null && dataDaSolucaoStr != '--') ...[
                _buildInfoRow(context, label: 'Solucionado por', value: solucionadoPorNome),
                _buildInfoRow(context, label: 'Data da Solução', value: dataDaSolucaoStr),
            ],
            Container(
              padding: const EdgeInsets.all(kSpacingSmall - 2),
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: SelectableText(solucao, style: textTheme.bodyMedium?.copyWith(height: 1.35)),
            ),
            const SizedBox(height: kSpacingSmall),
          ],

          if (requerenteConfirmou) ...[
            _buildSectionTitle(context, 'Confirmação do Requerente', titleColor: Colors.green.shade700),
            _buildInfoRow(context, label: 'Status Confirmação', value: 'Solução Aceita pelo Requerente'),
            if (nomeRequerenteConfirmador != null)
              _buildInfoRow(context, label: 'Confirmado por', value: nomeRequerenteConfirmador),
            _buildInfoRow(context, label: 'Data Confirmação', value: dtConfirmacaoReq),
              const SizedBox(height: kSpacingSmall),
          ],

          if (isAdmin) ...[
            if (podeAdminFinalizar) ...[
              _buildSectionDivider(context),
              Center(
                child: isFinalizandoAdmin
                    ? const CircularProgressIndicator(strokeWidth: 3)
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text('Arquivar Chamado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: onAdminFinalizarChamado,
                      ),
              ),
                const SizedBox(height: kSpacingXSmall),
            ] else if (adminFinalizou) ...[
              _buildSectionDivider(context),
              _buildSectionTitle(context, 'Detalhes do Arquivamento', titleColor: AppTheme.kWinStatusFinalizadoBackground),
              _buildInfoRow(context, label: 'Data Arquivamento', value: adminFinalizouDataStr),
              if (adminFinalizouNome != null)
                _buildInfoRow(context, label: 'Arquivado por', value: adminFinalizouNome),
              _buildInfoRow(context, label: 'Status Sistema', value: 'Chamado Arquivado'),
                const SizedBox(height: kSpacingSmall),
            ],
          ],

          if (isAdmin && !isUpdatingVisibility) ...[
            _buildSectionDivider(context),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(isInativoAdmin ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                label: Text(isInativoAdmin ? "Reativar p/ Requ." : "Inativar p/ Requ."),
                style: ElevatedButton.styleFrom(
                    backgroundColor: isInativoAdmin ? colorScheme.primary : Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => onToggleInatividade(isInativoAdmin),
              ),
            ),
              const SizedBox(height: kSpacingXSmall),
          ] else if (isUpdatingVisibility) ... [
              const Center(child: Padding(padding: EdgeInsets.all(kSpacingXSmall), child: CircularProgressIndicator(strokeWidth: 3)))
          ],

          _buildSectionDivider(context),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Agenda de Visitas", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (isAdmin || !isInativoAdmin)
                TextButton.icon(
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Agendar', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall, vertical: kSpacingXSmall-2),
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AgendamentoVisitaScreen(chamadoId: chamadoId),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: kSpacingXSmall),
          buildAgendaSection(),

          _buildSectionDivider(context),
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacingXSmall),
            child: Text("Comentários e Histórico", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          buildCommentsSection(),
          const SizedBox(height: kSpacingLarge),
        ],
      ),
    );
  }
}