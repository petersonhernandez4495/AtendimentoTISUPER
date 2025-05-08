import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../config/theme/app_theme.dart';
import '../services/chamado_service.dart';
import '../detalhes_chamado_screen.dart';

class TicketCard extends StatelessWidget {
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

  const TicketCard({
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
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); final ColorScheme colorScheme = theme.colorScheme; final TextTheme textTheme = theme.textTheme; final Color textoSecundarioCor = colorScheme.onSurfaceVariant;
    final String titulo = chamadoData[kFieldProblemaOcorre]?.toString() ?? chamadoData[kFieldEquipamentoSolicitacao]?.toString() ?? 'Chamado Sem Título';
    final String prioridade = chamadoData[kFieldPrioridade]?.toString() ?? 'Média'; final String status = chamadoData[kFieldStatus]?.toString() ?? 'N/I'; final String creatorName = chamadoData['creatorName']?.toString() ?? chamadoData[kFieldNomeSolicitante]?.toString() ?? 'N/I'; final Timestamp? tsCriacao = chamadoData[kFieldDataCriacao] as Timestamp?; final String dataFormatada = tsCriacao != null ? DateFormat('dd/MM/yy').format(tsCriacao.toDate()) : '--'; final String? creatorPhone = chamadoData[kFieldCelularContato] as String?; final String? tecnicoResponsavel = chamadoData[kFieldTecnicoResponsavel] as String?; final String? tipoSolicitante = chamadoData[kFieldTipoSolicitante] as String?; final String? setorSuperintendencia = chamadoData[kFieldSetorSuper] as String?; final String? cidadeSuperintendencia = chamadoData[kFieldCidadeSuperintendencia] as String?; final String? instituicao = chamadoData[kFieldInstituicao] as String?; final String? cidade = chamadoData[kFieldCidade] as String?; final String? instituicaoManual = chamadoData[kFieldInstituicaoManual] as String?;
    final bool isInativo = chamadoData[kFieldAdminInativo] ?? false; final bool requerenteConfirmou = chamadoData[kFieldRequerenteConfirmou] ?? false; final String? creatorUid = chamadoData[kFieldCreatorUid] as String?; final String? currentUserId = currentUser?.uid;
    final bool podeConfirmar = !isAdmin && currentUserId != null && currentUserId == creatorUid && status == kStatusSolucionado && !requerenteConfirmou && !isInativo;
    final bool mostrarAreaConfirmado = status == kStatusSolucionado && requerenteConfirmou && !isInativo;
    final String? solucao = chamadoData[kFieldSolucao] as String?; // <<< EXTRAI A SOLUÇÃO >>>

    String? localPrincipalValue; IconData? localPrincipalIcon; String? localSecundarioValue; IconData? localSecundarioIcon; if (tipoSolicitante == 'ESCOLA') { localPrincipalIcon = Icons.account_balance_outlined; localPrincipalValue = (cidade == "OUTRO" && instituicaoManual != null && instituicaoManual.isNotEmpty) ? instituicaoManual : instituicao; localSecundarioIcon = Icons.location_city_outlined; localSecundarioValue = cidade == "OUTRO" ? "Outra Localidade" : cidade; } else if (tipoSolicitante == 'SUPERINTENDENCIA') { localPrincipalIcon = Icons.meeting_room_outlined; localPrincipalValue = setorSuperintendencia; localSecundarioIcon = Icons.location_city_rounded; localSecundarioValue = cidadeSuperintendencia; } else { localPrincipalIcon = Icons.business_outlined; localPrincipalValue = instituicao; localSecundarioIcon = Icons.location_city_outlined; localSecundarioValue = cidade; }
    final Color corPrioridade = AppTheme.getPriorityColor(prioridade) ?? colorScheme.primary; final Color? corStatus = AppTheme.getStatusColor(status); final BorderRadius borderRadius = BorderRadius.circular(12.0);

    return Card( margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: borderRadius), elevation: isInativo ? 0.5 : 1.5, color: isInativo ? Colors.grey.shade100 : null, child: InkWell( onTap: () { if (isAdmin || !isInativo) { onNavigateToDetails(chamadoId); } else { ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: const Text('Chamado inativo.'), backgroundColor: Colors.orange.shade800, duration: const Duration(seconds: 3), ), ); } }, borderRadius: borderRadius, child: Row( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ Container( width: 10.0, color: isInativo ? Colors.grey.shade400 : corPrioridade, ), Expanded( child: Padding( padding: const EdgeInsets.only(left: 15, right: 10, top: 12.0, bottom: 12.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.start, children: [ Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ Padding( padding: const EdgeInsets.only(top: 3.0), child: CircleAvatar( radius: 14, backgroundColor: corPrioridade.withOpacity(0.1), child: Icon(Icons.report_problem_outlined, size: 15, color: corPrioridade),),), const SizedBox(width: 10), Expanded( child: Text( titulo, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3, decoration: isInativo ? TextDecoration.lineThrough : null,), maxLines: 3, overflow: TextOverflow.ellipsis, ),), if (isInativo) Padding( padding: const EdgeInsets.only(left: 8.0), child: Chip( label: const Text('INATIVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade700, padding: EdgeInsets.zero, labelPadding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, side: BorderSide.none, ),), if (isAdmin && onDelete != null) InkWell( onTap: onDelete, borderRadius: BorderRadius.circular(20), child: Padding( padding: const EdgeInsets.all(4.0), child: Icon(Icons.close_rounded, color: AppTheme.kErrorColor.withOpacity(0.7), size: 18),),), ], ), const SizedBox(height: 10.0),
                    Row( children: [ Expanded( child: Row( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.label_important_outline, size: 13, color: textoSecundarioCor), const SizedBox(width: 4), Flexible( child: Text( prioridade, style: textTheme.bodySmall?.copyWith(color: corPrioridade, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1, ),),],),), const SizedBox(width: 8), Chip( label: Text(status.toUpperCase()), labelStyle: textTheme.labelSmall?.copyWith( color: corStatus != null && corStatus.computeLuminance() > 0.5 ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600, letterSpacing: 0.5, ), backgroundColor: corStatus?.withOpacity(0.9), padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),), ], ), const SizedBox(height: 10.0), Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)), const SizedBox(height: 8.0),
                    Row( crossAxisAlignment: CrossAxisAlignment.center, children: [ Expanded( child: Row( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.person_outline, size: 13, color: textoSecundarioCor), const SizedBox(width: 4), Flexible( child: Text( creatorName, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor), maxLines: 1, overflow: TextOverflow.ellipsis, ),),],),), const SizedBox(width: 10), Row( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.calendar_today_outlined, size: 11, color: textoSecundarioCor), const SizedBox(width: 4), Text( dataFormatada, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor), maxLines: 1, overflow: TextOverflow.ellipsis, ),],), ], ),
                    if (localPrincipalValue != null && localPrincipalValue.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0, bottom: 0), child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [ Icon(localPrincipalIcon, size: 13, color: textoSecundarioCor), const SizedBox(width: 6), Expanded( child: Text( localPrincipalValue, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor), maxLines: 1, overflow: TextOverflow.ellipsis, ),),],),),
                    if (localSecundarioValue != null && localSecundarioValue.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0, bottom: 0), child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [ Icon(localSecundarioIcon, size: 13, color: textoSecundarioCor), const SizedBox(width: 6), Expanded( child: Text( localSecundarioValue, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor), maxLines: 1, overflow: TextOverflow.ellipsis, ),),],),),
                    if ((creatorPhone != null && creatorPhone.isNotEmpty) || (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty)) Padding( padding: const EdgeInsets.only(top: 4.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ if (creatorPhone != null && creatorPhone.isNotEmpty) Padding( padding: EdgeInsets.only( bottom: (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) ? 2.0 : 0, ), child: Row( children: [ Icon(Icons.phone_outlined, size: 13, color: textoSecundarioCor), const SizedBox(width: 4), Expanded( child: Text( creatorPhone, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor), maxLines: 1, overflow: TextOverflow.ellipsis, ),),],),), if (tecnicoResponsavel != null && tecnicoResponsavel.isNotEmpty) Row( children: [ Icon(Icons.engineering_outlined, size: 13, color: textoSecundarioCor), const SizedBox(width: 4), Expanded( child: Text( 'Téc: $tecnicoResponsavel', style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis, ),),],), ],),),

                    if (podeConfirmar || mostrarAreaConfirmado) Padding( padding: const EdgeInsets.only(top: 10.0), child: Column( children: [
                          const Divider(height: 1), const SizedBox(height: 8),
                          if (podeConfirmar) Center( child: isLoadingConfirmation ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : OutlinedButton.icon( icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('Aceitar Solução'), style: OutlinedButton.styleFrom( foregroundColor: Colors.green[800], side: BorderSide(color: Colors.green[700]!), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold) ), onPressed: () => onConfirmar(chamadoId), ), )
                          else if (mostrarAreaConfirmado) Center( child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Chip( label: Text('Solução Aceita', style: textTheme.labelSmall?.copyWith(color: Colors.green[800])), avatar: Icon(Icons.check_circle, size: 16, color: Colors.green[700]), backgroundColor: Colors.green[100], visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0), ), const SizedBox(width: 8), IconButton( icon: isLoadingPdfDownload ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 20), tooltip: 'Baixar PDF Confirmado', color: colorScheme.primary, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: isLoadingPdfDownload ? null : () => onDownloadPdf(chamadoId), ) ], ), ),
                        ], ), ),

                    // --- NOVA SEÇÃO: EXIBIR SOLUÇÃO ---
                    if (status == kStatusSolucionado && solucao != null && solucao.isNotEmpty)
                       Padding(
                         padding: const EdgeInsets.only(top: 10.0), // Espaço acima
                         child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               const Divider(height: 1), // Divisor opcional
                               const SizedBox(height: 6),
                               Text( "Solução/Diagnótico:", style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                               const SizedBox(height: 2),
                               Text(
                                  solucao,
                                  style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                  maxLines: 3, // Limita o número de linhas no card
                                  overflow: TextOverflow.ellipsis, // Adiciona "..." se for maior
                               ),
                            ]
                         ),
                       )
                    // --- FIM NOVA SEÇÃO ---

                  ], ), ), ), ], ), ), );
  }
}