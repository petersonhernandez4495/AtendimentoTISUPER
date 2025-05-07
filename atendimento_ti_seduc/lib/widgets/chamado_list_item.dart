import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../config/theme/app_theme.dart';
import '../services/chamado_service.dart';

class ChamadoListItem extends StatelessWidget {
  final String chamadoId;
  final Map<String, dynamic> chamadoData;
  final User? currentUser;
  final bool isAdmin;
  final Function(String) onConfirmar;
  final Function(String) onNavigateToDetails;
  final bool isLoadingConfirmation;
  final VoidCallback? onDelete;
  final Function(String) onDownloadPdf;
  final bool isLoadingPdfDownload;
  final Future<void> Function(String chamadoId)? onFinalizarArquivar;
  final bool isLoadingFinalizarArquivar;

  const ChamadoListItem({
    super.key,
    required this.chamadoId,
    required this.chamadoData,
    required this.currentUser,
    required this.isAdmin,
    required this.onConfirmar,
    required this.onNavigateToDetails,
    required this.isLoadingConfirmation,
    required this.onDownloadPdf,
    required this.isLoadingPdfDownload,
    this.onDelete,
    this.onFinalizarArquivar,
    this.isLoadingFinalizarArquivar = false,
  });

  String _formatTimestamp(Timestamp? timestamp, [String format = 'dd/MM/yy HH:mm']) {
    if (timestamp == null) return '--';
    return DateFormat(format, 'pt_BR').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color textoSecundarioCor = colorScheme.onSurfaceVariant.withOpacity(0.8);

    final String titulo = chamadoData[kFieldProblemaOcorre]?.toString() ?? chamadoData[kFieldEquipamentoSolicitacao]?.toString() ?? 'Chamado Sem Título';
    final String prioridade = chamadoData[kFieldPrioridade]?.toString() ?? 'Média';
    final String status = chamadoData[kFieldStatus]?.toString() ?? 'N/I';
    final String creatorName = chamadoData['creatorName']?.toString() ?? chamadoData[kFieldNomeSolicitante]?.toString() ?? 'N/I';
    final Timestamp? tsCriacao = chamadoData[kFieldDataCriacao] as Timestamp?;
    final String dataFormatada = _formatTimestamp(tsCriacao, 'dd/MM/yy');
    final String? tecnicoResponsavel = chamadoData[kFieldTecnicoResponsavel] as String?;
    final String? creatorPhone = chamadoData[kFieldCelularContato] as String?;

    final bool isInativo = chamadoData[kFieldAdminInativo] as bool? ?? false;
    final bool requerenteConfirmou = chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
    final String? creatorUid = chamadoData[kFieldCreatorUid] as String?;
    final String? currentUserId = currentUser?.uid;

    final String statusSolucionadoComparacao = kStatusPadraoSolicionado;

    final bool podeConfirmar = !isAdmin && currentUserId != null && currentUserId == creatorUid && status.toLowerCase() == statusSolucionadoComparacao.toLowerCase() && !requerenteConfirmou && !isInativo;
    final bool mostrarSolucaoAceitaChip = status.toLowerCase() == statusSolucionadoComparacao.toLowerCase() && requerenteConfirmou && !isInativo;
    final String? solucao = chamadoData[kFieldSolucao] as String?;

    final Color corPrioridade = AppTheme.getPriorityColor(prioridade) ?? colorScheme.primary;
    final Color? corStatus = AppTheme.getStatusColor(status);
    final bool isClickable = isAdmin || !isInativo;

    final String? tipoSolicitante = chamadoData[kFieldTipoSolicitante] as String?;
    String? localPrincipalDisplay;
    String? localSecundarioDisplay;

    final String? cidadeEscola = chamadoData[kFieldCidade] as String?;
    final String? instituicaoEscola = chamadoData[kFieldInstituicao] as String?;
    final String? instituicaoManualEscola = chamadoData[kFieldInstituicaoManual] as String?;
    final String? setorSuper = chamadoData[kFieldSetorSuper] as String?;
    final String? cidadeSuper = chamadoData[kFieldCidadeSuperintendencia] as String?;

    if (tipoSolicitante == 'ESCOLA') {
      if (cidadeEscola == "OUTRO" && instituicaoManualEscola != null && instituicaoManualEscola.isNotEmpty) {
        localPrincipalDisplay = instituicaoManualEscola;
        localSecundarioDisplay = "Outra Localidade";
      } else {
        localPrincipalDisplay = instituicaoEscola;
        localSecundarioDisplay = cidadeEscola;
      }
    } else if (tipoSolicitante == 'SUPERINTENDENCIA') {
      localPrincipalDisplay = setorSuper;
      localSecundarioDisplay = cidadeSuper;
    } else if (tipoSolicitante != null) {
      localPrincipalDisplay = instituicaoEscola ?? instituicaoManualEscola ?? setorSuper ?? "";
      localSecundarioDisplay = cidadeEscola ?? cidadeSuper;
    }

    String instituicaoCompleta = localPrincipalDisplay ?? "";
    if (localSecundarioDisplay != null && localSecundarioDisplay.isNotEmpty && localSecundarioDisplay != localPrincipalDisplay) {
      instituicaoCompleta += " ($localSecundarioDisplay)";
    }

    String infoSolicitanteCombinada = 'Solic.: $creatorName';
    if (instituicaoCompleta.trim().isNotEmpty) {
      infoSolicitanteCombinada += ' \u00B7 $instituicaoCompleta';
    }
    if (creatorPhone != null && creatorPhone.isNotEmpty) {
      infoSolicitanteCombinada += ' \u00B7 $creatorPhone';
    }
    
    final bool podeFinalizarPelaLista = isAdmin &&
                                (chamadoData[kFieldStatus] == kStatusPadraoSolicionado) &&
                                (chamadoData[kFieldRequerenteConfirmou] as bool? ?? false) &&
                                !(chamadoData[kFieldAdminFinalizou] as bool? ?? false) &&
                                onFinalizarArquivar != null;


    return Opacity(
      opacity: isInativo ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: isInativo ? BorderSide(color: Colors.grey.shade400, width: 0.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: isClickable ? () => onNavigateToDetails(chamadoId) : () {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Chamado inativo. Não pode ser aberto.'),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 3),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 10.0, 8.0, 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5.0,
                      margin: const EdgeInsets.only(right: 10.0),
                      decoration: BoxDecoration(
                        color: isInativo ? Colors.grey.shade400 : corPrioridade,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4))
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isInativo ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  infoSolicitanteCombinada,
                                  style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if(isInativo) ...[
                                        Chip(
                                          label: const Text('INATIVO'),
                                          labelStyle: textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          backgroundColor: Colors.red.shade600,
                                          padding: EdgeInsets.zero,
                                          labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Chip(
                                        label: Text(status.toUpperCase()),
                                        labelStyle: textTheme.labelSmall?.copyWith(
                                          color: corStatus != null && corStatus.computeLuminance() > 0.5 ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        backgroundColor: corStatus?.withOpacity(0.85) ?? Colors.grey,
                                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      if (mostrarSolucaoAceitaChip) ...[
                                        const SizedBox(width: 4),
                                        Tooltip(
                                          message: 'Solução aceita pelo requerente',
                                          child: Chip(
                                            avatar: Icon(Icons.check_circle_outline, size: 14, color: Colors.green[800]),
                                            label: Text('Aceita', style: textTheme.labelSmall?.copyWith(color: Colors.green[800], fontWeight: FontWeight.w500)),
                                            backgroundColor: Colors.green[100]?.withOpacity(0.7),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            side: BorderSide(color: Colors.green.shade200, width: 0.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dataFormatada,
                                    style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor.withOpacity(0.9)),
                                    textAlign: TextAlign.end,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.engineering_outlined, size: 11, color: textoSecundarioCor),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Téc: $tecnicoResponsavel',
                                      style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor, fontStyle: FontStyle.italic),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isClickable)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: textoSecundarioCor),
                        tooltip: "Mais opções",
                        onSelected: (value) {
                          if (value == 'details') {
                            onNavigateToDetails(chamadoId);
                          } else if (value == 'delete' && isAdmin && onDelete != null) {
                            onDelete!();
                          } else if (value == 'download_pdf_direct') {
                             onDownloadPdf(chamadoId);
                          } else if (value == 'confirmar_servico' && podeConfirmar) {
                             onConfirmar(chamadoId);
                          } else if (value == 'finalizar_arquivar' && podeFinalizarPelaLista) {
                            onFinalizarArquivar!(chamadoId);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          List<PopupMenuEntry<String>> items = [];
                          items.add(const PopupMenuItem<String>(value: 'details', child: Text('Ver Detalhes')));
                          
                          if (status.toLowerCase() == statusSolucionadoComparacao.toLowerCase() || status.toLowerCase() == kStatusFinalizado.toLowerCase()) {
                             items.add(PopupMenuItem<String>(
                                value: 'download_pdf_direct',
                                enabled: !isLoadingPdfDownload,
                                child: isLoadingPdfDownload ? const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 8), Text('Baixando PDF...')]) : const Text('Baixar PDF Solução'),
                              ));
                          }

                          if (podeConfirmar) {
                            items.add(PopupMenuItem<String>(
                              value: 'confirmar_servico',
                              enabled: !isLoadingConfirmation,
                              child: isLoadingConfirmation
                                  ? const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 8), Text('Confirmando...')])
                                  : const Text('Aceitar Solução'),
                            ));
                          }

                          if (podeFinalizarPelaLista) {
                            items.add(PopupMenuItem<String>(
                                value: 'finalizar_arquivar',
                                enabled: !isLoadingFinalizarArquivar,
                                child: isLoadingFinalizarArquivar
                                    ? const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 8), Text('Finalizando...')])
                                    : const Text('Finalizar e Arquivar'),
                            ));
                          }

                          if (isAdmin && onDelete != null) {
                            items.add(const PopupMenuDivider());
                            items.add(const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Excluir Chamado', style: TextStyle(color: Colors.red)),
                            ));
                          }
                          return items;
                        },
                      ),
                  ],
                ),
              ),
              if (!isInativo && podeConfirmar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 10.0),
                  child: Column(
                    children: [
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 8),
                      Center(
                        child: isLoadingConfirmation
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : OutlinedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text('Aceitar Solução'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green[800],
                                  side: BorderSide(color: Colors.green[700]!),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => onConfirmar(chamadoId),
                              ),
                      )
                    ],
                  ),
                ),
              if (!isInativo && status.toLowerCase() == statusSolucionadoComparacao.toLowerCase() && solucao != null && solucao.isNotEmpty && !podeConfirmar && !mostrarSolucaoAceitaChip)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 6),
                      Text("Solução:", style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(
                        solucao,
                        style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor.withOpacity(0.9)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                )
            ],
          ),
        ),
      ),
    );
  }
}