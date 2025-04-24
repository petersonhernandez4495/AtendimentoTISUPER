// lib/pdf_generator.dart
import 'dart:typed_data';
import 'dart:io'; // Para File
import 'package:flutter/material.dart'; // Para BuildContext
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Usar prefixo 'pw'
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import 'package:path_provider/path_provider.dart'; // Para pasta temporária
import 'package:share_plus/share_plus.dart';       // Para compartilhar

// --- Função que GERA os bytes do PDF de UM Chamado (SEU CÓDIGO - PARECE OK) ---
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
  final Timestamp? tsCriacao = ticketData['data_criacao'] as Timestamp?;
  final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
  final Timestamp? tsUpdate = ticketData['data_atualizacao'] as Timestamp?;
  final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(30),
      build: (pw.Context context) {
        return pw.Column( crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Header( level: 0, child: pw.Text('Detalhes do Chamado - Atendimento TI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),),
            pw.Divider(thickness: 1, height: 20),
            _buildPdfRow('Título:', titulo), _buildPdfRow('Descrição:', descricao, isMultiline: true), pw.Divider(height: 15),
            _buildPdfRow('Status:', status), _buildPdfRow('Prioridade:', prioridade), _buildPdfRow('Categoria:', categoria),
            _buildPdfRow('Departamento:', departamento), _buildPdfRow('Equipamento/Sistema:', equipamento), pw.Divider(height: 15),
            _buildPdfRow('Criado por:', criadorNome), _buildPdfRow('Telefone Criador:', criadorPhone), pw.Divider(height: 15),
            _buildPdfRow('Criado em:', dtCriacao), _buildPdfRow('Última Atualização:', dtUpdate),
            pw.Spacer(), pw.Divider(),
            pw.Align( alignment: pw.Alignment.centerRight, child: pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey)),)
          ],
        );
      },
    ),
  );
  return pdf.save();
}

// --- Helper para criar linhas Label: Valor no PDF (SEU CÓDIGO - PARECE OK) ---
pw.Widget _buildPdfRow(String label, String value, {bool isMultiline = false}) {
  return pw.Padding( padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Row( crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox( width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),),
      pw.SizedBox(width: 10), pw.Expanded( child: pw.Text(value),),
    ],
  ),);
}

// --- Função para GERAR E COMPARTILHAR o PDF de UM Chamado ---
enum PdfShareResult { success, dismissed, error }

Future<PdfShareResult> generateAndSharePdfForTicket({
  required BuildContext context,
  required String chamadoId,
  required Map<String, dynamic> dadosChamado,
}) async {
  showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    // --- CORREÇÃO DA CHAMADA AQUI ---
    final Uint8List pdfBytes = await generateTicketPdf(dadosChamado); // <<< CORRIGIDO para generateTicketPdf
    // -----------------------------
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/chamado_${chamadoId}_share.pdf'; // Nome diferente para share
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {} // Fecha loading

    final result = await Share.shareXFiles( [XFile(filePath)], text: 'Detalhes do Chamado: ${dadosChamado['titulo'] ?? chamadoId}');

    if (result.status == ShareResultStatus.success) return PdfShareResult.success;
    if (result.status == ShareResultStatus.dismissed) return PdfShareResult.dismissed;
    return PdfShareResult.success;

  } catch (e) {
    print("Erro ao gerar/compartilhar PDF: $e");
    try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
    return PdfShareResult.error;
  }
}

// --- Função para gerar PDF da LISTA ---
// <<< CÓDIGO COMPLETO ADICIONADO/DESCOMENTADO >>>
Future<Uint8List> generateTicketListPdf(List<QueryDocumentSnapshot> tickets) async {
  final pdf = pw.Document();
  final DateFormat dateFormatter = DateFormat('dd/MM/yy', 'pt_BR');

  const int ticketsPerPage = 20; // Ajuste conforme necessário
  List<List<QueryDocumentSnapshot>> pages = [];
  for (var i = 0; i < tickets.length; i += ticketsPerPage) {
    pages.add( tickets.sublist(i, i + ticketsPerPage > tickets.length ? tickets.length : i + ticketsPerPage) );
  }

  for (var pageTickets in pages) {
     pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Paisagem para caber mais colunas
        header: (pw.Context context) => pw.Container( alignment: pw.Alignment.centerLeft, margin: const pw.EdgeInsets.only(bottom: 10.0), child: pw.Text('Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)), ),
        footer: (pw.Context context) => pw.Container( alignment: pw.Alignment.centerRight, margin: const pw.EdgeInsets.only(top: 10.0), child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)), ),
        build: (pw.Context context) => [
              pw.Header( level: 0, text: 'Relatório de Chamados', padding: const pw.EdgeInsets.only(bottom: 20), textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18) ),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                cellAlignment: pw.Alignment.centerLeft, headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headerHeight: 25, cellHeight: 30, cellPadding: const pw.EdgeInsets.all(4),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: <String>[ 'Data', 'Título', 'Status', 'Prioridade', 'Criador', 'Depto.', 'Equip.' ], // Ajuste cabeçalhos
                data: pageTickets.map((ticketDoc) {
                   final data = ticketDoc.data() as Map<String, dynamic>;
                   final Timestamp? tsCriacao = data['data_criacao'] as Timestamp?;
                   final String dtCriacao = tsCriacao != null ? dateFormatter.format(tsCriacao.toDate()) : 'N/I';
                   return <String>[
                     dtCriacao, data['titulo'] ?? 'N/I', data['status'] ?? 'N/I', data['prioridade'] ?? 'N/I',
                     data['creatorName'] ?? 'N/I', data['departamento'] ?? 'N/I', data['equipamento'] ?? 'N/I',
                   ];
                 }).toList(),
                 columnWidths: { // Ajuste larguras
                   0: const pw.FixedColumnWidth(50), 1: const pw.FlexColumnWidth(3), 2: const pw.FixedColumnWidth(60),
                   3: const pw.FixedColumnWidth(50), 4: const pw.FlexColumnWidth(2), 5: const pw.FlexColumnWidth(2),
                   6: const pw.FlexColumnWidth(2),
                 }
              ),
           ],
      ),
    );
  }
  return pdf.save();
}
// ---------------------------------------