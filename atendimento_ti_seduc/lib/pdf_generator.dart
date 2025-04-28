// lib/pdf_generator.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart'; // Para BuildContext
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// --- Função que GERA os bytes do PDF de UM Chamado (ATUALIZADA) ---
Future<Uint8List> generateTicketPdf(Map<String, dynamic> ticketData) async {
  final pdf = pw.Document();

  // --- Extração de Dados da NOVA Estrutura ---
  final String tipoSolicitante = ticketData['tipo_solicitante']?.toString() ?? 'N/I';
  final String nomeSolicitante = ticketData['nome_solicitante']?.toString() ?? 'N/I';
  final String celularContato = ticketData['celular_contato']?.toString() ?? 'N/I';
  final String equipamentoSolicitacao = ticketData['equipamento_solicitacao']?.toString() ?? 'N/I';
  final String conectadoInternet = ticketData['equipamento_conectado_internet']?.toString() ?? 'N/I';
  final String marcaModelo = ticketData['marca_modelo_equipamento']?.toString() ?? ''; // Opcional
  final String patrimonio = ticketData['numero_patrimonio']?.toString() ?? 'N/I';
  final String problemaOcorre = ticketData['problema_ocorre']?.toString() ?? 'N/I';
  final String? escola = ticketData['escola'] as String?;
  final String? cargoFuncao = ticketData['cargo_funcao'] as String?;
  final String? atendimentoPara = ticketData['atendimento_para'] as String?;
  final String? setorSuper = ticketData['setor_superintendencia'] as String?;
  final String status = ticketData['status']?.toString() ?? 'N/I';
  // --- Verifique se prioridade existe ---
  final String prioridade = ticketData['prioridade']?.toString() ?? 'N/I'; // Mantenha se existir
  // -----------------------------------
  final String? tecnicoResponsavel = ticketData['tecnico_responsavel'] as String?;
  final String? authUserDisplay = ticketData['authUserDisplayName'] as String?;
  final Timestamp? tsCriacao = ticketData['data_criacao'] as Timestamp?;
  final String dtCriacao = tsCriacao != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate()) : 'N/I';
  final Timestamp? tsUpdate = ticketData['data_atualizacao'] as Timestamp?;
  final String dtUpdate = tsUpdate != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate()) : '--';
  // ---------------------------------------------

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Detalhes do Chamado - Atendimento TI',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
              ),
            ),
            pw.Divider(thickness: 1, height: 20),
            _buildPdfRow('Solicitante:', nomeSolicitante),
            _buildPdfRow('Contato:', celularContato),
            _buildPdfRow('Tipo:', tipoSolicitante),
            if (tipoSolicitante == 'Escola') ...[
              if (escola != null) _buildPdfRow('Escola:', escola),
              if (cargoFuncao != null) _buildPdfRow('Cargo/Função:', cargoFuncao),
              if (atendimentoPara != null) _buildPdfRow('Atendimento Para:', atendimentoPara),
            ],
            if (tipoSolicitante == 'Superintendência') ...[
              if (setorSuper != null) _buildPdfRow('Setor SUPER:', setorSuper),
            ],
            pw.Divider(height: 15),
            _buildPdfRow('Problema Relatado:', problemaOcorre, isMultiline: true),
            _buildPdfRow('Equipamento:', equipamentoSolicitacao),
            if (marcaModelo.isNotEmpty) _buildPdfRow('Marca/Modelo:', marcaModelo),
            _buildPdfRow('Patrimônio:', patrimonio),
            _buildPdfRow('Conectado à Internet:', conectadoInternet),
            pw.Divider(height: 15),
            _buildPdfRow('Status:', status),
            // -- Exibir Prioridade apenas se ainda for usada --
            _buildPdfRow('Prioridade:', prioridade), // << REMOVA SE NÃO EXISTIR MAIS
            // -------------------------------------------------
            if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty)
              _buildPdfRow('Técnico Responsável:', tecnicoResponsavel),
            pw.Divider(height: 15),
            _buildPdfRow('Criado em:', dtCriacao),
            _buildPdfRow('Última Atualização:', dtUpdate),
             if (authUserDisplay != null && authUserDisplay.isNotEmpty)
              _buildPdfRow('Registrado por:', authUserDisplay),
            pw.Spacer(),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}',
                style: const pw.TextStyle(color: PdfColors.grey),
              ),
            )
          ],
        );
      },
    ),
  );
  return pdf.save();
}

