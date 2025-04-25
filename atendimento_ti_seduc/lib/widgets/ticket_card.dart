// lib/widgets/ticket_card.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart'; // Importa a classe de tema

class TicketCard extends StatelessWidget {
  final String titulo;
  final String prioridade;
  final String status;
  final String creatorName;
  final String dataFormatada;
  final String chamadoId; // Necessário para o onTap ou onDelete se a lógica estiver aqui
  final VoidCallback? onTap; // Callback para quando o card for clicado
  final VoidCallback? onDelete; // Callback para o ícone de excluir

  const TicketCard({
    super.key,
    required this.titulo,
    required this.prioridade,
    required this.status,
    required this.creatorName,
    required this.dataFormatada,
    required this.chamadoId, // Recebe o ID
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Obtém tema e cores
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color? textoSecundarioCor = textTheme.bodyMedium?.color;

    // Obtém cores de status e prioridade usando AppTheme
    final Color? corStatus = AppTheme.getStatusColor(status);
    final Color? corBordaPrioridade = AppTheme.getPriorityColor(prioridade);

    // --- CARD ESTILIZADO (Lógica movida para cá) ---
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // Raio padrão do tema
        side: BorderSide(
          color: corBordaPrioridade ?? Colors.transparent, // Borda de prioridade
          width: 1.5,
        ),
      ),
      // Sem cor ou elevação explícita, usa o tema
      child: InkWell( // Permite clique no card todo
        onTap: onTap, // Chama o callback passado
        child: Column( // Estrutura principal em Column
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- PARTE SUPERIOR: Avatar, Título, Excluir ---
            Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 6.0, 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar (Placeholder)
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primary.withOpacity(0.15),
                    child: Icon(
                      Icons.support_agent_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Título
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        titulo,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Ícone Excluir (se o callback for fornecido)
                  if (onDelete != null)
                    InkWell(
                      onTap: onDelete, // Chama o callback de exclusão
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 0),
                        child: Icon(Icons.delete_outline, color: AppTheme.kErrorColor.withOpacity(0.7), size: 18),
                      ),
                    ),
                ],
              ),
            ),

            // --- PARTE DO MEIO: Informações e Status ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prioridade (Texto)
                  Text(
                    'Prioridade: $prioridade',
                    style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                  ),
                  const SizedBox(height: 4),
                  // Status (Chip)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(status),
                      labelStyle: textTheme.labelSmall?.copyWith(
                        color: AppTheme.kTextColor.withOpacity(0.9),
                        fontWeight: FontWeight.w600
                      ),
                      backgroundColor: corStatus?.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Criador e Data
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Expanded(
                         child: Text(
                          'Por: $creatorName',
                          style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: textoSecundarioCor?.withOpacity(0.8)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                       ),
                       const SizedBox(width: 4),
                       Text(
                        dataFormatada,
                        style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor?.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(), // Empurra a barra inferior para baixo

            // --- BARRA INFERIOR (Indicador Placeholder) ---
            Container(
              height: 8.0,
              margin: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.5),
                    colorScheme.secondary.withOpacity(0.5),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}