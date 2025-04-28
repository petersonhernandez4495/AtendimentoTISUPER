// lib/widgets/ticket_card.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart'; // Garanta que este import está correto

class TicketCard extends StatelessWidget {
  // IMPORTANTE: Ao criar este widget, passe a descrição do problema
  // para o parâmetro 'titulo'.
  final String titulo; // <= Deve conter a descrição do problema vinda do seu dado
  final String prioridade;
  final String status;
  final String creatorName;
  final String dataFormatada;
  final String chamadoId;
  final String? creatorPhone;
  final String? tecnicoResponsavel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TicketCard({
    super.key,
    required this.titulo, // <= Recebe o problema aqui
    required this.prioridade,
    required this.status,
    required this.creatorName,
    required this.dataFormatada,
    required this.chamadoId,
    this.creatorPhone,
    this.tecnicoResponsavel,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Obtém tema e cores
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color? textoSecundarioCor = textTheme.bodySmall?.color?.withOpacity(0.7);
    final Color? corStatus = AppTheme.getStatusColor(status);
    final Color corPrioridade = AppTheme.getPriorityColor(prioridade) ?? colorScheme.primary;
    final BorderRadius borderRadius = BorderRadius.circular(12.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinha a barra ao topo
          children: [
            // Barra Lateral de Prioridade
            Container(
              width: 6.0,
              // Estica a barra verticalmente - truque usando constraints no pai ou garantindo altura mínima
              // Como o Row está com CrossAxisAlignment.start, a altura será definida pelo conteúdo.
              // Adicionamos altura mínima ao conteúdo para garantir que a barra apareça.
              color: corPrioridade,
              // A altura será implicitamente definida pelo conteúdo ao lado
            ),

            // Conteúdo Principal do Card
            Expanded(
              child: Padding(
                // AUMENTADO Padding vertical para aumentar a altura geral
                padding: const EdgeInsets.only(left: 12.0, right: 8.0, top: 16.0, bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Garante que a coluna não tente ser infinita
                  children: [
                    // PARTE SUPERIOR: Título (Problema) e Excluir
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: corPrioridade.withOpacity(0.1),
                          child: Icon(
                            Icons.report_problem_outlined, // Ícone talvez mais apropriado para problema
                            size: 16,
                            color: corPrioridade,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 0),
                            child: Text(
                              titulo, // Exibe o problema passado como título
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                              maxLines: 3, // Permite um pouco mais de linhas para o problema
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (onDelete != null)
                          InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 0, bottom: 4, right: 4),
                              child: Icon(
                                Icons.close,
                                color: AppTheme.kErrorColor.withOpacity(0.8),
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // AUMENTADO Espaçamento vertical
                    const SizedBox(height: 14.0),

                    // PARTE DO MEIO: Prioridade e Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Prioridade:',
                              style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prioridade,
                              style: textTheme.bodySmall?.copyWith(
                                  color: corPrioridade,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(status),
                          labelStyle: textTheme.labelSmall?.copyWith(
                            color: AppTheme.kTextColor.withOpacity(0.95),
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: corStatus?.withOpacity(0.85),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide.none,
                        ),
                      ],
                    ),

                    // AUMENTADO Espaçamento vertical
                    const SizedBox(height: 12.0),
                    Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)),
                    // AUMENTADO Espaçamento vertical
                    const SizedBox(height: 12.0),

                    // Informações do Criador e Data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline, size: 13, color: textoSecundarioCor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  creatorName,
                                  style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 11, color: textoSecundarioCor),
                            const SizedBox(width: 4),
                            Text(
                              dataFormatada,
                              style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Telefone e Técnico (Opcional)
                    if ((creatorPhone != null && creatorPhone!.isNotEmpty) || (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty)) ...[
                       // AUMENTADO Espaçamento vertical
                       const SizedBox(height: 10.0), // Pouco mais de espaço antes dos detalhes de contato
                      if (creatorPhone != null && creatorPhone!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 13, color: textoSecundarioCor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                creatorPhone!,
                                style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty) ...[
                        if (creatorPhone != null && creatorPhone!.isNotEmpty) const SizedBox(height: 6), // Espaço entre telefone e técnico
                        Row(
                          children: [
                            Icon(Icons.engineering_outlined, size: 13, color: textoSecundarioCor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Téc: $tecnicoResponsavel',
                                style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    // Fim das Informações
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}