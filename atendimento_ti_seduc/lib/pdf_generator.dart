// lib/pdf_generator.dart

import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;

// Importando constantes do seu ChamadoService para centralizar definições
// Certifique-se que o caminho para chamado_service.dart está correto.
// Se este arquivo estiver em /lib/utils/ e chamado_service.dart em /lib/services/
// o caminho seria '../services/chamado_service.dart'
// Se você não importar, garanta que as constantes abaixo sejam idênticas às de ChamadoService.dart
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
const String kFieldTecnicoUid = 'tecnicoUid'; // IMPORTANTE: Use este campo em dadosChamado para o UID do técnico da solução
const String kFieldAuthUserDisplay = 'authUserDisplayName';
const String kFieldDataCriacao = 'data_criacao';
const String kFieldDataAtendimento = 'data_atendimento';
const String kFieldSolucao = 'solucao';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldRequerenteConfirmouUid = 'requerente_confirmou_uid';
const String kFieldCreatorUid = 'creatorUid';
const String kFieldUserAssinaturaUrl = 'assinatura_url'; 

const String kFieldAdminFinalizou = 'adminFinalizou';
const String kFieldAdminFinalizouData = 'adminFinalizouData';
const String kFieldAdminFinalizouUid = 'adminFinalizouUid';
const String kFieldAdminFinalizouNome = 'adminFinalizouNome';

// Usando "Solucionado" conforme sua última confirmação
const String kStatusSolucionadoPdf = 'Solucionado'; 


String _formatTimestamp(Timestamp? timestamp, {String format = 'dd/MM/yyyy HH:mm'}) { 
  if (timestamp == null) return '--'; 
  try { return DateFormat(format, 'pt_BR').format(timestamp.toDate()); } catch (e) { return 'Data Inválida'; } 
}
String _formatTimestampShort(Timestamp? timestamp) { 
  if (timestamp == null) return 'N/I'; 
  try { return DateFormat('dd/MM/yy', 'pt_BR').format(timestamp.toDate()); } catch (e) { return 'Inv.'; } 
}

pw.Widget _buildPdfRow(String label, String value, {bool isMultiline = false, double fontSize = 9.5}) { 
  final cVal = value.trim().isEmpty ? '--' : value.trim(); 
  return pw.Padding( 
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5), 
    child: pw.Row( 
      crossAxisAlignment: isMultiline ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center, 
      children: [ 
        pw.SizedBox( 
          width: 115, 
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize)), 
        ), 
        pw.SizedBox(width: 5), 
        pw.Expanded( 
          child: isMultiline 
            ? pw.Paragraph(text: cVal, style: pw.TextStyle(fontSize: fontSize, lineSpacing: 1.1)) 
            : pw.Text(cVal, style: pw.TextStyle(fontSize: fontSize)), 
        ), 
      ], 
    ), 
  ); 
}

