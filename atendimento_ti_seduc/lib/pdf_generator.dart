import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'dart:convert'; // Para Base64 (se usar como fallback ou em user data)
import 'package:flutter/material.dart'; // Necessário se usar BuildContext
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para buscar dados do usuário
import 'package:firebase_storage/firebase_storage.dart'; // Para buscar assinatura
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http; // Para baixar imagem da URL

// Constantes dos campos do CHAMADO
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldCelularContato = 'celular_contato';
const String kFieldEquipamentoSolicitacao = 'equipamento_solicitacao';
const String kFieldEquipamentoOutro = 'equipamento_outro_descricao';
const String kFieldConectadoInternet = 'equipamento_conectado_internet';
const String kFieldMarcaModelo = 'marca_modelo_equipamento';
const String kFieldPatrimonio = 'numero_patrimonio';
const String kFieldProblemaOcorre = 'problema_ocorre';
const String kFieldProblemaOutro = 'problema_outro_descricao';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
const String kFieldInstituicaoManual = 'instituicao_manual';
const String kFieldCargoFuncao = 'cargo_funcao';
const String kFieldAtendimentoPara = 'atendimento_para';
const String kFieldSetorSuper = 'setor_superintendencia';
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia';
const String kFieldStatus = 'status';
const String kFieldPrioridade = 'prioridade';
const String kFieldTecnicoResponsavel = 'tecnico_responsavel';
const String kFieldAuthUserDisplay = 'authUserDisplayName';
const String kFieldDataCriacao = 'data_criacao';
const String kFieldDataAtendimento = 'data_atendimento';
const String kFieldSolucao = 'solucao';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldCreatorUid = 'creatorUid';
const String kStatusSolucionado = 'Solucionado';
// Constante do campo de assinatura no documento do USUÁRIO
const String kFieldUserAssinaturaUrl = 'assinatura_url'; // << Campo esperado no doc 'users'

String _formatTimestamp(Timestamp? timestamp, {String format = 'dd/MM/yyyy HH:mm'}) { if (timestamp == null) return '--'; try { return DateFormat(format, 'pt_BR').format(timestamp.toDate()); } catch (e) { return 'Inválida'; } }
String _formatTimestampShort(Timestamp? timestamp) { if (timestamp == null) return 'N/I'; try { return DateFormat('dd/MM/yy', 'pt_BR').format(timestamp.toDate()); } catch (e) { return 'Inv.'; } }
pw.Widget _buildPdfRow(String label, String value, {bool isMultiline = false}) { final cVal = value.trim().isEmpty ? '-' : value.trim(); return pw.Padding( padding: const pw.EdgeInsets.symmetric(vertical: 3.5), child: pw.Row( crossAxisAlignment: isMultiline ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center, children: [ pw.SizedBox( width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), ), pw.SizedBox(width: 10), pw.Expanded( child: isMultiline ? pw.Paragraph(text: cVal, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2)) : pw.Text(cVal, style: const pw.TextStyle(fontSize: 10)), ), ], ), ); }

