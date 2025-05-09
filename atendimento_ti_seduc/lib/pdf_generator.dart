// lib/pdf_generator.dart

import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw; // Para o QR Code

// --- INÍCIO: CONSTANTES DE CAMPO ---
const String kFieldStatus = 'status';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldEquipamentoSolicitacao = 'equipamento_solicitacao';
const String kFieldProblemaOcorre = 'problema_ocorre';
const String kFieldSolucao = 'solucao';
const String kFieldDataAtendimento = 'data_atendimento';
const String kFieldSolucaoPorNome = 'solucaoPorNome';
const String kFieldDataDaSolucao = 'dataDaSolucao';
const String kFieldDataCriacao = 'data_criacao';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador';
const String kFieldCelularContato = 'celular_contato';
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
const String kFieldInstituicaoManual = 'instituicao_manual';
const String kFieldCargoFuncao = 'cargo_funcao';
const String kFieldAtendimentoPara = 'atendimento_para';
const String kFieldSetorSuper = 'setor_superintendencia';
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia';
const String kFieldMarcaModelo = 'marca_modelo';
const String kFieldPatrimonio = 'patrimonio';
const String kFieldConectadoInternet = 'conectado_internet';
const String kFieldEquipamentoOutro = 'equipamento_outro';
const String kFieldProblemaOutro = 'problema_outro';
const String kFieldTecnicoResponsavel = 'tecnico_responsavel';
// --- FIM: CONSTANTES DE CAMPO ---

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
      print(
          'PDFGenerator: Falha ao baixar imagem de $url. Status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('PDFGenerator: Erro ao baixar imagem de $url: $e');
      return null;
    }
  }

  static String _formatTimestamp(Timestamp? ts, String format,
      {String defaultValue = '--'}) {
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
    String? adminSignatureUrl,
    String? requesterSignatureUrl,
    // Estes bytes devem ser carregados no seu código Flutter antes de chamar esta função
    // Ex: logoGovBytes para FOTO-PERFIL_ROLIM-DE-MOURA.jpg
    // Ex: logoEmblemBytes para seu_logo.jpg (ChamaTI)
    Uint8List? logoGovBytes,
    Uint8List? logoEmblemBytes,
  }) async {
    final pdf = pw.Document();

    final String nomeSolicitante =
        dadosChamado[kFieldNomeSolicitante] as String? ?? 'N/I';
    final String? celularContato =
        dadosChamado[kFieldCelularContato] as String?;

    final String problemaOcorre =
        dadosChamado[kFieldProblemaOcorre] as String? ?? 'N/I';
    final String? problemaOutroDesc =
        dadosChamado[kFieldProblemaOutro] as String?;
    String displayProblema = problemaOcorre;
    if (problemaOcorre.toUpperCase() == "OUTRO" &&
        problemaOutroDesc != null &&
        problemaOutroDesc.isNotEmpty) {
      displayProblema = "$problemaOcorre: $problemaOutroDesc";
    }

    final String? equipamentoSelecionado =
        dadosChamado[kFieldEquipamentoSolicitacao] as String?;
    final String? equipamentoOutroDesc =
        dadosChamado[kFieldEquipamentoOutro] as String?;
    String displayEquipamento = equipamentoSelecionado ?? 'N/I';
    if (equipamentoSelecionado?.toUpperCase() == "OUTRO" &&
        equipamentoOutroDesc != null &&
        equipamentoOutroDesc.isNotEmpty) {
      displayEquipamento = "$equipamentoSelecionado: $equipamentoOutroDesc";
    }

    final String headerNomeGerencia =
        "Gerência de Infraestrutura e Suporte - GIS";
    final String headerTelefoneGerencia = "(69) 3212-8218";
    final String headerEnderecoGerencia =
        dadosChamado['endereco_gerencia_organizacao'] as String? ??
            "Palácio Rio Madeira - Rio Guaporé - Porto Velho - Rondônia";

    final Timestamp? tsDataCriacao =
        dadosChamado[kFieldDataCriacao] as Timestamp?;
    final String dataOSStr = _formatTimestamp(tsDataCriacao, 'dd/MM/yyyy');

    final String? tipoSolicitante =
        dadosChamado[kFieldTipoSolicitante] as String?;

    String clienteInfoLabel1 = '';
    String clienteInfoValor1 = '--';
    String clienteInfoLabel2 = '';
    String clienteInfoValor2 = '--';
    String instituicaoParaEscola = '--';

    if (tipoSolicitante == 'ESCOLA') {
      final String? instituicao = dadosChamado[kFieldInstituicao] as String?;
      final String? instituicaoManual =
          dadosChamado[kFieldInstituicaoManual] as String?;
      if (instituicao?.toUpperCase() == 'OUTRO' &&
          instituicaoManual != null &&
          instituicaoManual.isNotEmpty) {
        instituicaoParaEscola = instituicaoManual;
      } else if (instituicao != null && instituicao.isNotEmpty) {
        instituicaoParaEscola = instituicao;
      }
      clienteInfoLabel1 = 'Atendimento Para:';
      clienteInfoValor1 =
          dadosChamado[kFieldAtendimentoPara] as String? ?? '--';
      clienteInfoLabel2 = 'Instituição:';
      clienteInfoValor2 = instituicaoParaEscola;
    } else if (tipoSolicitante == 'SUPERINTENDENCIA') {
      clienteInfoLabel1 = 'Setor:';
      clienteInfoValor1 = dadosChamado[kFieldSetorSuper] as String? ?? '--';
      clienteInfoLabel2 = 'Cidade (SUP):';
      clienteInfoValor2 =
          dadosChamado[kFieldCidadeSuperintendencia] as String? ?? '--';
    }

    String tituloServico = displayProblema;
    if (displayEquipamento != 'N/I' && displayEquipamento.isNotEmpty) {
      tituloServico += " em ${displayEquipamento}";
    }
    final String? cidadeChamado = dadosChamado[kFieldCidade] as String?;
    if (cidadeChamado != null &&
        cidadeChamado.isNotEmpty &&
        tipoSolicitante == 'ESCOLA') {
      tituloServico += " - ${cidadeChamado}";
    }

    pw.MemoryImage? adminSignatureImage;
    if (adminSignatureUrl != null && adminSignatureUrl.isNotEmpty) {
      Uint8List? adminSigBytes = await _fetchImageFromUrl(adminSignatureUrl);
      if (adminSigBytes != null) {
        try {
          adminSignatureImage = pw.MemoryImage(adminSigBytes);
        } catch (e) {
          print('PDFGenerator: Erro MemoryImage admin: $e');
        }
      }
    }

    pw.MemoryImage? requesterSignatureImage;
    if (requesterSignatureUrl != null && requesterSignatureUrl.isNotEmpty) {
      Uint8List? requesterSigBytes =
          await _fetchImageFromUrl(requesterSignatureUrl);
      if (requesterSigBytes != null) {
        try {
          requesterSignatureImage = pw.MemoryImage(requesterSigBytes);
        } catch (e) {
          print('PDFGenerator: Erro MemoryImage requerente: $e');
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          build: (pw.Context context) {
            List<pw.Widget> widgets = [];

            widgets.add(_buildCustomHeader(
              logoGovBytes:
                  logoGovBytes, // Passar os bytes da imagem "FOTO-PERFIL_ROLIM-DE-MOURA.jpg"
              logoEmblemBytes:
                  logoEmblemBytes, // Passar os bytes da imagem "seu_logo.jpg" (ChamaTI)
              nomeGerencia: headerNomeGerencia,
              telefoneGerencia: headerTelefoneGerencia,
              enderecoGerencia: headerEnderecoGerencia,
              osNumero: chamadoId,
              osData: dataOSStr,
            ));
            widgets.add(pw.SizedBox(height: 12));

            widgets.add(_buildSectionTitle("DADOS DO CLIENTE"));
            widgets.add(_buildDadosClienteTable(
                requerente: nomeSolicitante,
                telefone: celularContato ?? '--',
                tipoSolicitante: tipoSolicitante,
                label1: clienteInfoLabel1,
                valor1: clienteInfoValor1,
                label2: clienteInfoLabel2,
                valor2: clienteInfoValor2));
            widgets.add(pw.SizedBox(height: 8));

            widgets.add(_buildSectionTitle("DETALHES DA ORDEM DE SERVIÇO"));
            widgets.add(_buildDetalhesOrdemServicoTable(
              titulo: tituloServico,
            ));
            widgets.add(pw.SizedBox(height: 12));

            final String? solucaoDescricao =
                dadosChamado[kFieldSolucao] as String?;
            final String? adminSolucionouNome =
                dadosChamado[kFieldSolucaoPorNome] as String?;
            final Timestamp? tsDataRealSolucao =
                dadosChamado[kFieldDataDaSolucao] as Timestamp?;
            final String dataRealSolucaoStr =
                _formatTimestamp(tsDataRealSolucao, 'dd/MM/yyyy HH:mm');

            if (solucaoDescricao != null && solucaoDescricao.isNotEmpty) {
              widgets.add(_buildSectionTitle("SOLUÇÃO REGISTRADA",
                  titleColor: PdfColors.blueGrey700));
              widgets.add(pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                  ),
                  child: pw.Text(solucaoDescricao,
                      style: const pw.TextStyle(fontSize: 8.5))));
              if (adminSolucionouNome != null &&
                  adminSolucionouNome.isNotEmpty) {
                widgets.add(_buildPdfInfoRow(
                    'Solucionado por:', adminSolucionouNome,
                    valueStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8.5)));
                widgets.add(_buildPdfInfoRow(
                    'Data do Registro da Solução:', dataRealSolucaoStr,
                    valueStyle: const pw.TextStyle(fontSize: 8.5)));
                if (adminSignatureImage != null) {
                  widgets.add(pw.SizedBox(height: 4));
                  widgets.add(_buildSignatureBlock("Assinatura Técnico/Admin:",
                      adminSignatureImage, adminSolucionouNome,
                      alignment: pw.CrossAxisAlignment.start));
                }
              }
              widgets.add(pw.SizedBox(height: 8));
            }

            final bool requerenteConfirmou =
                dadosChamado[kFieldRequerenteConfirmou] as bool? ?? false;
            if (requerenteConfirmou) {
              final String nomeRequerenteQueConfirmou =
                  dadosChamado[kFieldNomeRequerenteConfirmador] as String? ??
                      nomeSolicitante;
              final Timestamp? tsRequerenteConfirmouData =
                  dadosChamado[kFieldRequerenteConfirmouData] as Timestamp?;
              final String requerenteConfirmouDataStr = _formatTimestamp(
                  tsRequerenteConfirmouData, 'dd/MM/yyyy HH:mm');

              widgets.add(_buildSectionTitle('CONFIRMAÇÃO DO REQUERENTE',
                  titleColor: PdfColors.green700));
              widgets.add(_buildPdfInfoRow(
                  'Status Confirmação:', 'Solução Aceita pelo Requerente',
                  valueStyle: const pw.TextStyle(fontSize: 8.5)));
              widgets.add(_buildPdfInfoRow(
                  'Confirmado por:', nomeRequerenteQueConfirmou,
                  valueStyle: const pw.TextStyle(fontSize: 8.5)));
              widgets.add(_buildPdfInfoRow(
                  'Data da Confirmação:', requerenteConfirmouDataStr,
                  valueStyle: const pw.TextStyle(fontSize: 8.5)));
              if (requesterSignatureImage != null) {
                widgets.add(pw.SizedBox(height: 4));
                widgets.add(_buildSignatureBlock("Assinatura Requerente:",
                    requesterSignatureImage, nomeRequerenteQueConfirmou,
                    alignment: pw.CrossAxisAlignment.start));
              }
              widgets.add(pw.SizedBox(height: 12));
            }
            return widgets;
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.Theme.of(context)
                    .defaultTextStyle
                    .copyWith(color: PdfColors.grey, fontSize: 8),
              ),
            );
          }),
    );
    return pdf.save();
  }

  static pw.Widget _buildCustomHeader({
    Uint8List? logoGovBytes,
    Uint8List? logoEmblemBytes,
    required String nomeGerencia,
    required String telefoneGerencia,
    required String enderecoGerencia,
    required String osNumero,
    required String osData,
  }) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            pw.CrossAxisAlignment.start, // Alinha o topo dos elementos
        children: [
          // Coluna Esquerda: Logos
          pw.Container(
            // Container para os logos
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment
                  .center, // Alinha os logos verticalmente se tiverem alturas diferentes
              children: [
                if (logoGovBytes != null)
                  pw.Image(pw.MemoryImage(logoGovBytes),
                      width: 90,
                      height: 75,
                      fit: pw.BoxFit.contain), // Ajuste o fit se necessário
                if (logoGovBytes != null && logoEmblemBytes != null)
                  pw.SizedBox(width: 2),
                if (logoEmblemBytes != null)
                  pw.Image(pw.MemoryImage(logoEmblemBytes),
                      width: 80,
                      height: 80,
                      fit: pw.BoxFit.contain), // Ajuste o fit se necessário
              ],
            ),
          ),
          // Coluna Central: Informações da Gerência (Alinhado à esquerda)
          pw.Expanded(
              flex: 3, // Ajuste o flex conforme necessário para o espaçamento
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10), // Espaçamento horizontal
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start, // Alinhamento à esquerda
                  children: [
                    pw.Text(nomeGerencia,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                    pw.SizedBox(height: 2), // Espaço entre nome e telefone
                    pw.Text(telefoneGerencia,
                        style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 1), // Espaço entre telefone e endereço
                    pw.Text(enderecoGerencia,
                        style: const pw.TextStyle(fontSize: 7.5),
                        textAlign: pw.TextAlign.left), // Alinhamento à esquerda
                  ],
                ),
              )),
          // Coluna Direita: OS, Data, QR Code
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("OS Nº", style: const pw.TextStyle(fontSize: 9)),
              pw.Text(osNumero.substring(0, min(6, osNumero.length)),
                  style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.redAccent700)),
              pw.Text(osData, style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 3),
              pw.BarcodeWidget(
                  barcode: bw.Barcode.qrCode(),
                  data: "ID Chamado: $osNumero",
                  width: 42,
                  height: 42,
                  color: PdfColors.black,
                  margin: const pw.EdgeInsets.only(top: 2)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(thickness: 1.2, height: 0, color: PdfColors.black),
    ]);
  }

  static pw.Widget _buildSectionTitle(String title,
      {PdfColor titleColor = PdfColors.black}) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 0),
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: titleColor),
      ),
    );
  }

  static pw.Widget _buildCell(
    String text, {
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    double fontSize = 8.5,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    int flex = 1,
    PdfColor textColor = PdfColors.black,
    bool isLabel = false,
    double? fixedWidth,
  }) {
    final cellContent = pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: alignment,
      child: pw.Text(
        text,
        softWrap: true,
        style: pw.TextStyle(
            fontWeight: isLabel ? pw.FontWeight.bold : fontWeight,
            fontSize: fontSize,
            color: textColor),
      ),
    );

    if (fixedWidth != null) {
      return pw.SizedBox(width: fixedWidth, child: cellContent);
    }
    return pw.Expanded(
      flex: flex,
      child: cellContent,
    );
  }

  static pw.Widget _buildDadosClienteTable({
    required String requerente,
    required String telefone,
    String? tipoSolicitante,
    String? label1,
    String? valor1,
    String? label2,
    String? valor2,
  }) {
    List<pw.TableRow> rows = [
      pw.TableRow(children: [
        _buildCell('Requerente:', isLabel: true),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: _buildCell(requerente)),
            _buildCell('Telefone:',
                isLabel: true,
                fixedWidth: 55,
                alignment: pw.Alignment.centerRight),
            _buildCell(telefone, fixedWidth: 90),
          ],
        ),
      ]),
    ];

    if ((tipoSolicitante == 'ESCOLA' ||
            tipoSolicitante == 'SUPERINTENDENCIA') &&
        label1 != null &&
        label1.isNotEmpty &&
        label2 != null &&
        label2.isNotEmpty) {
      rows.add(pw.TableRow(
        children: [
          _buildCell(label1, isLabel: true),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: _buildCell(valor1 ?? '--')),
              _buildCell(label2,
                  isLabel: true,
                  fixedWidth: 85,
                  alignment: pw.Alignment.centerRight),
              _buildCell(valor2 ?? '--', fixedWidth: 90),
            ],
          ),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(90),
        1: pw.FlexColumnWidth(),
      },
      children: rows,
    );
  }

  static pw.Widget _buildDetalhesOrdemServicoTable({
    required String titulo,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(70),
        1: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(children: [
          _buildCell('Título:', isLabel: true),
          _buildCell(titulo),
        ]),
      ],
    );
  }

  static pw.Widget _buildPdfInfoRow(String label, String? value,
      {pw.TextStyle? valueStyle}) {
    final String displayValue =
        (value == null || value.trim().isEmpty) ? '--' : value.trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0, horizontal: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
          ),
          pw.Expanded(
            child: pw.Text(displayValue,
                style: valueStyle ?? const pw.TextStyle(fontSize: 8.5)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureBlock(
      String title, pw.MemoryImage image, String? name,
      {pw.CrossAxisAlignment alignment = pw.CrossAxisAlignment.center}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2, left: 4, right: 4),
        child: pw.Column(crossAxisAlignment: alignment, children: [
          if (alignment == pw.CrossAxisAlignment.start)
            pw.Text(title,
                style: const pw.TextStyle(
                    fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(
            width: 110,
            height: 35,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
          pw.Container(
              width: 110,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Divider(thickness: 0.4, color: PdfColors.grey600),
                    if (name != null && name.isNotEmpty)
                      pw.Text(name, style: const pw.TextStyle(fontSize: 8.5)),
                  ])),
        ]));
  }
}