Future<Uint8List> _buildPdfPageContent(
  Map<String, dynamic> ticketData, 
  String chamadoId, 
  Uint8List? requerenteSignatureBytes, 
  String? nomeRequerenteParaAssinatura,
  Uint8List? adminFinalizadorSignatureBytes, 
  String? nomeAdminFinalizadorParaAssinatura
) async {
  final pdf = pw.Document(); 
  final DateFormat footerDateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  
  pw.MemoryImage? requerenteMemoryImage; 
  if (requerenteSignatureBytes != null) { 
    try { requerenteMemoryImage = pw.MemoryImage(requerenteSignatureBytes); } catch (e) { print("Erro MemoryImage Assinatura Requerente: $e"); } 
  }

  pw.MemoryImage? adminFinalizadorMemoryImage; 
  if (adminFinalizadorSignatureBytes != null) { 
    try { adminFinalizadorMemoryImage = pw.MemoryImage(adminFinalizadorSignatureBytes); } catch (e) { print("Erro MemoryImage Assinatura Admin Finalizador: $e"); }
  }

  final String tipoSolicitante = ticketData[kFieldTipoSolicitante]?.toString() ?? 'N/I'; 
  final String nomeSolicitanteOriginal = ticketData[kFieldNomeSolicitante]?.toString() ?? 'N/I'; 
  final String celularContato = ticketData[kFieldCelularContato]?.toString() ?? 'N/I'; 
  final String equipamentoSolicitacao = ticketData[kFieldEquipamentoSolicitacao]?.toString() ?? 'N/I'; 
  final String equipamentoOutroDesc = ticketData[kFieldEquipamentoOutro]?.toString() ?? ''; 
  final String conectadoInternet = ticketData[kFieldConectadoInternet]?.toString() ?? 'N/I'; 
  final String marcaModelo = ticketData[kFieldMarcaModelo]?.toString() ?? ''; 
  final String patrimonio = ticketData[kFieldPatrimonio]?.toString() ?? 'N/I'; 
  final String problemaOcorre = ticketData[kFieldProblemaOcorre]?.toString() ?? 'N/I'; 
  final String problemaOutroDesc = ticketData[kFieldProblemaOutro]?.toString() ?? ''; 
  final String? cidade = ticketData[kFieldCidade] as String?; 
  final String? instituicao = ticketData[kFieldInstituicao] as String?; 
  final String? instituicaoManual = ticketData[kFieldInstituicaoManual] as String?; 
  final String? cargoFuncao = ticketData[kFieldCargoFuncao] as String?; 
  final String? atendimentoPara = ticketData[kFieldAtendimentoPara] as String?; 
  final String? setorSuper = ticketData[kFieldSetorSuper] as String?; 
  final String? cidadeSuper = ticketData[kFieldCidadeSuperintendencia] as String?; 
  final String status = ticketData[kFieldStatus]?.toString() ?? 'N/I'; 
  final String prioridade = ticketData[kFieldPrioridade]?.toString() ?? 'N/I'; 
  final String? tecnicoResponsavelNomeOriginal = ticketData[kFieldTecnicoResponsavel] as String?; 
  final String? solucao = ticketData[kFieldSolucao] as String?; 
  final String? authUserDisplay = ticketData[kFieldAuthUserDisplay] as String?; 
  final String dtCriacao = _formatTimestamp(ticketData[kFieldDataCriacao] as Timestamp?); 
  final String dtAtendimento = _formatTimestamp(ticketData[kFieldDataAtendimento] as Timestamp?, format: 'dd/MM/yyyy');
  final bool requerenteConfirmou = ticketData[kFieldRequerenteConfirmou] ?? false; 
  final Timestamp? tsConfirmacaoReq = ticketData[kFieldRequerenteConfirmouData] as Timestamp?; 
  final String dtConfirmacaoReq = _formatTimestamp(tsConfirmacaoReq);
  
  final String nomeDisplayRequerente = nomeRequerenteParaAssinatura ?? nomeSolicitanteOriginal;
  
  final bool adminFinalizou = ticketData[kFieldAdminFinalizou] as bool? ?? false;
  // Usa o nome do admin que finalizou passado como parâmetro (que já tem fallback do fetch)
  // ou o nome salvo diretamente no chamado se o parâmetro for nulo.
  final String nomeDisplayAdminFinalizadorEfetivo = nomeAdminFinalizadorParaAssinatura ?? ticketData[kFieldAdminFinalizouNome] as String? ?? "Admin não especificado";
  final String dtAdminFinalizou = _formatTimestamp(ticketData[kFieldAdminFinalizouData] as Timestamp?);

  String displayInstituicao = instituicao ?? 'N/I'; 
  if (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) { displayInstituicao = instituicaoManual; } 
  String displayEquipamento = equipamentoSolicitacao; 
  if (equipamentoSolicitacao == "OUTRO" && equipamentoOutroDesc.isNotEmpty) { displayEquipamento = "OUTRO: $equipamentoOutroDesc"; } 
  String displayProblema = problemaOcorre; 
  if (problemaOcorre == "OUTRO" && problemaOutroDesc.isNotEmpty) { displayProblema = "OUTRO: $problemaOutroDesc"; }

  pdf.addPage( 
    pw.MultiPage( 
      pageFormat: PdfPageFormat.a4, 
      margin: const pw.EdgeInsets.all(30), 
      header: (pw.Context context) { 
        return pw.Column(children: [
           pw.Row( mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ pw.Text('Ordem de Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)), pw.Column( crossAxisAlignment: pw.CrossAxisAlignment.end, children: [ pw.Text('Número OS:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)), pw.Text(chamadoId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.SizedBox(height: 3), pw.Text('Data Criação:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)), pw.Text(dtCriacao, style: const pw.TextStyle(fontSize: 9)),])]), pw.Divider(thickness: 1.2, height: 20),
        ]);
      },
      footer: (pw.Context context) { 
        return pw.Align( 
          alignment: pw.Alignment.centerRight, 
          child: pw.Text( 
            'Página ${context.pageNumber} de ${context.pagesCount} | Gerado em: ${footerDateFormatter.format(DateTime.now())}', 
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500), 
          ), 
        );
      },
      build: (pw.Context context) { 
        List<pw.Widget> widgets = [];

        widgets.addAll([
          pw.Text('Dados da Solicitação', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)), 
          pw.SizedBox(height: 6),
          _buildPdfRow('Solicitante:', nomeSolicitanteOriginal), 
          _buildPdfRow('Contato:', celularContato),
          _buildPdfRow('Tipo:', tipoSolicitante), 
          if (tipoSolicitante == 'ESCOLA') ...[ if (cidade != null) _buildPdfRow('Cidade/Distrito:', cidade), _buildPdfRow('Instituição:', displayInstituicao), if (cargoFuncao != null) _buildPdfRow('Cargo/Função:', cargoFuncao), if (atendimentoPara != null) _buildPdfRow('Atendimento Para:', atendimentoPara), ], if (tipoSolicitante == 'SUPERINTENDENCIA') ...[ if (setorSuper != null) _buildPdfRow('Setor SUPER:', setorSuper), if (cidadeSuper != null) _buildPdfRow('Cidade SUPER:', cidadeSuper), ], 
          pw.Divider(height: 15, thickness: 0.5),
          pw.Text('Detalhes Técnicos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)), 
          pw.SizedBox(height: 6),
          _buildPdfRow('Problema Relatado:', displayProblema, isMultiline: true),
          _buildPdfRow('Equipamento:', displayEquipamento), if (marcaModelo.isNotEmpty) _buildPdfRow('Marca/Modelo:', marcaModelo), _buildPdfRow('Patrimônio:', patrimonio), _buildPdfRow('Conectado à Internet:', conectadoInternet), 
          pw.Divider(height: 15, thickness: 0.5),
          pw.Text('Status e Andamento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)), 
          pw.SizedBox(height: 6),
          _buildPdfRow('Status Atual:', status),
          _buildPdfRow('Prioridade:', prioridade), 
          if (tecnicoResponsavelNomeOriginal != null && tecnicoResponsavelNomeOriginal.isNotEmpty) 
              _buildPdfRow('Técnico Atribuído:', tecnicoResponsavelNomeOriginal),
          _buildPdfRow('Data de Atendimento:', dtAtendimento), 
          if (authUserDisplay != null && authUserDisplay.isNotEmpty) _buildPdfRow('Registrado por:', authUserDisplay),
        ]);
        
        if (status.toLowerCase() == kStatusSolucionadoPdf.toLowerCase() && solucao != null && solucao.isNotEmpty) {
          widgets.addAll([
            pw.Divider(height: 15, thickness: 0.5),
            pw.Text('Solução/Diagnóstico Técnico', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 6),
            pw.Paragraph(text: solucao, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3)),
            pw.SizedBox(height: 6),
          ]);
        }
        
        widgets.addAll([
          pw.Divider(height: 20, thickness: 1.0),
          pw.Text('Confirmação do Requerente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)),
          pw.SizedBox(height: 6),
          requerenteConfirmou
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (requerenteMemoryImage != null)
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        margin: const pw.EdgeInsets.only(bottom: 2),
                        height: 30, width: 120,
                        child: pw.Image(requerenteMemoryImage)),
                    _buildPdfRow(requerenteMemoryImage != null ? 'Assinado Digitalmente Por:' : 'Confirmado Por:', nomeDisplayRequerente, fontSize: 9),
                    _buildPdfRow('Data da Confirmação:', dtConfirmacaoReq, fontSize: 9),
                    if (requerenteMemoryImage == null)
                      pw.Text('(Assinatura digital do requerente indisponível)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500))
                  ])
              : _buildPdfRow('Status da Confirmação:', 'Pendente de confirmação pelo requerente', fontSize: 9),
        ]);

        if (adminFinalizou) {
          widgets.addAll([
            pw.Divider(height: 15, thickness: 0.5),
            pw.Text('Finalização Administrativa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 6),
            if (adminFinalizadorMemoryImage != null)
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                margin: const pw.EdgeInsets.only(bottom: 2),
                height: 30, width: 120,
                child: pw.Image(adminFinalizadorMemoryImage),
              ),
            _buildPdfRow('Finalizado por (Admin):', nomeDisplayAdminFinalizadorEfetivo, fontSize: 9), // VARIÁVEL CORRIGIDA
            _buildPdfRow('Data da Finalização:', dtAdminFinalizou, fontSize: 9),
            if (adminFinalizadorMemoryImage == null && nomeDisplayAdminFinalizadorEfetivo != "Admin não especificado" && nomeDisplayAdminFinalizadorEfetivo.isNotEmpty)
              pw.Text('(Assinatura digital do admin indisponível)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          ]);
        } else if (status.toLowerCase() == kStatusSolucionadoPdf.toLowerCase() && tecnicoResponsavelNomeOriginal != null && tecnicoResponsavelNomeOriginal.isNotEmpty) {
           widgets.addAll([
            pw.Divider(height: 15, thickness: 0.5),
            pw.Text('Serviço Realizado Por', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 6),
             _buildPdfRow('Técnico:', tecnicoResponsavelNomeOriginal, fontSize: 9),
           ]);
        }
        
        widgets.add(pw.Spacer());
        widgets.add(pw.Divider(height: 10, thickness: 0.5));
        return widgets;
      }, 
    ),
  );
  return pdf.save();
}

Future<Map<String, dynamic>?> _fetchUserDataAndSignature(String? userId) async {
  if (userId == null || userId.isEmpty) {
    print("[PDF_USER_FETCH] User ID nulo ou vazio.");
    return null;
  }
  print("[PDF_USER_FETCH] Buscando dados para userId: $userId");
  try {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!userDoc.exists || userDoc.data() == null) {
      print("[PDF_USER_FETCH] Documento do usuário $userId não encontrado.");
      return {'userData': {'name': 'Usuário ($userId) não encontrado'}, 'userName': 'Usuário ($userId) não encontrado', 'signatureBytes': null};
    }

    final userData = userDoc.data()!;
    final signatureUrl = userData[kFieldUserAssinaturaUrl] as String?; 
    Uint8List? signatureBytes;
    String? userName = userData['name'] as String? ?? userData['displayName'] as String? ?? "Nome Indisponível";

    print("[PDF_USER_FETCH] User $userId Data: $userData");
    print("[PDF_USER_FETCH] User $userId Signature URL: $signatureUrl");

    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(signatureUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          signatureBytes = response.bodyBytes;
          print("[PDF_USER_FETCH] Assinatura baixada para $userId (${signatureBytes.lengthInBytes} bytes).");
        } else {
          print("[PDF_USER_FETCH] Erro HTTP ${response.statusCode} ao baixar assinatura de $signatureUrl");
        }
      } catch (e) {
        print("[PDF_USER_FETCH] Exceção ao baixar assinatura de $signatureUrl: $e");
      }
    } else {
      print("[PDF_USER_FETCH] URL da assinatura nula/vazia para $userId.");
    }
    return {
      'userData': userData, 
      'userName': userName, 
      'signatureBytes': signatureBytes, 
    };
  } catch (e) {
    print("[PDF_USER_FETCH] Erro geral ao buscar dados do usuário $userId: $e");
    return {'userData': {'name': 'Erro ao buscar usuário ($userId)'},'userName': 'Erro ao buscar usuário ($userId)', 'signatureBytes': null};
  }
}

