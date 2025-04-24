// Exemplo (pode ser em lib/utils/pdf_generator.dart ou dentro do State)
import 'dart:typed_data';
import 'package:pdf/pdf.dart';               
import 'package:pdf/widgets.dart' as pw;      
import 'package:intl/intl.dart';            
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'pdf_generator.dart';
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart';
// Função que recebe os dados do chamado e retorna os bytes do PDF
Future<Uint8List> generateTicketPdf(Map<String, dynamic> ticketData) async {
  final pdf = pw.Document();

  // Dados (com valores padrão para segurança)
  final String titulo = ticketData['titulo'] ?? 'N/I';
  final String descricao = ticketData['descricao'] ?? 'N/I';
  final String status = ticketData['status'] ?? 'N/I';
  final String prioridade = ticketData['prioridade'] ?? 'N/I';
  final String categoria = ticketData['categoria'] ?? 'N/I';
  final String departamento = ticketData['departamento'] ?? 'N/I';
  final String equipamento = ticketData['equipamento'] ?? 'N/I';
  final String criadorNome = ticketData['creatorName'] ?? 'N/I';
  final String criadorPhone = ticketData['creatorPhone'] ?? 'N/I'; // Se salvou no chamado
  // Ou buscar de 'users' se necessário, mas complica a função

  final Timestamp? tsCriacao = ticketData['data_criacao'] as Timestamp?;
  final String dtCriacao = tsCriacao != null
      ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsCriacao.toDate())
      : 'N/I';
  final Timestamp? tsUpdate = ticketData['data_atualizacao'] as Timestamp?;
   final String dtUpdate = tsUpdate != null
      ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(tsUpdate.toDate())
      : '--';

  // Adiciona uma página ao PDF
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4, // Formato da página
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(30), // Margens da página
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              pw.Header(
                level: 0,
                child: pw.Text('Detalhes do Chamado - Atendimento TI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              ),
              pw.Divider(thickness: 1, height: 20),

              // Conteúdo (usando helper para layout)
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
               _buildPdfRow('Telefone Criador:', criadorPhone), // Exibe o telefone
               pw.Divider(height: 15),
              _buildPdfRow('Criado em:', dtCriacao),
              _buildPdfRow('Última Atualização:', dtUpdate),

              // Adicione mais campos se necessário

              // Rodapé (Exemplo)
              pw.Spacer(),
              pw.Divider(),
              pw.Text('Documento gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}'),
            ],
          ),
        );
      },
    ),
  ); // Fim da page

  // Salva o PDF em memória e retorna os bytes
  return pdf.save();
}

// Helper para criar linhas Label: Valor no PDF
pw.Widget _buildPdfRow(String label, String value, {bool isMultiline = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110, // Largura fixa para o label
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(value), // O valor ocupa o resto
        ),
      ],
    ),
  );
}