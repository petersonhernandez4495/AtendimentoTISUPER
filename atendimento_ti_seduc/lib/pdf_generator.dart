// lib/pdf_generator.dart

import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- INÍCIO: CONSTANTES DE CAMPO ---
// (IMPORTANTE: Garanta que estas constantes sejam IDÊNTICAS às usadas
// no seu chamado_service.dart e no restante do app. Idealmente, importe-as.)

// Já existentes:
const String kFieldStatus = 'status';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldEquipamentoSolicitacao = 'equipamento_solicitacao';
const String kFieldProblemaOcorre = 'problema_ocorre';
const String kFieldSolucao = 'solucao';
const String kFieldDataAtendimento = 'data_atendimento'; // Data informada pelo Admin/Tec
const String kStatusPadraoSolicionado = 'Solucionado';
const String kFieldSolucaoPorNome = 'solucaoPorNome'; // Nome de quem registrou a solução
const String kFieldDataDaSolucao = 'dataDaSolucao'; // Timestamp de quando a solução foi registrada
const String kFieldDataCriacao = 'data_criacao';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador';

// Novas/Confirmadas (baseado em _ChamadoInfoBody):
const String kFieldCelularContato = 'celular_contato';
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldCidade = 'cidade'; // Usado para Escola
const String kFieldInstituicao = 'instituicao'; // Usado para Escola
const String kFieldInstituicaoManual = 'instituicao_manual'; // Usado se cidade = OUTRO
const String kFieldCargoFuncao = 'cargo_funcao'; // Usado para Escola
const String kFieldAtendimentoPara = 'atendimento_para'; // Usado para Escola
const String kFieldSetorSuper = 'setor_super'; // Usado para SUPER
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia'; // Usado para SUPER
const String kFieldMarcaModelo = 'marca_modelo';
const String kFieldPatrimonio = 'patrimonio';
const String kFieldConectadoInternet = 'conectado_internet';
const String kFieldEquipamentoOutro = 'equipamento_outro'; // Descrição se equipamento = OUTRO
const String kFieldProblemaOutro = 'problema_outro'; // Descrição se problema = OUTRO
const String kFieldTecnicoResponsavel = 'tecnico_responsavel';
const String kFieldAuthUserDisplay = 'authUserDisplay'; // Nome do usuário que criou o chamado
const String kFieldAdminFinalizouData = 'adminFinalizouData'; // Timestamp de arquivamento
const String kFieldAdminFinalizouNome = 'adminFinalizouNome'; // Nome de quem arquivou
const String kStatusFinalizado = 'Finalizado'; // Status para identificar arquivados

// --- FIM: CONSTANTES DE CAMPO ---