enum PdfOpenResult { success, errorCantOpen, errorGenerating }
enum PdfShareResult { success, dismissed, error, unavailable }

Future<PdfOpenResult> generateAndOpenPdfForTicket({
  required BuildContext context, 
  required String chamadoId,
  required Map<String, dynamic> dadosChamado,
}) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  Uint8List? requerenteSignatureBytes;
  String? nomeRequerenteParaAssinatura;
  Uint8List? adminFinalizadorSignatureBytes;
  String? nomeAdminFinalizadorParaAssinatura;

  try {
    final String? uidParaAssinaturaRequerente = dadosChamado[kFieldRequerenteConfirmouUid] as String? ?? dadosChamado[kFieldCreatorUid] as String?;
    final requerenteFetchResult = await _fetchUserDataAndSignature(uidParaAssinaturaRequerente);
    if (requerenteFetchResult != null) {
      nomeRequerenteParaAssinatura = requerenteFetchResult['userName'] as String?;
      requerenteSignatureBytes = requerenteFetchResult['signatureBytes'] as Uint8List?;
    }

    final bool adminFinalizou = dadosChamado[kFieldAdminFinalizou] as bool? ?? false;
    if (adminFinalizou) {
      final String? adminUid = dadosChamado[kFieldAdminFinalizouUid] as String?;
      if (adminUid != null && adminUid.isNotEmpty) {
        final adminFetchResult = await _fetchUserDataAndSignature(adminUid);
        if (adminFetchResult != null) {
          nomeAdminFinalizadorParaAssinatura = adminFetchResult['userName'] as String?;
          adminFinalizadorSignatureBytes = adminFetchResult['signatureBytes'] as Uint8List?;
        }
      } else {
        nomeAdminFinalizadorParaAssinatura = dadosChamado[kFieldAdminFinalizouNome] as String?;
      }
    } else {
      final String? tecnicoSolucaoUid = dadosChamado[kFieldTecnicoUid] as String?; 
      if (tecnicoSolucaoUid != null && tecnicoSolucaoUid.isNotEmpty) {
         final tecnicoFetchResult = await _fetchUserDataAndSignature(tecnicoSolucaoUid);
         if (tecnicoFetchResult != null) {
           nomeAdminFinalizadorParaAssinatura = tecnicoFetchResult['userName'] as String?;
           adminFinalizadorSignatureBytes = tecnicoFetchResult['signatureBytes'] as Uint8List?;
         }
      } else {
          nomeAdminFinalizadorParaAssinatura = dadosChamado[kFieldTecnicoResponsavel] as String?;
      }
    }

    final Uint8List pdfBytes = await _buildPdfPageContent(
      dadosChamado, 
      chamadoId, 
      requerenteSignatureBytes, 
      nomeRequerenteParaAssinatura,
      adminFinalizadorSignatureBytes, 
      nomeAdminFinalizadorParaAssinatura  
    );
      
    final tempDir = await getTemporaryDirectory(); 
    final filePath = '${tempDir.path}/OS_${chamadoId.substring(0,min(6, chamadoId.length))}_${DateTime.now().millisecondsSinceEpoch}.pdf'; 
    final file = File(filePath); 
    await file.writeAsBytes(pdfBytes);
            
    final result = await OpenFilex.open(filePath);
    if (result.type == ResultType.done) { 
      print('PDF $filePath aberto com sucesso.'); 
      return PdfOpenResult.success; 
    } else { 
      print('Erro ao abrir PDF $filePath: ${result.message}'); 
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Não foi possível abrir o PDF: ${result.message}'), backgroundColor: Colors.orange));
      return PdfOpenResult.errorCantOpen; 
    }
  } catch (e, s) { 
    print("Erro em generateAndOpenPdfForTicket para OS $chamadoId: $e\nStackTrace: $s");
    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro crítico ao gerar o PDF: ${e.toString()}'), backgroundColor: Colors.red));
    return PdfOpenResult.errorGenerating;
  }
}