// --- Helper para criar linhas Label: Valor no PDF (Mantido) ---
pw.Widget _buildPdfRow(String label, String value, {bool isMultiline = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(value.isEmpty ? '-' : value),
        ),
      ],
    ),
  );
}

// --- Função para GERAR E COMPARTILHAR o PDF de UM Chamado (Mantida) ---
enum PdfShareResult { success, dismissed, error }

Future<PdfShareResult> generateAndSharePdfForTicket({
  required BuildContext context,
  required String chamadoId,
  required Map<String, dynamic> dadosChamado,
}) async {
  showDialog( context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final Uint8List pdfBytes = await generateTicketPdf(dadosChamado); // Chama a função atualizada
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/chamado_${chamadoId}_share.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}

    final shareTitle = dadosChamado['problema_ocorre']?.toString() ?? dadosChamado['equipamento_solicitacao']?.toString() ?? chamadoId;
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Detalhes do Chamado: $shareTitle'
    );

    if (result.status == ShareResultStatus.success) return PdfShareResult.success;
    if (result.status == ShareResultStatus.dismissed) return PdfShareResult.dismissed;
    return PdfShareResult.success;

  } catch (e) {
    print("Erro ao gerar/compartilhar PDF: $e");
    try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
    return PdfShareResult.error;
  }
}

// --- Função para gerar PDF da LISTA (ATUALIZADA) ---
Future<Uint8List> generateTicketListPdf(List<QueryDocumentSnapshot> tickets) async {
  final pdf = pw.Document();
  final DateFormat dateFormatter = DateFormat('dd/MM/yy', 'pt_BR');

  const int ticketsPerPage = 18;
  List<List<QueryDocumentSnapshot>> pages = [];
  for (var i = 0; i < tickets.length; i += ticketsPerPage) {
    pages.add( tickets.sublist(i, i + ticketsPerPage > tickets.length ? tickets.length : i + ticketsPerPage) );
  }

  final List<String> headers = <String>[
     'Data', 'Tipo', 'Solicitante', 'Local/Setor', 'Problema', 'Equip.', 'Patrimônio', 'Status'
     // ,'Prioridade' // << DESCOMENTE SE PRIORIDADE FOR USADA
  ];

  for (var pageTickets in pages) {
     pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
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
            headers: headers,
            data: pageTickets.map((ticketDoc) {
               final data = ticketDoc.data() as Map<String, dynamic>;
               final Timestamp? tsCriacao = data['data_criacao'] as Timestamp?;
               final String dtCriacao = tsCriacao != null ? dateFormatter.format(tsCriacao.toDate()) : 'N/I';
               final String tipo = data['tipo_solicitante'] ?? 'N/I';
               final String solicitante = data['nome_solicitante'] ?? 'N/I';
               final String localRaw = tipo == 'Escola'
                   ? (data['escola']?.toString() ?? 'N/I')
                   : (data['setor_superintendencia']?.toString() ?? 'N/I');
                final String local = localRaw.length > 40 ? '${localRaw.substring(0, 37)}...' : localRaw;
               final String problema = data['problema_ocorre'] ?? 'N/I';
               final String equipamento = data['equipamento_solicitacao'] ?? 'N/I';
               final String patrimonio = data['numero_patrimonio'] ?? 'N/I';
               final String status = data['status'] ?? 'N/I';
               // final String prioridade = data['prioridade'] ?? 'N/I'; // << DESCOMENTE SE PRIORIDADE FOR USADA

               return <String>[
                 dtCriacao, tipo, solicitante, local,
                 problema, equipamento, patrimonio, status,
                 // prioridade, // << DESCOMENTE SE PRIORIDADE FOR USADA
               ];
            }).toList(),
            columnWidths: {
               0: const pw.FixedColumnWidth(50),  // Data
               1: const pw.FixedColumnWidth(80),  // Tipo
               2: const pw.FlexColumnWidth(2.5), // Solicitante
               3: const pw.FlexColumnWidth(3.5), // Local/Setor
               4: const pw.FlexColumnWidth(3),   // Problema
               5: const pw.FlexColumnWidth(2),   // Equipamento
               6: const pw.FixedColumnWidth(70),  // Patrimonio
               7: const pw.FixedColumnWidth(60),  // Status
               // 8: const pw.FixedColumnWidth(50), // Prioridade (se usada)
            }
           ),
         ],
      ),
    );
  }
  return pdf.save();
}
// ---------------------------------------