// --- Função interna para gerar o conteúdo do PDF ---
Future<Uint8List> _buildPdfPageContent(Map<String, dynamic> ticketData, String chamadoId, Uint8List? signatureBytes, String? nomeUsuarioAssinatura) async {
  final pdf = pw.Document(); final DateFormat footerDateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  pw.MemoryImage? signatureMemoryImage; if (signatureBytes != null) { try { signatureMemoryImage = pw.MemoryImage(signatureBytes); } catch (e) { print("Erro MemoryImage: $e"); } }
  final String tipoSolicitante = ticketData[kFieldTipoSolicitante]?.toString() ?? 'N/I'; final String nomeSolicitante = ticketData[kFieldNomeSolicitante]?.toString() ?? 'N/I'; final String celularContato = ticketData[kFieldCelularContato]?.toString() ?? 'N/I'; final String equipamentoSolicitacao = ticketData[kFieldEquipamentoSolicitacao]?.toString() ?? 'N/I'; final String equipamentoOutroDesc = ticketData[kFieldEquipamentoOutro]?.toString() ?? ''; final String conectadoInternet = ticketData[kFieldConectadoInternet]?.toString() ?? 'N/I'; final String marcaModelo = ticketData[kFieldMarcaModelo]?.toString() ?? ''; final String patrimonio = ticketData[kFieldPatrimonio]?.toString() ?? 'N/I'; final String problemaOcorre = ticketData[kFieldProblemaOcorre]?.toString() ?? 'N/I'; final String problemaOutroDesc = ticketData[kFieldProblemaOutro]?.toString() ?? ''; final String? cidade = ticketData[kFieldCidade] as String?; final String? instituicao = ticketData[kFieldInstituicao] as String?; final String? instituicaoManual = ticketData[kFieldInstituicaoManual] as String?; final String? cargoFuncao = ticketData[kFieldCargoFuncao] as String?; final String? atendimentoPara = ticketData[kFieldAtendimentoPara] as String?; final String? setorSuper = ticketData[kFieldSetorSuper] as String?; final String? cidadeSuper = ticketData[kFieldCidadeSuperintendencia] as String?; final String status = ticketData[kFieldStatus]?.toString() ?? 'N/I'; final String prioridade = ticketData[kFieldPrioridade]?.toString() ?? 'N/I'; final String? tecnicoResponsavel = ticketData[kFieldTecnicoResponsavel] as String?; final String? solucao = ticketData[kFieldSolucao] as String?; final String? authUserDisplay = ticketData[kFieldAuthUserDisplay] as String?; final String dtCriacao = _formatTimestamp(ticketData[kFieldDataCriacao] as Timestamp?); final String dtAtendimento = _formatTimestamp(ticketData[kFieldDataAtendimento] as Timestamp?, format: 'dd/MM/yyyy');
  final bool requerenteConfirmou = ticketData[kFieldRequerenteConfirmou] ?? false; final Timestamp? tsConfirmacaoReq = ticketData[kFieldRequerenteConfirmouData] as Timestamp?; final String dtConfirmacaoReq = _formatTimestamp(tsConfirmacaoReq);
  final String nomeConfirmador = nomeUsuarioAssinatura ?? nomeSolicitante;
  String displayInstituicao = instituicao ?? 'N/I'; if (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) { displayInstituicao = instituicaoManual; } String displayEquipamento = equipamentoSolicitacao; if (equipamentoSolicitacao == "OUTRO" && equipamentoOutroDesc.isNotEmpty) { displayEquipamento = "OUTRO: $equipamentoOutroDesc"; } String displayProblema = problemaOcorre; if (problemaOcorre == "OUTRO" && problemaOutroDesc.isNotEmpty) { displayProblema = "OUTRO: $problemaOutroDesc"; }

  pdf.addPage( pw.Page( pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(35), build: (pw.Context context) { return pw.Column( crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ pw.Row( mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ pw.Text('Ordem de Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)), pw.Column( crossAxisAlignment: pw.CrossAxisAlignment.end, children: [ pw.Text('Número OS:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.Text(chamadoId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)), pw.SizedBox(height: 4), pw.Text('Data Criação:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.Text(dtCriacao, style: const pw.TextStyle(fontSize: 10)),])]), pw.Divider(thickness: 1.5, height: 25), pw.Text('Dados da Solicitação', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)), pw.SizedBox(height: 8), _buildPdfRow('Solicitante:', nomeSolicitante), _buildPdfRow('Contato:', celularContato), _buildPdfRow('Tipo:', tipoSolicitante), if (tipoSolicitante == 'ESCOLA') ...[ if (cidade != null) _buildPdfRow('Cidade/Distrito:', cidade), _buildPdfRow('Instituição:', displayInstituicao), if (cargoFuncao != null) _buildPdfRow('Cargo/Função:', cargoFuncao), if (atendimentoPara != null) _buildPdfRow('Atendimento Para:', atendimentoPara), ], if (tipoSolicitante == 'SUPERINTENDENCIA') ...[ if (setorSuper != null) _buildPdfRow('Setor SUPER:', setorSuper), if (cidadeSuper != null) _buildPdfRow('Cidade SUPER:', cidadeSuper), ], pw.Divider(height: 20, thickness: 0.5), pw.Text('Detalhes Técnicos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)), pw.SizedBox(height: 8), _buildPdfRow('Problema Relatado:', displayProblema, isMultiline: true), _buildPdfRow('Equipamento:', displayEquipamento), if (marcaModelo.isNotEmpty) _buildPdfRow('Marca/Modelo:', marcaModelo), _buildPdfRow('Patrimônio:', patrimonio), _buildPdfRow('Conectado à Internet:', conectadoInternet), pw.Divider(height: 20, thickness: 0.5), pw.Text('Status e Andamento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)), pw.SizedBox(height: 8), _buildPdfRow('Status Atual:', status), _buildPdfRow('Prioridade:', prioridade), if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) _buildPdfRow('Técnico Responsável:', tecnicoResponsavel), _buildPdfRow('Data de Atendimento:', dtAtendimento), if (authUserDisplay != null && authUserDisplay.isNotEmpty) _buildPdfRow('Registrado por:', authUserDisplay),
             if (status == kStatusSolucionado && solucao != null && solucao.isNotEmpty) ...[ pw.Divider(height: 20, thickness: 0.5), pw.Text('Solução/Diagnóstico', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)), pw.SizedBox(height: 8), pw.Paragraph( text: solucao, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5), ), ],
             pw.Divider(height: 25, thickness: 1.0), pw.Text('Confirmação do Requerente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blueGrey800)), pw.SizedBox(height: 8),
             requerenteConfirmou
               ? pw.Column( crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ if(signatureMemoryImage != null) pw.Container( alignment: pw.Alignment.centerLeft, margin: const pw.EdgeInsets.only(bottom: 5), padding: const pw.EdgeInsets.symmetric(vertical: 5), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))), height: 40, width: 160, child: pw.Image(signatureMemoryImage)), _buildPdfRow(signatureMemoryImage != null ? 'Assinado por:' : 'Confirmado por:', nomeConfirmador), _buildPdfRow('Data Confirmação:', dtConfirmacaoReq), if(signatureMemoryImage == null) pw.Text('(Assinatura digital indisponível)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)) ])
               : _buildPdfRow('Status Confirmação:', 'Pendente de confirmação'),
             pw.Spacer(), pw.Divider(), pw.Align( alignment: pw.Alignment.centerRight, child: pw.Text( 'Gerado em: ${footerDateFormatter.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600), ), ) ], ); }, ), );
  return pdf.save();
}


// --- FUNÇÃO AUXILIAR PARA BUSCAR DADOS DO USER E ASSINATURA ---
Future<Map<String, dynamic>?> _fetchUserDataAndSignature(String? userId) async {
  if (userId == null || userId.isEmpty) return null;
  try {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!userDoc.exists || userDoc.data() == null) return null;

    final userData = userDoc.data()!;
    final signatureUrl = userData['assinatura_url'] as String?; // Usa constante se definida
    Uint8List? signatureBytes;

    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        // Tenta baixar usando http (ou firebase_storage.refFromURL().getData())
        final response = await http.get(Uri.parse(signatureUrl));
        if (response.statusCode == 200) {
          signatureBytes = response.bodyBytes;
        } else {
           print("Erro ao baixar assinatura do Storage: Status ${response.statusCode}");
        }
      } catch (e) {
        print("Erro no download da assinatura do Storage: $e");
      }
    }
    return {
      'userData': userData, // Retorna dados do usuário
      'signatureBytes': signatureBytes, // Retorna bytes da assinatura (ou null)
    };
  } catch (e) {
    print("Erro ao buscar dados do usuário $userId: $e");
    return null;
  }
}


enum PdfShareResult { success, dismissed, error }
Future<PdfShareResult> generateAndSharePdfForTicket({ required BuildContext context, required String chamadoId, required Map<String, dynamic> dadosChamado}) async {
  showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  Uint8List? signatureBytes;
  Map<String, dynamic>? userData;
  String? nomeUsuarioAssinatura;
  final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context

  try {
    // Busca dados do usuário e assinatura ANTES de gerar o PDF
    final creatorUid = dadosChamado[kFieldCreatorUid] as String?;
    final fetchResult = await _fetchUserDataAndSignature(creatorUid);
    if (fetchResult != null) {
       userData = fetchResult['userData'];
       signatureBytes = fetchResult['signatureBytes'];
       nomeUsuarioAssinatura = userData?['name'] as String?;
    }

    final Uint8List pdfBytes = await _buildPdfPageContent(dadosChamado, chamadoId, signatureBytes, nomeUsuarioAssinatura); // Chama a função interna de build
    final tempDir = await getTemporaryDirectory(); final filePath = '${tempDir.path}/OS_${chamadoId.substring(0,6)}_share.pdf'; final file = File(filePath); await file.writeAsBytes(pdfBytes);
    try { if(Navigator.of(context).canPop()) Navigator.of(context, rootNavigator: true).pop(); } catch (_) {} // Fecha dialog
    final shareTitle = 'Ordem de Serviço: ${chamadoId.substring(0,6)}';
    final result = await Share.shareXFiles( [XFile(filePath)], subject: shareTitle, text: 'Segue OS ${chamadoId.substring(0,6)}.' );
    if (result.status == ShareResultStatus.success) return PdfShareResult.success;
    if (result.status == ShareResultStatus.dismissed) return PdfShareResult.dismissed;
    return PdfShareResult.success;
  } catch (e) {
    print("Erro gerar/compartilhar PDF OS $chamadoId: $e");
    try { if(Navigator.of(context).canPop()) Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao gerar/compartilhar PDF: $e'), backgroundColor: Colors.red));
    return PdfShareResult.error;
  }
}

enum PdfOpenResult { success, errorCantOpen, errorGenerating }
Future<PdfOpenResult> generateAndOpenPdfForTicket({ required BuildContext context, required String chamadoId, required Map<String, dynamic> dadosChamado}) async {
   showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
   Uint8List? signatureBytes;
   Map<String, dynamic>? userData;
   String? nomeUsuarioAssinatura;
   final scaffoldMessenger = ScaffoldMessenger.of(context);

   try {
      final creatorUid = dadosChamado[kFieldCreatorUid] as String?;
      final fetchResult = await _fetchUserDataAndSignature(creatorUid);
      if (fetchResult != null) {
         userData = fetchResult['userData'];
         signatureBytes = fetchResult['signatureBytes'];
         nomeUsuarioAssinatura = userData?['name'] as String?;
      }

      final Uint8List pdfBytes = await _buildPdfPageContent(dadosChamado, chamadoId, signatureBytes, nomeUsuarioAssinatura);
      final tempDir = await getTemporaryDirectory(); final filePath = '${tempDir.path}/OS_${chamadoId.substring(0,6)}_${DateTime.now().millisecondsSinceEpoch}.pdf'; final file = File(filePath); await file.writeAsBytes(pdfBytes);
      try { if(Navigator.of(context).canPop()) Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
      final result = await OpenFilex.open(filePath);
      if (result.type == ResultType.done) { print('PDF $filePath aberto.'); return PdfOpenResult.success; }
      else { print('Erro abrir PDF: ${result.message}'); scaffoldMessenger.showSnackBar(SnackBar(content: Text('Não foi possível abrir o PDF: ${result.message}'), backgroundColor: Colors.orange)); return PdfOpenResult.errorCantOpen; }
   } catch (e) {
      print("Erro gerar/abrir PDF OS $chamadoId: $e");
      try { if(Navigator.of(context).canPop()) Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao gerar/abrir PDF: $e'), backgroundColor: Colors.red));
      return PdfOpenResult.errorGenerating;
   }
}

Future<Uint8List> generateTicketListPdf(List<QueryDocumentSnapshot> tickets) async {
  final pdf = pw.Document(); final DateFormat footerListDateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR'); const int ticketsPerPage = 18; List<List<QueryDocumentSnapshot>> pagesData = []; for (var i = 0; i < tickets.length; i += ticketsPerPage) { pagesData.add( tickets.sublist(i, min(i + ticketsPerPage, tickets.length)) ); }
  final List<String> headers = <String>[ 'Abertura', 'Tipo', 'Solicitante', 'Local/Setor', 'Problema', 'Equip.', 'Patrimônio', 'Status', ];
  for (var pageTickets in pagesData) { pdf.addPage( pw.MultiPage( pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 30), header: (pw.Context context) => pw.Container( alignment: pw.Alignment.center, margin: const pw.EdgeInsets.only(bottom: 15.0), child: pw.Text( 'Relatório de Ordens de Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))), footer: (pw.Context context) => pw.Row( mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [ pw.Text( 'Gerado em: ${footerListDateFormatter.format(DateTime.now())}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey, fontSize: 9)), pw.Text( 'Página ${context.pageNumber} de ${context.pagesCount}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey, fontSize: 9)), ]), build: (pw.Context context) => [ pw.Table.fromTextArray( border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5), cellAlignment: pw.Alignment.centerLeft, headerDecoration: const pw.BoxDecoration( borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)), color: PdfColors.grey300 ), headerHeight: 25, cellHeight: 30, cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), cellStyle: const pw.TextStyle(fontSize: 8), rowDecoration: const pw.BoxDecoration( border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)) ), headers: headers, data: pageTickets.map((ticketDoc) { final data = ticketDoc.data() as Map<String, dynamic>; final String dtAbertura = _formatTimestampShort(data[kFieldDataCriacao] as Timestamp?); final String tipoRaw = data[kFieldTipoSolicitante]?.toString() ?? 'N/I'; final String tipo = tipoRaw.substring(0, min(15, tipoRaw.length)); final String solicitante = data[kFieldNomeSolicitante]?.toString() ?? 'N/I'; final String? cidadeList = data[kFieldCidade] as String?; final String? instituicaoList = data[kFieldInstituicao] as String?; final String? instituicaoManualList = data[kFieldInstituicaoManual] as String?; String displayInstituicaoList = instituicaoList ?? 'N/I'; if (cidadeList == "OUTRO" && instituicaoManualList != null && instituicaoManualList.isNotEmpty) { displayInstituicaoList = instituicaoManualList; } final String localSetor = tipoRaw == 'ESCOLA' ? displayInstituicaoList : (data[kFieldSetorSuper]?.toString() ?? 'N/I'); final String localSetorShort = localSetor.length > 35 ? '${localSetor.substring(0, 32)}...' : localSetor; final String problemaOcorreList = data[kFieldProblemaOcorre]?.toString() ?? 'N/I'; final String problemaOutroDescList = data[kFieldProblemaOutro]?.toString() ?? ''; String displayProblemaList = problemaOcorreList; if (problemaOcorreList == "OUTRO" && problemaOutroDescList.isNotEmpty) { displayProblemaList = "OUTRO: $problemaOutroDescList"; } final String problemaShort = displayProblemaList.length > 30 ? '${displayProblemaList.substring(0, 27)}...' : displayProblemaList; final String equipamentoRaw = data[kFieldEquipamentoSolicitacao]?.toString() ?? 'N/I'; final String equipamentoShort = equipamentoRaw.length > 20 ? '${equipamentoRaw.substring(0, 17)}...' : equipamentoRaw; final String patrimonio = data[kFieldPatrimonio]?.toString() ?? 'N/I'; final String status = data[kFieldStatus]?.toString() ?? 'N/I'; return <String>[ dtAbertura, tipo, solicitante, localSetorShort, problemaShort, equipamentoShort, patrimonio, status, ]; }).toList(), columnWidths: { 0: const pw.FixedColumnWidth(50), 1: const pw.FixedColumnWidth(60), 2: const pw.FlexColumnWidth(2.5), 3: const pw.FlexColumnWidth(3.5), 4: const pw.FlexColumnWidth(3.0), 5: const pw.FlexColumnWidth(2.0), 6: const pw.FixedColumnWidth(70), 7: const pw.FixedColumnWidth(70), } ), ], ), ); }
  return pdf.save();
}