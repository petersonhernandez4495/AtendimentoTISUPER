// lib/pdf_generator.dart
import 'dart:typed_data';
import 'dart:io'; // Para File
import 'package:flutter/material.dart'; // Para BuildContext e Widgets do Material (Dialog, ScaffoldMessenger)
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Usar prefixo 'pw'
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import 'package:path_provider/path_provider.dart'; // Para pasta temporária
import 'package:share_plus/share_plus.dart';       // Para compartilhar

// --- Função que GERA os bytes do PDF de UM Chamado ---
Future<Uint8List> generateTicketPdf(Map<String, dynamic> ticketData) async {
  final pdf = pw.Document();

  // Extração de dados com segurança
  final String titulo = ticketData['titulo']?.toString() ?? 'N/I';
  final String descricao = ticketData['descricao']?.toString() ?? 'N/I';
  final String status = ticketData['status']?.toString() ?? 'N/I';
  final String prioridade = ticketData['prioridade']?.toString() ?? 'N/I';
  final String categoria = ticketData['categoria']?.toString() ?? 'N/I';
  final String departamento = ticketData['departamento']?.toString() ?? 'N/I';
  final String equipamento = ticketData['equipamento']?.toString() ?? 'N/I';
  final String criadorNome = ticketData['creatorName']?.toString() ?? 'N/I';
  final String criadorPhone = ticketData['creatorPhone']?.toString() ?? 'N/I';

  // Tratamento seguro de Timestamps
  final Timestamp? tsCriacao = ticketData['data_criacao'] as Timestamp?;
  final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
  final Timestamp? tsUpdate = ticketData['data_atualizacao'] as Timestamp?;
  final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30), // Margem ajustada
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text('Detalhes do Chamado - Atendimento TI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            ),
            pw.Divider(thickness: 1, height: 20),
            _buildPdfRow('Título:', titulo),
            _buildPdfRow('Descrição:', descricao, isMultiline: true),
            pw.Divider(height: 15),
            _buildPdfRow('Status:', status),
            _buildPdfRow('Prioridade:', prioridade),
            _buildPdfRow('Categoria:', categoria),
            _buildPdfRow('Departamento:', departamento),
            _buildPdfRow('Equipamento/Sistema:', equipamento),
            pw.Divider(height: 15),
            _buildPdfRow('Criado por:', criadorNome),
            _buildPdfRow('Telefone Criador:', criadorPhone),
            pw.Divider(height: 15),
            _buildPdfRow('Criado em:', dtCriacao),
            _buildPdfRow('Última Atualização:', dtUpdate),
            pw.Spacer(),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey)),
            )
          ],
        );
      },
    ),
  );
  return pdf.save(); // Retorna os bytes
}

// --- Helper para criar linhas Label: Valor no PDF ---
pw.Widget _buildPdfRow(String label, String value, {bool isMultiline = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3), // Diminui padding vertical
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120, // Aumentei um pouco a largura do rótulo
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(value),
        ),
      ],
    ),
  );
}

// --- Função para GERAR E COMPARTILHAR o PDF de UM Chamado ---
enum PdfShareResult { success, dismissed, error }

Future<PdfShareResult> generateAndSharePdfForTicket({
  required BuildContext context,
  required String chamadoId,
  required Map<String, dynamic> dadosChamado,
}) async {
  // Mostra loading
  showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

  try {
    final Uint8List pdfBytes = await generateTicketPdf(dadosChamado); // Chama a função acima
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/chamado_${chamadoId}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    // Tenta fechar o loading ANTES de compartilhar
    try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}

    final result = await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Detalhes do Chamado: ${dadosChamado['titulo'] ?? chamadoId}'
    );

    // Retorna o status
    if (result.status == ShareResultStatus.success) return PdfShareResult.success;
    if (result.status == ShareResultStatus.dismissed) return PdfShareResult.dismissed;
    return PdfShareResult.success; // Considera outros como sucesso parcial

  } catch (e) {
    print("Erro ao gerar/compartilhar PDF: $e");
    // Tenta fechar o loading em caso de erro
     try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
    return PdfShareResult.error; // Retorna erro
  }
}

// --- Função para gerar PDF da LISTA (se implementada) ---
// Future<Uint8List> generateTicketListPdf(...) async { ... }