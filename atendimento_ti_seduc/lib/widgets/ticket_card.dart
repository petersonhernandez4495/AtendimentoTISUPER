// lib/widgets/ticket_card.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart'; // Garanta que este import está correto

class TicketCard extends StatelessWidget {
  final String titulo;
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
    required this.titulo,
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

    // >> VALOR DA ALTURA MÍNIMA DO CARD <<
    // Ajuste este valor para definir a altura mínima desejada para o card
    const double alturaMinimaCard = 250.0; // Exemplo: 250 pixels

    return Card(
      // Margem externa mantida
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      // >> REINTRODUZIDO ConstrainedBox para forçar altura mínima <<
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: alturaMinimaCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Estica barra lateral
            children: [
              // Barra Lateral de Prioridade (largura aumentada mantida)
              Container(
                width: 10.0,
                color: corPrioridade,
              ),

              // Conteúdo Principal do Card
              Expanded(
                child: Padding(
                  // Padding interno mantido
                  padding: const EdgeInsets.only(left: 15, right: 10, top: 20.0, bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Vertical alignment within the ConstrainedBox height
                    // Use MainAxisAlignment.start to align content to the top
                    // Use MainAxisAlignment.center to center
                    // Use MainAxisAlignment.spaceBetween to distribute space (might reintroduce issues if content > minHeight)
                    // Use MainAxisAlignment.spaceEvenly for even distribution
                    mainAxisAlignment: MainAxisAlignment.start, // Alinha conteúdo ao topo (padrão)
                    mainAxisSize: MainAxisSize.min, // Evita que a coluna tente ser infinita
                    children: [
                      // PARTE SUPERIOR: Título (Problema) e Excluir
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: corPrioridade.withOpacity(0.1),
                            child: Icon(
                              Icons.report_problem_outlined,
                              size: 16,
                              color: corPrioridade,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 0),
                              child: Text(
                                titulo,
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                                maxLines: 3,
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
                      const SizedBox(height: 18.0), // Espaçamento mantido

                      // PARTE DO MEIO: Prioridade e Status (Row Modificada mantida)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Prioridade:',
                                  style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    prioridade,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: corPrioridade,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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

                      const SizedBox(height: 20.0), // Espaçamento mantido
                      Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)),
                      const SizedBox(height: 15.0), // Espaçamento mantido

                      // Informações do Criador e Data (Row Modificada mantida)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                          const SizedBox(width: 20),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 11, color: textoSecundarioCor),
                              const SizedBox(width: 4),
                              Text(
                                dataFormatada,
                                style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Telefone e Técnico (Opcional)
                      if ((creatorPhone != null && creatorPhone!.isNotEmpty) || (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty)) ...[
                         const SizedBox(height: 12.0), // Espaçamento mantido
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
                          if (creatorPhone != null && creatorPhone!.isNotEmpty) const SizedBox(height: 8.0), // Espaçamento mantido
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
                      // Adiciona um Spacer no final se quiser que o conteúdo acima
                      // seja empurrado para cima quando houver espaço extra devido ao minHeight.
                      // Se preferir que o espaço extra fique no final, não adicione o Spacer.
                      // const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}