class PdfGenerator {
  static Future<Uint8List?> _fetchImageFromUrl(String? url) async {
    // ... (código existente, sem alterações)
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

  // Função auxiliar para formatar Timestamps de forma segura
  static String _formatTimestamp(Timestamp? ts, String format, {String defaultValue = '--'}) {
     if (ts == null) return defaultValue;
     try {
        return DateFormat(format, 'pt_BR').format(ts.toDate());
     } catch (e) {
        print("PDFGenerator: Erro ao formatar Timestamp: $e");
        return defaultValue;
     }
  }


  static Future<Uint8List> generateTicketPdfBytes({
    required String chamadoId,
    required Map<String, dynamic> dadosChamado,
    String? adminSignatureUrl, // Assinatura de quem solucionou
    String? requesterSignatureUrl, // Assinatura de quem confirmou
    String? nomeRequerenteConfirmou,
  }) async {
    final pdf = pw.Document();
    final DateFormat dateFormatTimestamp = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final DateFormat dateFormatDateOnly = DateFormat('dd/MM/yyyy', 'pt_BR');

    // --- Busca Imagens das Assinaturas ---
    pw.MemoryImage? adminSignatureImage;
    if (adminSignatureUrl != null && adminSignatureUrl.isNotEmpty) {
      Uint8List? adminSigBytes = await _fetchImageFromUrl(adminSignatureUrl);
      if (adminSigBytes != null) {
        try { adminSignatureImage = pw.MemoryImage(adminSigBytes); } catch (e) { print('PDFGenerator: Erro MemoryImage admin: $e'); }
      }
    }

    pw.MemoryImage? requesterSignatureImage;
    if (requesterSignatureUrl != null && requesterSignatureUrl.isNotEmpty) {
      Uint8List? requesterSigBytes = await _fetchImageFromUrl(requesterSignatureUrl);
      if (requesterSigBytes != null) {
         try { requesterSignatureImage = pw.MemoryImage(requesterSigBytes); } catch (e) { print('PDFGenerator: Erro MemoryImage requerente: $e'); }
      }
    }

    // --- Extração de TODOS os Campos (com tratamento para nulos/vazios) ---

    // Dados Gerais
    final String statusChamado = dadosChamado[kFieldStatus] as String? ?? 'N/I';
    final Timestamp? tsDataCriacao = dadosChamado[kFieldDataCriacao] as Timestamp?;
    final String dataCriacaoStr = _formatTimestamp(tsDataCriacao, 'dd/MM/yyyy HH:mm');
    final String? authUserDisplay = dadosChamado[kFieldAuthUserDisplay] as String?; // Registrado por

    // Dados do Solicitante
    final String nomeSolicitante = dadosChamado[kFieldNomeSolicitante] as String? ?? 'N/I';
    final String? celularContato = dadosChamado[kFieldCelularContato] as String?;
    final String? tipoSolicitante = dadosChamado[kFieldTipoSolicitante] as String?;
    final String? cidadeEscola = dadosChamado[kFieldCidade] as String?;
    final String? instituicaoEscola = dadosChamado[kFieldInstituicao] as String?;
    final String? instituicaoManualEscola = dadosChamado[kFieldInstituicaoManual] as String?;
    final String? cargoFuncao = dadosChamado[kFieldCargoFuncao] as String?;
    final String? atendimentoPara = dadosChamado[kFieldAtendimentoPara] as String?;
    final String? setorSuper = dadosChamado[kFieldSetorSuper] as String?;
    final String? cidadeSuper = dadosChamado[kFieldCidadeSuperintendencia] as String?;

    // Lógica para exibir local/instituição
    String displayInstituicao = 'N/I';
    String displayCidade = '';
    if (tipoSolicitante == 'ESCOLA') {
      displayCidade = cidadeEscola ?? '';
      if (cidadeEscola == "OUTRO" && instituicaoManualEscola != null && instituicaoManualEscola.isNotEmpty) {
        displayInstituicao = instituicaoManualEscola;
      } else if (instituicaoEscola != null && instituicaoEscola.isNotEmpty) {
        displayInstituicao = instituicaoEscola;
      }
    } else if (tipoSolicitante == 'SUPERINTENDENCIA') {
      displayInstituicao = setorSuper ?? 'N/I';
      displayCidade = cidadeSuper ?? '';
    }

    // Detalhes do Problema/Equipamento
    final String problemaOcorre = dadosChamado[kFieldProblemaOcorre] as String? ?? 'N/I';
    final String? problemaOutroDesc = dadosChamado[kFieldProblemaOutro] as String?;
    final String equipamentoSolicitacao = dadosChamado[kFieldEquipamentoSolicitacao] as String? ?? 'N/I';
    final String? equipamentoOutroDesc = dadosChamado[kFieldEquipamentoOutro] as String?;
    final String? marcaModelo = dadosChamado[kFieldMarcaModelo] as String?;
    final String? patrimonio = dadosChamado[kFieldPatrimonio] as String?;
    final String? conectadoInternet = dadosChamado[kFieldConectadoInternet] as String?;
    final String? tecnicoResponsavel = dadosChamado[kFieldTecnicoResponsavel] as String?;

    // Lógica para exibir problema/equipamento
    String displayProblema = problemaOcorre;
    if (problemaOcorre.toUpperCase() == "OUTRO" && problemaOutroDesc != null && problemaOutroDesc.isNotEmpty) {
      displayProblema = "$problemaOcorre: $problemaOutroDesc";
    }
     String displayEquipamento = equipamentoSolicitacao;
    if (equipamentoSolicitacao.toUpperCase() == "OUTRO" && equipamentoOutroDesc != null && equipamentoOutroDesc.isNotEmpty) {
      displayEquipamento = "$equipamentoSolicitacao: $equipamentoOutroDesc";
    }

    // Dados da Solução
    final String? solucaoDescricao = dadosChamado[kFieldSolucao] as String?;
    final Timestamp? tsDataAtendimentoInformada = dadosChamado[kFieldDataAtendimento] as Timestamp?; // Data informada no form de solução
    final String dataAtendimentoInformadaStr = _formatTimestamp(tsDataAtendimentoInformada, 'dd/MM/yyyy');
    final String? adminSolucionouNome = dadosChamado[kFieldSolucaoPorNome] as String?; // Nome de quem registrou
    final Timestamp? tsDataRealSolucao = dadosChamado[kFieldDataDaSolucao] as Timestamp?; // Timestamp de quando registrou
    final String dataRealSolucaoStr = _formatTimestamp(tsDataRealSolucao, 'dd/MM/yyyy HH:mm');

    // Dados da Confirmação do Requerente
    final bool requerenteConfirmou = dadosChamado[kFieldRequerenteConfirmou] as bool? ?? false;
    final Timestamp? tsRequerenteConfirmouData = dadosChamado[kFieldRequerenteConfirmouData] as Timestamp?;
    final String requerenteConfirmouDataStr = _formatTimestamp(tsRequerenteConfirmouData, 'dd/MM/yyyy HH:mm');
    final String nomeRequerenteQueConfirmou = dadosChamado[kFieldNomeRequerenteConfirmador] as String? ??
                                            (requerenteConfirmou ? nomeSolicitante : 'N/A'); // Usa nome do solicitante se não houver nome específico

    // Dados do Arquivamento
    final bool isFinalizado = statusChamado == kStatusFinalizado;
    final Timestamp? tsAdminFinalizouData = dadosChamado[kFieldAdminFinalizouData] as Timestamp?;
    final String adminFinalizouDataStr = _formatTimestamp(tsAdminFinalizouData, 'dd/MM/yyyy HH:mm');
    final String? adminFinalizouNome = dadosChamado[kFieldAdminFinalizouNome] as String?;


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

          // --- Título e Cabeçalho ---
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text('Relatório do Chamado', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                     pw.Text('ID: ${chamadoId.substring(0, min(6, chamadoId.length))}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                     pw.SizedBox(height: 2),
                     pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ]
                )

              ]
            )
          );
          widgets.add(pw.Divider(thickness: 1, height: 15));
          widgets.add(pw.SizedBox(height: 10));

          // --- Seção 1: Dados Gerais e do Solicitante ---
          widgets.add(_buildSectionHeader('Dados da Solicitação'));
          widgets.add(_buildPdfInfoRow('Status:', statusChamado, valueStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
          widgets.add(_buildPdfInfoRow('Solicitante:', nomeSolicitante));
          if (celularContato != null && celularContato.isNotEmpty) {
            widgets.add(_buildPdfInfoRow('Contato:', celularContato));
          }
          if (tipoSolicitante != null && tipoSolicitante.isNotEmpty) {
            widgets.add(_buildPdfInfoRow('Tipo Solicitante:', tipoSolicitante));
             // Detalhes específicos por tipo
             if (tipoSolicitante == 'ESCOLA') {
                if (displayCidade.isNotEmpty) widgets.add(_buildPdfInfoRow('Cidade/Distrito:', displayCidade));
                widgets.add(_buildPdfInfoRow('Instituição:', displayInstituicao, isParagraph: true));
                if (cargoFuncao != null && cargoFuncao.isNotEmpty) widgets.add(_buildPdfInfoRow('Cargo/Função:', cargoFuncao));
                if (atendimentoPara != null && atendimentoPara.isNotEmpty) widgets.add(_buildPdfInfoRow('Atendimento Para:', atendimentoPara));
             } else if (tipoSolicitante == 'SUPERINTENDENCIA') {
                widgets.add(_buildPdfInfoRow('Setor SUPER:', displayInstituicao, isParagraph: true));
                if (displayCidade.isNotEmpty) widgets.add(_buildPdfInfoRow('Cidade SUPER:', displayCidade));
             }
          }
          widgets.add(_buildPdfInfoRow('Data de Criação:', dataCriacaoStr));
          if (authUserDisplay != null && authUserDisplay.isNotEmpty) {
            widgets.add(_buildPdfInfoRow('Registrado por:', authUserDisplay));
          }
          widgets.add(pw.SizedBox(height: 10));


          // --- Seção 2: Detalhes do Problema e Equipamento ---
          widgets.add(_buildSectionHeader('Detalhes do Problema / Equipamento'));
          widgets.add(_buildPdfInfoRow('Problema Relatado:', displayProblema, isParagraph: true));
          widgets.add(_buildPdfInfoRow('Equipamento:', displayEquipamento, isParagraph: true));
           if (marcaModelo != null && marcaModelo.isNotEmpty) {
            widgets.add(_buildPdfInfoRow('Marca/Modelo:', marcaModelo));
          }
          if (patrimonio != null && patrimonio.isNotEmpty) {
            widgets.add(_buildPdfInfoRow('Patrimônio:', patrimonio));
          }
          if (conectadoInternet != null && conectadoInternet.isNotEmpty) {
             widgets.add(_buildPdfInfoRow('Possui Internet:', conectadoInternet));
          }
           if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) {
            widgets.add(_buildPdfInfoRow('Técnico Responsável:', tecnicoResponsavel));
          }
          widgets.add(pw.SizedBox(height: 15));


          // --- Seção 3: Solução (Se houver) ---
          // Exibe mesmo se status for 'Finalizado', pois a solução ocorreu antes.
          if (solucaoDescricao != null && solucaoDescricao.isNotEmpty) {
            widgets.add(_buildSectionHeader('Solução Registrada', color: PdfColors.blue700));
            widgets.add(_buildPdfInfoRow('Descrição:', solucaoDescricao, isParagraph: true));
            widgets.add(_buildPdfInfoRow('Data Atendimento (Informada):', dataAtendimentoInformadaStr)); // Data que o técnico informou ter atendido

            if (adminSolucionouNome != null && adminSolucionouNome.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 5));
              widgets.add(_buildPdfInfoRow('Solucionado por:', adminSolucionouNome, valueStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
              widgets.add(_buildPdfInfoRow('Data do Registro:', dataRealSolucaoStr)); // Data/Hora que a solução foi salva no sistema
              if (adminSignatureImage != null) {
                widgets.add(pw.SizedBox(height: 8));
                widgets.add(_buildSignatureBlock("Assinatura Técnico/Admin:", adminSignatureImage, adminSolucionouNome));
              } else if (adminSignatureUrl != null && adminSignatureUrl.isNotEmpty) {
                  widgets.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 135), child: pw.Text('[Falha ao carregar assinatura]', style: pw.TextStyle(color: PdfColors.red, fontStyle: pw.FontStyle.italic, fontSize: 9))));
              }
            }
            widgets.add(pw.SizedBox(height: 15));
          }

          // --- Seção 4: Confirmação do Requerente (Se houve) ---
          if (requerenteConfirmou) {
            widgets.add(_buildSectionHeader('Confirmação do Requerente', color: PdfColors.green700));
            widgets.add(_buildPdfInfoRow('Status Confirmação:', 'Solução Aceita pelo Requerente'));
            widgets.add(_buildPdfInfoRow('Confirmado por:', nomeRequerenteQueConfirmou));
            widgets.add(_buildPdfInfoRow('Data da Confirmação:', requerenteConfirmouDataStr));
            if (requesterSignatureImage != null) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(_buildSignatureBlock("Assinatura Requerente:", requesterSignatureImage, nomeRequerenteQueConfirmou));
            } else if (requesterSignatureUrl != null && requesterSignatureUrl.isNotEmpty) {
                 widgets.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 135), child: pw.Text('[Falha ao carregar assinatura]', style: pw.TextStyle(color: PdfColors.red, fontStyle: pw.FontStyle.italic, fontSize: 9))));
            }
             widgets.add(pw.SizedBox(height: 15));
          }

          // --- Seção 5: Arquivamento (Se status for Finalizado) ---
          if (isFinalizado) {
              widgets.add(_buildSectionHeader('Detalhes do Arquivamento', color: PdfColors.grey700));
              if (adminFinalizouNome != null && adminFinalizouNome.isNotEmpty) {
                  widgets.add(_buildPdfInfoRow('Arquivado por (Admin):', adminFinalizouNome));
              }
              widgets.add(_buildPdfInfoRow('Data do Arquivamento:', adminFinalizouDataStr));
              widgets.add(pw.SizedBox(height: 15));
          }


          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  // Widget auxiliar para Títulos de Seção
  static pw.Widget _buildSectionHeader(String title, {PdfColor color = PdfColors.black}) {
     return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6, top: 5),
        padding: const pw.EdgeInsets.only(bottom: 2),
        decoration: const pw.BoxDecoration(
           border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey500))
        ),
        child: pw.Text(
           title,
           style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        )
     );
  }


  // Widget auxiliar para Linhas de Informação (Label/Valor)
  static pw.Widget _buildPdfInfoRow(String label, String? value, {bool isParagraph = false, pw.TextStyle? valueStyle}) {
    final String displayValue = (value == null || value.trim().isEmpty) ? '--' : value.trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: isParagraph ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 130, // Largura fixa para o label
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(displayValue, style: valueStyle ?? const pw.TextStyle()),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para Bloco de Assinatura
  static pw.Widget _buildSignatureBlock(String title, pw.MemoryImage image, String? name) {
     return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
           pw.Padding( // Adiciona um recuo para alinhar com os valores
              padding: const pw.EdgeInsets.only(left: 135),
              child: pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.start,
                 children: [
                    pw.Text(title, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(
                        width: 150,
                        height: 50, // Levemente menor para economizar espaço
                        child: pw.Image(image, fit: pw.BoxFit.contain),
                      ),
                    pw.Container(width: 150, child: pw.Divider(thickness: 0.5)),
                    if (name != null && name.isNotEmpty)
                       pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                 ]
              )
           )
        ]
     );
  }

}