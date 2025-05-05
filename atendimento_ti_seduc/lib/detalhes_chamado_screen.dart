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

// Importações locais
import 'pdf_generator.dart';
import 'agendamento_visita_screen.dart';
import 'config/theme/app_theme.dart';
import 'services/chamado_service.dart'; // <-- Importar o serviço (para a constante kFieldAdminInativo e métodos)

// Constantes locais (removidas se importadas de outro lugar)
 const String kFieldInstituicaoManual = 'instituicao_manual'; // Exemplo
 const String kFieldEquipamentoOutro = 'equipamento_outro_descricao'; // Exemplo
 const String kFieldProblemaOutro = 'problema_outro_descricao'; // Exemplo

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  // --- Serviços e Autenticação ---
  final ChamadoService _chamadoService = ChamadoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isAdmin = false; // Flag para verificar se o usuário é admin
  bool _isAdminStatusChecked = false; // Para evitar checagens repetidas

  // --- Estado para Edição e Comentários ---
  final List<String> _listaStatus = ['aberto', 'em andamento', 'pendente', 'resolvido', 'fechado', 'cancelado'];
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];
  final TextEditingController _comentarioController = TextEditingController();
  bool _isSendingComment = false;
  bool _isUpdatingVisibility = false; // Loading para ação de admin (inatividade)

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _checkAdminStatus(); // Verifica o status de admin ao iniciar
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  // --- LÓGICA PARA VERIFICAR ADMIN (MODIFICADA para usar role_temp) ---
  Future<void> _checkAdminStatus() async {
    // Garante que só executa uma vez ou se o estado ainda não foi checado
    if (!_isAdminStatusChecked && mounted) {
      bool isAdminResult = false;
      // Garante que _currentUser está definido (já feito no initState)
      if (_currentUser != null) {
        final userId = _currentUser!.uid;
        print("--- Iniciando Verificação de Role para UID: $userId ---");
        try {
          print("Firestore Check: Tentando ler /users/$userId"); // Ajuste 'users' se sua coleção for outra
          final DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users') // <<< CONFIRME O NOME DA SUA COLEÇÃO DE USUÁRIOS
              .doc(userId)
              .get(); // Pega do servidor/cache

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
          print("DetalhesChamadoScreen: ERRO FATAL ao buscar role do usuário: $e");
          print(s);
          isAdminResult = false; // Assume não-admin em caso de erro
        }
      } else {
        print("DetalhesChamadoScreen: Nenhum usuário logado para verificar a role.");
        isAdminResult = false;
      }

      // Atualiza o estado APENAS se o widget ainda estiver montado
      if (mounted) {
        setState(() {
          _isAdmin = isAdminResult;
          _isAdminStatusChecked = true; // Marca a verificação como concluída
        });
        print("--- Fim Verificação de Role --- _isAdmin definido como: $_isAdmin ---");
      }
    }
  }


  // --- Função para mostrar diálogo de edição (status operacional) ---
  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
     // (Código inalterado - da resposta anterior, já chama o serviço corretamente)
      final ThemeData theme = Theme.of(context);
     String statusSelecionado = dadosAtuais['status'] ?? _listaStatus.first;
     String prioridadeSelecionada = dadosAtuais['prioridade'] ?? _listaPrioridades.first;
     String tecnicoResponsavel = dadosAtuais['tecnico_responsavel'] as String? ?? '';
     final tecnicoController = TextEditingController(text: tecnicoResponsavel);
     final formKeyDialog = GlobalKey<FormState>();

     if (!_listaStatus.contains(statusSelecionado)) statusSelecionado = _listaStatus.first;
     if (!_listaPrioridades.contains(prioridadeSelecionada)) prioridadeSelecionada = _listaPrioridades.first;

     bool? confirmou = await showDialog<bool>(
       context: context,
       builder: (BuildContext dialogContext) {
         return Theme(
           data: theme,
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
                           decoration: const InputDecoration(labelText: 'Status'),
                           validator: (value) => value == null ? 'Selecione um status' : null,
                         ),
                         const SizedBox(height: 15),
                         DropdownButtonFormField<String>(
                           value: prioridadeSelecionada,
                           items: _listaPrioridades.map((String value) => DropdownMenuItem<String>( value: value, child: Text(value), )).toList(),
                           onChanged: (newValue) { if (newValue != null) { setDialogState(() { prioridadeSelecionada = newValue; }); } },
                           decoration: const InputDecoration(labelText: 'Prioridade'),
                            validator: (value) => value == null ? 'Selecione uma prioridade' : null,
                         ),
                         const SizedBox(height: 15),
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
           ),
         );
       },
     );

     if (confirmou == true && mounted) {
       try {
         final tecnicoFinal = tecnicoController.text.trim();
          await _chamadoService.atualizarStatusOperacional(
              widget.chamadoId,
              statusSelecionado,
              prioridade: prioridadeSelecionada,
              tecnicoResponsavel: tecnicoFinal,
         );

         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chamado atualizado!'), backgroundColor: Colors.green,));
       } catch (e) {
         print("Erro ao atualizar: $e");
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: ${e.toString()}'), backgroundColor: Colors.red,));
       }
     }
     tecnicoController.dispose();
  }


  // --- Funções de PDF (inalteradas) ---
  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
     try {
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
        final Uint8List pdfBytes = await generateTicketPdf(dadosChamado);
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/chamado_${widget.chamadoId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) { throw Exception('Não foi possível abrir o arquivo PDF: ${result.message}'); }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('PDF baixado e aberto: ${file.path.split('/').last}')) );
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        print("Erro ao baixar/abrir PDF: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao baixar/abrir PDF: ${e.toString()}'), backgroundColor: Colors.red,) );
      }
  }

  // --- Função para Adicionar Comentário (inalterada) ---
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
        FocusScope.of(context).unfocus();
      } catch (e) { print("Erro ao adicionar comentário: $e"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar comentário.'), backgroundColor: Colors.red,));
      } finally { if(mounted) setState(() { _isSendingComment = false; }); }
  }

  // --- Função: Alternar Inatividade Administrativa (Ação de Admin) ---
  Future<void> _toggleInatividadeAdmin(bool isInativoAtual) async {
    if (!_isAdmin || _isUpdatingVisibility) return; // Só admin pode executar

    final bool tornarAtivo = isInativoAtual; // A ação desejada é o inverso do estado atual
    final String acao = tornarAtivo ? "Reativar" : "Tornar Inativo";
    final String acaoLabel = tornarAtivo ? "Reativado" : "Inativo";

    // --- Diálogo de Confirmação ---
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Não fechar clicando fora
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar Ação de Admin'),
        content: Text('Deseja realmente "$acao" este chamado administrativamente?\n(O requisitante ${tornarAtivo ? 'poderá' : 'NÃO poderá mais'} acessar os detalhes).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Confirmar', style: TextStyle(color: tornarAtivo ? Colors.green : Colors.red))
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    // --- Fim Diálogo ---

    setState(() { _isUpdatingVisibility = true; });
    try {
      // Chama o método do serviço com o NOVO estado desejado (!isInativoAtual)
      await _chamadoService.definirInatividadeAdministrativa(widget.chamadoId, !isInativoAtual);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chamado tornado "$acaoLabel" administrativamente.'),
            backgroundColor: Colors.green));
        // O StreamBuilder vai atualizar a UI automaticamente, não precisa setState aqui para os dados
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao atualizar inatividade: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isUpdatingVisibility = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    // Mostra loading inicial enquanto verifica o status de admin
    if (!_isAdminStatusChecked) {
      return Scaffold(
        appBar: AppBar(title: Text('Carregando Chamado...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Título pode ser dinâmico se você buscar os dados aqui também
        title: Text('Chamado #${widget.chamadoId.substring(0, 6)}...'),
        // --- Ações da AppBar ---
         actions: [
           // Usar snapshot do corpo para os dados atuais nos actions
           StreamBuilder<DocumentSnapshot>(
             stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
             builder: (context, snapshot) {
               if (snapshot.hasData && snapshot.data!.exists) {
                 // Usar data() com segurança
                 final currentData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                 final bool isInativoAdmin = currentData[kFieldAdminInativo] ?? false; // Usa constante importada do serviço

                 // Admin pode editar/compartilhar/baixar mesmo inativo
                 // Requisitante SÓ pode se NÃO for admin E NÃO estiver inativo
                 bool podeInteragir = _isAdmin || !isInativoAdmin;

                 return Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     // Botão de editar status/técnico (apenas para admin neste exemplo)
                     if (_isAdmin)
                       IconButton(
                         icon: const Icon(Icons.edit_note_outlined),
                         tooltip: 'Editar Status/Técnico',
                         // Desabilita se estiver atualizando outra coisa? Ou permite?
                         onPressed: _isUpdatingVisibility ? null : () => _mostrarDialogoEdicao(currentData),
                       ),
                     // Botões de Compartilhar/Baixar
                     if (podeInteragir) ...[
                       IconButton(
                         icon: const Icon(Icons.share_outlined),
                         tooltip: 'Compartilhar PDF',
                         onPressed: () => _handlePdfShare(currentData),
                       ),
                       IconButton(
                         icon: const Icon(Icons.download_outlined),
                         tooltip: 'Baixar PDF',
                         onPressed: () => _baixarPdf(currentData),
                       ),
                     ]
                   ],
                 );
               }
               return const SizedBox.shrink(); // Retorna vazio se não houver dados ainda
             }
           )
         ],
      ),
      // --- Corpo Principal com StreamBuilder ---
      body: Column( // Para incluir área de comentário abaixo
        children: [
          Expanded( // Para a lista de detalhes rolar
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
              builder: (context, snapshotChamado) {
                // Tratamento de Erros e Loading
                if (snapshotChamado.hasError) { return Center(child: Text('Erro: ${snapshotChamado.error}', style: TextStyle(color: colorScheme.error))); }
                if (snapshotChamado.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (!snapshotChamado.hasData || !snapshotChamado.data!.exists) { return const Center(child: Text('Chamado não encontrado')); }

                // Dados do Chamado
                final Map<String, dynamic> data = snapshotChamado.data!.data()! as Map<String, dynamic>;
                // Usa a constante importada do serviço
                final bool isInativoAdmin = data[kFieldAdminInativo] ?? false;

                // --- EXTRAÇÃO DE DADOS (como antes) ---
                 final String tipoSolicitante = data['tipo_solicitante'] ?? 'N/I';
                 final String nomeSolicitante = data['nome_solicitante'] ?? 'N/I';
                 final String celularContato = data['celular_contato'] ?? 'N/I';
                 final String equipamentoSolicitacao = data['equipamento_solicitacao'] ?? 'N/I';
                 final String conectadoInternet = data['equipamento_conectado_internet'] ?? 'N/I';
                 final String marcaModelo = data['marca_modelo_equipamento'] ?? '';
                 final String patrimonio = data['numero_patrimonio'] ?? 'N/I';
                 final String problemaOcorre = data['problema_ocorre'] ?? 'N/I';
                 final String status = data['status'] ?? 'N/I';
                 final String prioridade = data['prioridade'] ?? 'N/I';
                 final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?;
                 final String? authUserDisplay = data['authUserDisplayName'] as String?;
                 final Timestamp? tsCriacao = data['data_criacao'] as Timestamp?;
                 final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
                 final Timestamp? tsUpdate = data['data_atualizacao'] as Timestamp?;
                 final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';
                 final String? cidade = data['cidade'] as String?;
                 final String? instituicao = data['instituicao'] as String?;
                 final String? cargoFuncao = data['cargo_funcao'] as String?;
                 final String? atendimentoPara = data['atendimento_para'] as String?;
                 final String? setorSuper = data['setor_superintendencia'] as String?;
                 final String? cidadeSuperintendencia = data['cidade_superintendencia'] as String?;
                 final String? instituicaoManual = data[kFieldInstituicaoManual] as String?;
                 final String? equipamentoOutroDesc = data[kFieldEquipamentoOutro] as String?;
                 final String? problemaOutroDesc = data[kFieldProblemaOutro] as String?;

                // --- LÓGICA PARA DETERMINAR VALORES DE EXIBIÇÃO (como antes) ---
                 String displayInstituicao = instituicao ?? 'N/I';
                 if (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) {
                     displayInstituicao = instituicaoManual;
                 }
                 String displayEquipamento = equipamentoSolicitacao;
                 if (equipamentoSolicitacao == "OUTRO" && equipamentoOutroDesc != null && equipamentoOutroDesc.isNotEmpty) {
                     displayEquipamento = "OUTRO: $equipamentoOutroDesc";
                 }
                 String displayProblema = problemaOcorre;
                 if (problemaOcorre == "OUTRO" && problemaOutroDesc != null && problemaOutroDesc.isNotEmpty) {
                     displayProblema = "OUTRO: $problemaOutroDesc";
                 }

                // --- Layout Principal ---
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // --- TAG INATIVO (Visível para Todos) ---
                      if (isInativoAdmin)
                         Padding(
                           padding: const EdgeInsets.only(bottom: 15.0),
                           child: Center(
                             child: Chip(
                               label: Text('INATIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                               backgroundColor: Colors.red.shade700,
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             ),
                           ),
                         ),

                      _buildStatusChips(context, status: status, prioridade: prioridade),
                      const SizedBox(height: 20.0),

                       Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // COLUNA 1 (Solicitação)
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
                                   if (cidadeSuperintendencia != null) _buildModernInfoTile( context, icon: Icons.location_city_rounded, label: 'Cidade SUPER', value: cidadeSuperintendencia ),
                                 ],
                               ],
                             ),
                           ),
                           const SizedBox(width: 16.0),
                           // COLUNA 2 (Detalhes Técnicos)
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
                                  _buildModernInfoTile(context, icon: Icons.update_outlined, label: 'Última Atualização', value: dtUpdate),
                                  if (authUserDisplay != null && authUserDisplay.isNotEmpty) _buildModernInfoTile(context, icon: Icons.person_pin_outlined, label: 'Registrado por', value: authUserDisplay),
                               ],
                             ),
                           ),
                         ],
                       ),

                      // --- BOTÃO ADMIN PARA MUDAR INATIVIDADE ---
                      if (_isAdmin) ...[ // Só mostra para Admin
                         const Divider(height: 35, thickness: 1),
                         Center(
                           child: ElevatedButton.icon(
                             icon: _isUpdatingVisibility
                                 ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                 : Icon(isInativoAdmin ? Icons.visibility_outlined : Icons.visibility_off_outlined), // Ícone muda com estado
                             label: Text(isInativoAdmin ? "Reativar p/ Requisitante" : "Tornar Inativo p/ Req."),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: isInativoAdmin ? Colors.blue.shade700 : Colors.orange.shade800, // Cor muda com estado
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                             ),
                             // Chama a função passando o ESTADO ATUAL
                             onPressed: _isUpdatingVisibility ? null : () => _toggleInatividadeAdmin(isInativoAdmin),
                           ),
                         ),
                      ],

                       Divider(height: 35, thickness: 1, color: colorScheme.primary.withOpacity(0.3)),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           Text("Agenda de Visitas", style: textTheme.titleMedium),
                           // Só permite agendar se for admin OU se não for admin E chamado estiver ativo
                           if (_isAdmin || !isInativoAdmin)
                              ElevatedButton.icon(
                                 icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                                 label: const Text('Agendar'),
                                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                 onPressed: () {
                                    if (_isAdmin || !isInativoAdmin) {
                                       Navigator.push( context, MaterialPageRoute( builder: (context) => AgendamentoVisitaScreen(chamadoId: widget.chamadoId),),);
                                    } else {
                                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é possível agendar visita para chamado inativo.')));
                                    }
                                 },
                              ),
                         ],
                       ),
                       const SizedBox(height: 10),
                       _buildAgendaSection(), // Método auxiliar inalterado

                       Divider(height: 35, thickness: 1, color: colorScheme.primary.withOpacity(0.3)),
                       Padding( padding: const EdgeInsets.only(bottom: 10.0), child: Text("Comentários / Histórico", style: textTheme.titleMedium), ),
                       _buildCommentsSection(), // Método auxiliar inalterado
                       const SizedBox(height: 20), // Espaço antes da área de comentário
                    ],
                  ),
                );
              },
            ),
          ), // Fim Expanded principal

          // --- Área de Input de Comentário ---
          StreamBuilder<DocumentSnapshot>(
             stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
             builder: (context, snapshot) {
                 if (!snapshot.hasData || snapshot.hasError || !snapshot.data!.exists) {
                     return const SizedBox.shrink();
                 }
                 final bool isInativoAdmin = (snapshot.data!.data() as Map<String, dynamic>?)?[kFieldAdminInativo] ?? false;
                 final bool podeComentar = _isAdmin || !isInativoAdmin;

                 return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: podeComentar
                      ? _buildCommentInputArea()
                      : Container(
                          key: const ValueKey('comentario_inativo'),
                          padding: const EdgeInsets.all(12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8),
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          child: Center(
                              child: Text(
                                'Comentários desabilitados (Chamado Inativo)',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              )
                          ),
                       ),
                 );
             }
          ),
        ], // Fim Column principal
      ), // Fim Body Column
    ); // Fim Scaffold
  } // Fim build()


  // --- Widgets Auxiliares ---
  // Cole aqui as implementações de:
  // _buildStatusChips, _buildModernInfoTile, _buildAgendaSection,
  // _getVisitaStatusIcon, _getVisitaStatusColor, _buildCommentsSection,
  // _buildCommentInputArea
  // (O código deles foi fornecido nas respostas anteriores e parece correto)

  // --- Widget para construir Chips de Status e Prioridade ---
  Widget _buildStatusChips(BuildContext context, {required String status, required String prioridade}) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    Color getChipTextColor(Color backgroundColor) {
      return backgroundColor.computeLuminance() > 0.5 ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9);
    }

    final Color statusColor = AppTheme.getStatusColor(status) ?? theme.colorScheme.surfaceVariant;
    final Color priorityColor = AppTheme.getPriorityColor(prioridade) ?? theme.colorScheme.secondary;

    return Wrap(
      spacing: 8.0,
      runSpacing: 6.0,
      children: [
        Chip(
          label: Text(status.toUpperCase()),
          labelStyle: textTheme.labelMedium?.copyWith(
            color: getChipTextColor(statusColor),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          backgroundColor: statusColor,
          avatar: Icon(Icons.flag_outlined, size: 16, color: getChipTextColor(statusColor).withOpacity(0.8)),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        Chip(
          label: Text(prioridade),
          labelStyle: textTheme.labelMedium?.copyWith(
              color: getChipTextColor(priorityColor),
              fontWeight: FontWeight.w600,
            ),
          backgroundColor: priorityColor,
          avatar: Icon(Icons.priority_high_rounded, size: 16, color: getChipTextColor(priorityColor).withOpacity(0.8)),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ],
    );
  }

  // --- Widget auxiliar REFINADO ---
  Widget _buildModernInfoTile(BuildContext context, {required IconData icon, required String label, required String value, bool isValueMultiline = false}) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Icon( icon, color: colorScheme.primary, size: 20, ),
            )
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text( label, style: textTheme.bodySmall?.copyWith( color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.1 ), ),
                SelectableText( displayValue, style: textTheme.bodyLarge?.copyWith( height: 1.2 ), maxLines: isValueMultiline ? null : 5, textAlign: TextAlign.start, ),
              ],
            ),
          ),
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
          if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhuma visita agendada.")), ); }

          return Column( children: snapshotVisitas.data!.docs.map((docVisita) {
            final dataVisita = docVisita.data() as Map<String, dynamic>;
            final Timestamp? timestampAgendado = dataVisita['dataHoraAgendada'] as Timestamp?;
            final String dataHoraAgendada = timestampAgendado != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestampAgendado.toDate()) : 'Data Inválida';
            final String tecnico = dataVisita['tecnicoNome'] as String? ?? 'Não definido';
            final String status = dataVisita['statusVisita'] as String? ?? 'N/I';
            final String obs = dataVisita['observacoes'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
              child: ListTile(
                leading: Icon(_getVisitaStatusIcon(status), color: _getVisitaStatusColor(status), size: 32),
                title: Text("Agendado: $dataHoraAgendada", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 3),
                  if (tecnico != 'Não definido') Text("Técnico: $tecnico", style: Theme.of(context).textTheme.bodySmall),
                  if (obs.isNotEmpty) Text("Obs: $obs", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  Text("Status: $status", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                ]),
                dense: true,
              ),
            );
          }).toList(), );
        },
      );
    }
    IconData _getVisitaStatusIcon(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Icons.event_available; case 'realizada': return Icons.check_circle; case 'cancelada': return Icons.cancel; case 'reagendada': return Icons.history_toggle_off; default: return Icons.help_outline; } }
    Color _getVisitaStatusColor(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; } }

  // --- Widget para construir a lista de comentários ---
  Widget _buildCommentsSection() {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance .collection('chamados') .doc(widget.chamadoId) .collection('comentarios') .orderBy('timestamp', descending: true) .limit(50) .snapshots(),
        builder: (context, snapshotComentarios) {
          if (snapshotComentarios.hasError) { return Text("Erro ao carregar comentários.", style: TextStyle(color: Theme.of(context).colorScheme.error)); }
          if (snapshotComentarios.connectionState == ConnectionState.waiting) { return const Center(child: SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))); }
          if (!snapshotComentarios.hasData || snapshotComentarios.data!.docs.isEmpty) { return const Padding( padding: EdgeInsets.symmetric(vertical: 15.0), child: Center(child: Text("Nenhum comentário ainda.")), ); }

          return Column( children: snapshotComentarios.data!.docs.map((docComentario) {
            final dataComentario = docComentario.data() as Map<String, dynamic>;
            final String texto = dataComentario['texto'] ?? '';
            final String autor = dataComentario['autorNome'] ?? 'Desconhecido';
            final Timestamp? timestamp = dataComentario['timestamp'] as Timestamp?;
            final String dataHora = timestamp != null ? DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(timestamp.toDate()) : '--:--';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
              child: ListTile(
                title: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("$autor - $dataHora", style: Theme.of(context).textTheme.bodySmall),
                ),
                dense: true,
              ),
            );
          }).toList(), );
        },
      );
    }

  // --- Widget para a área de input de comentário ---
  Widget _buildCommentInputArea() {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest, // Ou surfaceContainer
          boxShadow: [ BoxShadow( color: theme.shadowColor.withOpacity(0.1), spreadRadius: 0, blurRadius: 4, offset: const Offset(0, -1), ), ],
        ),
        child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: TextField(
              controller: _comentarioController,
              decoration: InputDecoration(
                hintText: 'Adicionar comentário...',
                isDense: true,
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest, // Ou surfaceVariant
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1, maxLines: 4, enabled: !_isSendingComment,
              onSubmitted: (_) => _isSendingComment ? null : _adicionarComentario(),
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: _isSendingComment ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Icon(Icons.send_rounded, color: colorScheme.primary),
            onPressed: _isSendingComment ? null : _adicionarComentario,
            tooltip: 'Enviar Comentário',
            style: IconButton.styleFrom( backgroundColor: colorScheme.primaryContainer, disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12), ),
          ),
        ]),
      );
    }

} // Fim da classe _DetalhesChamadoScreenState