// lib/detalhes_chamado_screen.dart
import 'dart:io';         // Para File
import 'dart:typed_data'; // Para Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Para achar pasta
import 'package:share_plus/share_plus.dart';       // Para compartilhar
import 'package:open_filex/open_filex.dart';       // <<< NOVO: Para abrir arquivo
import 'pdf_generator.dart'; // Importa generateTicketPdf

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  // Listas e função _mostrarDialogoEdicao (mantidas)
  final List<String> _listaStatus = ['aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];
  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async { /* ... código do diálogo ... */ }

  // --- Função para GERAR E COMPARTILHAR PDF ---
  Future<void> _handlePdfShare(Map<String, dynamic> currentData) async {
     // Mostra loading
     showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
     try {
       // Gera os bytes do PDF
       final Uint8List pdfBytes = await generateTicketPdf(currentData);
       // Salva temporariamente
       final tempDir = await getTemporaryDirectory();
       final filePath = '${tempDir.path}/chamado_${widget.chamadoId}_share.pdf'; // Nome diferente para share
       final file = File(filePath);
       await file.writeAsBytes(pdfBytes);

       if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha loading

       // Compartilha
       final result = await Share.shareXFiles(
           [XFile(filePath)],
           text: 'Detalhes do Chamado: ${currentData['titulo'] ?? widget.chamadoId}'
       );
        if (result.status == ShareResultStatus.success && mounted) { print("Compartilhamento iniciado."); }
     } catch (e) {
        if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
        print("Erro ao gerar/compartilhar PDF: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar/compartilhar PDF: $e'), backgroundColor: Colors.red));
     }
  }
  // -----------------------------------------

  // --- Função para GERAR E BAIXAR PDF ---
  // <<< NOVA FUNÇÃO >>>
  Future<void> _baixarPdf(Map<String, dynamic> dadosChamado) async {
      // Mostra loading
      showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      String? savedFilePath; // Guarda o caminho onde foi salvo

      try {
        // 1. Gera os bytes do PDF
        final Uint8List pdfBytes = await generateTicketPdf(dadosChamado);

        // 2. Obtém o diretório de documentos do aplicativo (interno, mas acessível)
        final Directory appDocsDir = await getApplicationDocumentsDirectory();
        // OBS: Para salvar na pasta "Downloads" pública, precisaria de permissões
        // e pacotes adicionais (mais complexo e dependente da plataforma).
        // Salvar em getApplicationDocumentsDirectory é mais simples e garantido.
        final String downloadsPath = appDocsDir.path; // Pasta de documentos do app
        final String fileName = 'chamado_${widget.chamadoId}_${DateFormat('yyyyMMddHHmm').format(DateTime.now())}.pdf';
        final String filePath = '$downloadsPath/$fileName';
        savedFilePath = filePath; // Guarda para o SnackBar

        print("Salvando PDF em: $filePath");

        // 3. Escreve o arquivo
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        if(!mounted) return; // Sai se o widget foi desmontado
        Navigator.of(context, rootNavigator: true).pop(); // Fecha loading

        // 4. Mostra confirmação com opção de abrir
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF salvo em Documentos do App! ($fileName)'),
            duration: const Duration(seconds: 5), // Duração maior
            action: SnackBarAction(
              label: 'ABRIR',
              onPressed: () {
                OpenFilex.open(filePath); // Usa open_filex para abrir
              },
            ),
          ),
        );

      } catch (e) {
        if(mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
        print("Erro ao baixar PDF: $e");
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao baixar PDF: $e'), backgroundColor: Colors.red));
      }
  }
  // -----------------------------------
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
                    children: [
                      // Botão Editar
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: 'Editar Status/Prioridade',
                        onPressed: () => _mostrarDialogoEdicao(currentData),
                      ),
                      // --- Botão COMPARTILHAR PDF ---
                      IconButton(
                        icon: const Icon(Icons.share), // Ícone de compartilhar
                        tooltip: 'Compartilhar PDF',
                        onPressed: () => _handlePdfShare(currentData), // Chama a função de compartilhar
                      ),
                      // --- Botão BAIXAR PDF --- <<< NOVO BOTÃO >>>
                      IconButton(
                        icon: const Icon(Icons.download), // Ícone de download
                        tooltip: 'Baixar PDF',
                        onPressed: () => _baixarPdf(currentData), // Chama a função de baixar
                      ),
                      // ------------------------
                    ],
                  );
                }
                return const SizedBox.shrink();
              })
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
           // ... (Código do builder do StreamBuilder como antes, exibindo os detalhes) ...
            if (snapshot.hasError) { return Center(child: Text('Erro: ${snapshot.error}')); }
            if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
            if (!snapshot.hasData || !snapshot.data!.exists) { return const Center(child: Text('Chamado não encontrado')); }

            final Map<String, dynamic> data = snapshot.data!.data()! as Map<String, dynamic>;
             final String titulo = data['titulo'] ?? 'S/ Título';
             final String descricao = data['descricao'] ?? 'S/ Descrição';
             final String categoria = data['categoria'] ?? 'S/ Categoria';
             final String status = data['status'] ?? 'S/ Status';
             final String prioridade = data['prioridade'] ?? 'S/ Prioridade';
             final String criadorNome = data['creatorName'] ?? 'Desconhecido';
             final String equipamento = data['equipamento'] ?? 'N/I';
             final String departamento = data['departamento'] ?? 'N/I';
             final String? creatorUid = data['creatorUid'] as String?;
             final Timestamp? dataCriacaoTimestamp = data['data_criacao'] as Timestamp?;
             final String dataCriacaoFormatada = dataCriacaoTimestamp != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataCriacaoTimestamp.toDate()) : 'N/I';
             final Timestamp? dataAtualizacaoTimestamp = data['data_atualizacao'] as Timestamp?;
             final String dataAtualizacaoFormatada = dataAtualizacaoTimestamp != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataAtualizacaoTimestamp.toDate()) : '--';

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: <Widget>[
                 _buildDetailItem(context, 'Título', titulo),
                 _buildDetailItem(context, 'Descrição', descricao, isMultiline: true),
                 const Divider(height: 30, thickness: 1),
                 Row( children: [ Expanded(child: _buildDetailItem(context, 'Status', status)), Expanded(child: _buildDetailItem(context, 'Prioridade', prioridade)), ], ),
                 Row( children: [ Expanded(child: _buildDetailItem(context, 'Categoria', categoria)), Expanded(child: _buildDetailItem(context, 'Departamento', departamento)), ], ),
                 _buildDetailItem(context, 'Equipamento/Sistema', equipamento),
                 const Divider(height: 30, thickness: 1),
                 _buildDetailItem(context, 'Criado por', criadorNome),
                 // Bloco para Buscar e Exibir Telefone do Criador (mantido)
                 if (creatorUid != null && creatorUid.isNotEmpty)
                   FutureBuilder<DocumentSnapshot>(
                     future: FirebaseFirestore.instance.collection('users').doc(creatorUid).get(),
                     builder: (context, snapshotUser) {
                       if (snapshotUser.connectionState == ConnectionState.waiting) { return _buildDetailItem(context, 'Telefone Criador', 'Carregando...'); }
                       if (snapshotUser.hasError || !snapshotUser.hasData || !snapshotUser.data!.exists) { return _buildDetailItem(context, 'Telefone Criador', 'Não disponível'); }
                       final userData = snapshotUser.data!.data() as Map<String, dynamic>;
                       final String phone = userData['phone'] as String? ?? 'Não informado';
                       return _buildDetailItem(context, 'Telefone Criador', phone);
                     },
                   )
                 else
                     _buildDetailItem(context, 'Telefone Criador', 'UID não encontrado'),
                 _buildDetailItem(context, 'Criado em', dataCriacaoFormatada),
                 _buildDetailItem(context, 'Última Atualização', dataAtualizacaoFormatada),
              ],
            );
        },
      ),
    );
  }

  // Widget auxiliar _buildDetailItem (mantido)
  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          SizedBox( width: 130, child: Text( label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), ), ),
          const SizedBox(width: 10),
          Expanded( child: SelectableText( value, style: Theme.of(context).textTheme.bodyMedium, ), ),
        ],
      ),
    );
  }
}