Future<PdfShareResult> generateAndSharePdfForTicket({ 
  required BuildContext context,
  required String chamadoId, 
  required Map<String, dynamic> dadosChamado
}) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

  Uint8List? requerenteSignatureBytes;
  String? nomeRequerenteParaAssinatura;
  Uint8List? adminFinalizadorSignatureBytes;
  String? nomeAdminFinalizadorParaAssinatura;

  try {
    final String? uidParaAssinaturaRequerente = dadosChamado[kFieldRequerenteConfirmouUid] as String? ?? dadosChamado[kFieldCreatorUid] as String?;
    final requerenteFetchResult = await _fetchUserDataAndSignature(uidParaAssinaturaRequerente);
    if (requerenteFetchResult != null) {
      nomeRequerenteParaAssinatura = requerenteFetchResult['userName'] as String?;
      requerenteSignatureBytes = requerenteFetchResult['signatureBytes'] as Uint8List?;
    }

    final bool adminFinalizou = dadosChamado[kFieldAdminFinalizou] as bool? ?? false;
    if (adminFinalizou) {
      final String? adminUid = dadosChamado[kFieldAdminFinalizouUid] as String?;
      if (adminUid != null && adminUid.isNotEmpty) {
        final adminFetchResult = await _fetchUserDataAndSignature(adminUid);
        if (adminFetchResult != null) {
          nomeAdminFinalizadorParaAssinatura = adminFetchResult['userName'] as String?;
          adminFinalizadorSignatureBytes = adminFetchResult['signatureBytes'] as Uint8List?;
        }
      } else {
        nomeAdminFinalizadorParaAssinatura = dadosChamado[kFieldAdminFinalizouNome] as String?;
      }
    } else {
       final String? tecnicoSolucaoUid = dadosChamado[kFieldTecnicoUid] as String?; 
       if (tecnicoSolucaoUid != null && tecnicoSolucaoUid.isNotEmpty) {
         final tecnicoFetchResult = await _fetchUserDataAndSignature(tecnicoSolucaoUid);
         if (tecnicoFetchResult != null) {
           nomeAdminFinalizadorParaAssinatura = tecnicoFetchResult['userName'] as String?;
           adminFinalizadorSignatureBytes = tecnicoFetchResult['signatureBytes'] as Uint8List?;
         }
       } else {
          nomeAdminFinalizadorParaAssinatura = dadosChamado[kFieldTecnicoResponsavel] as String?;
       }
    }

    final Uint8List pdfBytes = await _buildPdfPageContent(
        dadosChamado, 
        chamadoId, 
        requerenteSignatureBytes, 
        nomeRequerenteParaAssinatura,
        adminFinalizadorSignatureBytes,
        nomeAdminFinalizadorParaAssinatura
    );
    final tempDir = await getTemporaryDirectory(); 
    final filePath = '${tempDir.path}/OS_${chamadoId.substring(0,min(6, chamadoId.length))}_share.pdf'; 
    final file = File(filePath); 
    await file.writeAsBytes(pdfBytes);
    
    if(Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop(); 
    }

    final shareTitle = 'Ordem de Serviço: ${chamadoId.substring(0,min(6, chamadoId.length))}';
    final result = await Share.shareXFiles( [XFile(filePath)], subject: shareTitle, text: 'Segue OS ${chamadoId.substring(0,min(6, chamadoId.length))}.' );
    
    if (result.status == ShareResultStatus.success) return PdfShareResult.success;
    if (result.status == ShareResultStatus.dismissed) return PdfShareResult.dismissed;
    if (result.status == ShareResultStatus.unavailable) return PdfShareResult.unavailable;
    return PdfShareResult.error;
  } catch (e,s) {
    print("Erro gerar/compartilhar PDF OS $chamadoId: $e\n$s");
    if(Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop(); 
    }
    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao gerar/compartilhar PDF: $e'), backgroundColor: Colors.red));
    return PdfShareResult.error;
  }
}

