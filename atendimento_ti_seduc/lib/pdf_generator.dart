import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para o tipo Timestamp

// Constantes usadas neste arquivo (garanta que correspondam às do seu projeto)
const String kFieldStatus = 'status';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldEquipamentoSolicitacao = 'equipamento_solicitacao';
const String kFieldProblemaOcorre = 'problema_ocorre';
const String kFieldSolucao = 'solucao';
const String kFieldDataAtendimento = 'data_atendimento';
const String kStatusPadraoSolicionado = 'Solucionado';
const String kFieldSolucaoPorNome = 'solucaoPorNome';
const String kFieldDataDaSolucao = 'dataDaSolucao';
const String kFieldDataCriacao = 'data_criacao';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador'; // Adicionada para consistência


class PdfGenerator {
  static Future<Uint8List?> _fetchImageFromUrl(String? url) async {
    if (url == null || url.isEmpty) {
      return null;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      print('PDFGenerator: Falha ao baixar imagem de $url. Status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('PDFGenerator: Erro ao baixar imagem de $url: $e');
      return null;
    }
  }

  static Future<Uint8List> generateTicketPdfBytes({
    required String chamadoId,
    required Map<String, dynamic> dadosChamado,
    String? adminSignatureUrl,
    String? requesterSignatureUrl,
  }) async {
    final pdf = pw.Document();
    final DateFormat dateFormatTimestamp = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final DateFormat dateFormatDateOnly = DateFormat('dd/MM/yyyy', 'pt_BR');

    pw.MemoryImage? adminSignatureImage;
    if (adminSignatureUrl != null && adminSignatureUrl.isNotEmpty) {
      Uint8List? adminSigBytes = await _fetchImageFromUrl(adminSignatureUrl);
      if (adminSigBytes != null) {
        try {
          adminSignatureImage = pw.MemoryImage(adminSigBytes);
        } catch (e) {
          print('PDFGenerator: Erro ao criar MemoryImage para assinatura do admin: $e');
          adminSignatureImage = null;
        }
      }
    }

    pw.MemoryImage? requesterSignatureImage;
    if (requesterSignatureUrl != null && requesterSignatureUrl.isNotEmpty) {
      Uint8List? requesterSigBytes = await _fetchImageFromUrl(requesterSignatureUrl);
      if (requesterSigBytes != null) {
         try {
          requesterSignatureImage = pw.MemoryImage(requesterSigBytes);
        } catch (e) {
          print('PDFGenerator: Erro ao criar MemoryImage para assinatura do requerente: $e');
          requesterSignatureImage = null;
        }
      }
    }
    
    final String statusChamado = dadosChamado[kFieldStatus] as String? ?? 'N/I';
    final String nomeSolicitante = dadosChamado[kFieldNomeSolicitante] as String? ?? 'N/I';
    final Timestamp? tsDataCriacao = dadosChamado[kFieldDataCriacao] as Timestamp?;
    final String dataCriacaoStr = tsDataCriacao != null
        ? dateFormatTimestamp.format(tsDataCriacao.toDate())
        : '--';
    final String equipamento = dadosChamado[kFieldEquipamentoSolicitacao] as String? ?? 'N/I';
    final String problema = dadosChamado[kFieldProblemaOcorre] as String? ?? 'N/I';
    
    final String? solucaoDescricao = dadosChamado[kFieldSolucao] as String?;
    final Timestamp? tsDataAtendimentoInformada = dadosChamado[kFieldDataAtendimento] as Timestamp?;
    final String dataAtendimentoInformadaStr = tsDataAtendimentoInformada != null
        ? dateFormatDateOnly.format(tsDataAtendimentoInformada.toDate())
        : '--';

    final String? adminSolucionouNome = dadosChamado[kFieldSolucaoPorNome] as String?;
    final Timestamp? tsDataRealSolucao = dadosChamado[kFieldDataDaSolucao] as Timestamp?;
    final String dataRealSolucaoStr = tsDataRealSolucao != null
        ? dateFormatTimestamp.format(tsDataRealSolucao.toDate())
        : '--';

    final bool requerenteConfirmou = dadosChamado[kFieldRequerenteConfirmou] as bool? ?? false;
    final Timestamp? tsRequerenteConfirmouData = dadosChamado[kFieldRequerenteConfirmouData] as Timestamp?;
    final String requerenteConfirmouDataStr = tsRequerenteConfirmouData != null
        ? dateFormatTimestamp.format(tsRequerenteConfirmouData.toDate())
        : '--';
    
    final String nomeRequerenteQueConfirmou = dadosChamado[kFieldNomeRequerenteConfirmador] as String? ?? 
                                            (requerenteConfirmou ? nomeSolicitante : 'N/A');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
            padding: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey700)),
            ),
            child: pw.Text(
              'Chamado ID: ${chamadoId.substring(0, min(6, chamadoId.length))}',
              style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey),
            ),
          );
        },
        build: (pw.Context pdfContext) {
          List<pw.Widget> widgets = [];

          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Relatório do Chamado', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('ID: ${chamadoId.substring(0, min(6, chamadoId.length))}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
              ]
            )
          );
          widgets.add(pw.Divider(thickness: 1, height: 20));
          widgets.add(pw.SizedBox(height: 10));

          widgets.add(_buildPdfInfoRow('Status:', statusChamado));
          widgets.add(_buildPdfInfoRow('Solicitante:', nomeSolicitante));
          widgets.add(_buildPdfInfoRow('Data de Criação:', dataCriacaoStr));
          widgets.add(_buildPdfInfoRow('Equipamento:', equipamento));
          widgets.add(_buildPdfInfoRow('Problema Relatado:', problema, isParagraph: true));
          
          widgets.add(pw.SizedBox(height: 15));

          if (statusChamado.toLowerCase() == kStatusPadraoSolicionado.toLowerCase()) {
            widgets.add(pw.Header(level: 1, text: 'Detalhes da Solução', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)));
            widgets.add(pw.SizedBox(height: 5));

            if (solucaoDescricao != null && solucaoDescricao.isNotEmpty) {
              widgets.add(_buildPdfInfoRow('Descrição da Solução:', solucaoDescricao, isParagraph: true));
            }
            widgets.add(_buildPdfInfoRow('Data de Atendimento (Informada):', dataAtendimentoInformadaStr));
            
            if (adminSolucionouNome != null && adminSolucionouNome.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(_buildPdfInfoRow('Solucionado por (Admin/Técnico):', adminSolucionouNome, valueStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
              widgets.add(_buildPdfInfoRow('Data do Registro da Solução:', dataRealSolucaoStr));
              if (adminSignatureImage != null) {
                widgets.add(pw.SizedBox(height: 10));
                widgets.add(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Assinatura do Técnico/Admin:", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(
                        width: 150,
                        height: 60,
                        child: pw.Image(adminSignatureImage, fit: pw.BoxFit.contain),
                      ),
                      pw.Container(width: 150, child: pw.Divider(thickness: 0.5)),
                      pw.Text(adminSolucionouNome, style: pw.TextStyle(fontSize: 10)),
                    ]
                  )
                );
              } else if (adminSignatureUrl != null && adminSignatureUrl.isNotEmpty) {
                 widgets.add(pw.Text('[Falha ao carregar assinatura do técnico/admin]', style: pw.TextStyle(color: PdfColors.red, fontStyle: pw.FontStyle.italic, fontSize: 9)));
              }
            }
            widgets.add(pw.SizedBox(height: 20));
          }
          
          if (requerenteConfirmou) {
            widgets.add(pw.Header(level: 1, text: 'Confirmação do Requerente', textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)));
            widgets.add(pw.SizedBox(height: 5));
            widgets.add(_buildPdfInfoRow('Status Confirmação:', 'Solução Aceita pelo Requerente'));
            widgets.add(_buildPdfInfoRow('Confirmado por:', nomeRequerenteQueConfirmou));
            widgets.add(_buildPdfInfoRow('Data da Confirmação:', requerenteConfirmouDataStr));
            if (requesterSignatureImage != null) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Assinatura do Requerente:", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(
                        width: 150, 
                        height: 60, 
                        child: pw.Image(requesterSignatureImage, fit: pw.BoxFit.contain),
                      ),
                      pw.Container(width: 150, child: pw.Divider(thickness: 0.5)),
                      pw.Text(nomeRequerenteQueConfirmou, style: pw.TextStyle(fontSize: 10)),
                    ]
                  )
                );
            } else if (requesterSignatureUrl != null && requesterSignatureUrl.isNotEmpty) {
                widgets.add(pw.Text('[Falha ao carregar assinatura do requerente]', style: pw.TextStyle(color: PdfColors.red, fontStyle: pw.FontStyle.italic, fontSize: 9)));
            }
          }
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildPdfInfoRow(String label, String value, {bool isParagraph = false, pw.TextStyle? valueStyle}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: isParagraph ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: isParagraph
                ? pw.Text(value, style: valueStyle ?? const pw.TextStyle())
                : pw.Text(value, style: valueStyle ?? const pw.TextStyle()),
          ),
        ],
      ),
    );
  }
}