Future<Uint8List> generateTicketListPdf(List<QueryDocumentSnapshot> tickets) async {
  final pdf = pw.Document(); 
  final DateFormat footerListDateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR'); 
  const int ticketsPerPage = 18; 
  List<List<QueryDocumentSnapshot>> pagesData = []; 
  for (var i = 0; i < tickets.length; i += ticketsPerPage) { 
    pagesData.add( tickets.sublist(i, min(i + ticketsPerPage, tickets.length)) ); 
  }
  final List<String> headers = <String>[ 'Abertura', 'Tipo', 'Solicitante', 'Local/Setor', 'Problema', 'Equip.', 'Patrimônio', 'Status', ];
  for (var pageTickets in pagesData) { 
    pdf.addPage( pw.MultiPage( 
      pageFormat: PdfPageFormat.a4.landscape, 
      margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 30), 
      header: (pw.Context context) => pw.Container( alignment: pw.Alignment.center, margin: const pw.EdgeInsets.only(bottom: 15.0), child: pw.Text( 'Relatório de Ordens de Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))), 
      footer: (pw.Context context) => pw.Row( mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [ pw.Text( 'Gerado em: ${footerListDateFormatter.format(DateTime.now())}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey, fontSize: 9)), pw.Text( 'Página ${context.pageNumber} de ${context.pagesCount}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey, fontSize: 9)), ]), 
      build: (pw.Context context) => [ 
        pw.Table.fromTextArray( 
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5), 
            cellAlignment: pw.Alignment.centerLeft, 
            headerDecoration: const pw.BoxDecoration( borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)), color: PdfColors.grey300 ), 
            headerHeight: 25, 
            cellHeight: 30, 
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5), // CORRIGIDO
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), 
            cellStyle: const pw.TextStyle(fontSize: 8), 
            rowDecoration: const pw.BoxDecoration( border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)) ), 
            headers: headers, 
            data: pageTickets.map((ticketDoc) { 
              final data = ticketDoc.data() as Map<String, dynamic>; 
              final String dtAbertura = _formatTimestampShort(data[kFieldDataCriacao] as Timestamp?); 
              final String tipoRaw = data[kFieldTipoSolicitante]?.toString() ?? 'N/I'; 
              final String tipo = tipoRaw.substring(0, min(15, tipoRaw.length)); 
              final String solicitante = data[kFieldNomeSolicitante]?.toString() ?? 'N/I'; 
              final String? cidadeList = data[kFieldCidade] as String?; 
              final String? instituicaoList = data[kFieldInstituicao] as String?; 
              final String? instituicaoManualList = data[kFieldInstituicaoManual] as String?; 
              String displayInstituicaoList = instituicaoList ?? 'N/I'; 
              if (cidadeList == "OUTRO" && instituicaoManualList != null && instituicaoManualList.isNotEmpty) { displayInstituicaoList = instituicaoManualList; } 
              final String localSetor = tipoRaw == 'ESCOLA' ? displayInstituicaoList : (data[kFieldSetorSuper]?.toString() ?? 'N/I'); 
              final String localSetorShort = localSetor.length > 35 ? '${localSetor.substring(0, 32)}...' : localSetor; 
              final String problemaOcorreList = data[kFieldProblemaOcorre]?.toString() ?? 'N/I'; 
              final String problemaOutroDescList = data[kFieldProblemaOutro]?.toString() ?? ''; 
              String displayProblemaList = problemaOcorreList; 
              if (problemaOcorreList == "OUTRO" && problemaOutroDescList.isNotEmpty) { displayProblemaList = "OUTRO: $problemaOutroDescList"; } 
              final String problemaShort = displayProblemaList.length > 30 ? '${displayProblemaList.substring(0, 27)}...' : displayProblemaList; 
              final String equipamentoRaw = data[kFieldEquipamentoSolicitacao]?.toString() ?? 'N/I'; 
              final String equipamentoShort = equipamentoRaw.length > 20 ? '${equipamentoRaw.substring(0, 17)}...' : equipamentoRaw; 
              final String patrimonioPdf = data[kFieldPatrimonio]?.toString() ?? 'N/I';
              final String statusPdfValue = data[kFieldStatus]?.toString() ?? 'N/I'; 
              return <String>[ dtAbertura, tipo, solicitante, localSetorShort, problemaShort, equipamentoShort, patrimonioPdf, statusPdfValue, ]; 
            }).toList(), 
            columnWidths: { 0: const pw.FixedColumnWidth(50), 1: const pw.FixedColumnWidth(60), 2: const pw.FlexColumnWidth(2.5), 3: const pw.FlexColumnWidth(3.5), 4: const pw.FlexColumnWidth(3.0), 5: const pw.FlexColumnWidth(2.0), 6: const pw.FixedColumnWidth(70), 7: const pw.FixedColumnWidth(70), } 
          ), 
        ], 
      ), 
    ); 
  }
  return pdf.save();
}