// lib/widgets/ticket_card.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart';

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
    final Color? textoSecundarioCor = textTheme.bodyMedium?.color;
    final Color? corStatus = AppTheme.getStatusColor(status);
    final BorderRadius borderRadius = BorderRadius.circular(16.0);
    // Cor base da prioridade (viva)
    final Color? corPrioridade = AppTheme.getPriorityColor(prioridade);
    // Cor de fallback para sombra/neon
    final Color neonColorFallback = Colors.grey[850]!;

    // --- PARÂMETROS AJUSTADOS PARA EFEITO "NEON" ---
    final Color neonColor = corPrioridade ?? neonColorFallback; // Usa cor da prioridade ou fallback cinza
    final double neonOpacity = 0.65; // <<< Opacidade da cor neon (ajuste 0.0 a 1.0)
    final double blurRadiusValue = 5.0;  // <<< DIMINUÍDO para borda mais nítida
    final double spreadRadiusValue = 4.0; // <<< AUMENTADO para "linha" neon mais grossa
    final Offset offsetValue = const Offset(4.0, 4.0); // <<< Mantém deslocamento (ou Offset.zero para halo)
    // --------------------------------------------

    // Container Externo para Sombra/Neon
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius, // Arredonda a área da sombra
        boxShadow: [
          // --- SOMBRA CONFIGURADA PARA "NEON" ---
          BoxShadow(
            color: neonColor.withOpacity(neonOpacity), // Cor VIVA com opacidade
            blurRadius: blurRadiusValue,     // Menos desfoque = mais nítido
            spreadRadius: spreadRadiusValue,   // Mais expansão = linha mais grossa
            offset: offsetValue,           // Deslocamento para baixo/direita
          ),
          // --- Opcional: Segunda Sombra mais suave por fora ---
          // Adicionar uma segunda sombra com mais blur e menos opacidade pode
          // realçar o efeito neon. Descomente para testar:
          /*
          BoxShadow(
            color: neonColor.withOpacity(neonOpacity * 0.4), // Mesma cor, bem menos opaca
            blurRadius: blurRadiusValue * 3, // Desfoque bem maior
            spreadRadius: spreadRadiusValue * 0.5, // Expansão menor que a principal
            offset: offsetValue, // Mesmo deslocamento
          ),
          */
          // ----------------------------------------------------
        ],
      ),
      // Conteúdo Interno (Card Visual)
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container( // Container com fundo gradiente cinza/preto
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ Colors.grey[850]!.withOpacity(0.85), Colors.black.withOpacity(0.5), ],
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
              ),
            ),
            child: InkWell( // Conteúdo clicável
              onTap: onTap,
              borderRadius: borderRadius,
              child: Column( // Layout interno (mantido)
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // PARTE SUPERIOR: Avatar, Título, Excluir
                   Padding( padding: const EdgeInsets.fromLTRB(10.0, 10.0, 6.0, 8.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ CircleAvatar( radius: 18, backgroundColor: colorScheme.primary.withOpacity(0.15), child: Icon( Icons.support_agent_outlined, size: 18, color: colorScheme.primary, ), ), const SizedBox(width: 8), Expanded( child: Padding( padding: const EdgeInsets.only(top: 2.0), child: Text( titulo, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis, ), ), ), if (onDelete != null) InkWell( onTap: onDelete, child: Padding( padding: const EdgeInsets.only(left: 4.0, top: 0), child: Icon(Icons.delete_outline, color: AppTheme.kErrorColor.withOpacity(0.7), size: 18), ), ), ], ), ),
                   // PARTE DO MEIO: Informações
                   Padding( padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( 'Prioridade: $prioridade', style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor), ), const SizedBox(height: 4), Align( alignment: Alignment.centerLeft, child: Chip( label: Text(status), labelStyle: textTheme.labelSmall?.copyWith( color: AppTheme.kTextColor.withOpacity(0.9), fontWeight: FontWeight.w600 ), backgroundColor: corStatus?.withOpacity(0.8), padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, side: BorderSide.none, ), ), const SizedBox(height: 6), Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( 'Por: $creatorName', style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: textoSecundarioCor?.withOpacity(0.8)), maxLines: 1, overflow: TextOverflow.ellipsis, ), const SizedBox(height: 2), Text( dataFormatada, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor?.withOpacity(0.7)), ), ], ), if (creatorPhone != null && creatorPhone!.isNotEmpty) ...[ const SizedBox(height: 4), Row( children: [ Icon(Icons.phone_outlined, size: 11, color: textoSecundarioCor?.withOpacity(0.8)), const SizedBox(width: 4), Expanded( child: Text( creatorPhone!, style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor?.withOpacity(0.8)), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), ], ), ], if (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty) ...[ const SizedBox(height: 4), Row( children: [ Icon(Icons.engineering_outlined, size: 11, color: textoSecundarioCor?.withOpacity(0.8)), const SizedBox(width: 4), Expanded( child: Text( 'Téc: $tecnicoResponsavel', style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor?.withOpacity(0.8)), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), ], ), ], ], ), ),
                   const Spacer(),
                   // BARRA INFERIOR (Placeholder)
                   Container( height: 8.0, margin: const EdgeInsets.all(10.0), decoration: BoxDecoration( borderRadius: BorderRadius.circular(4.0), gradient: LinearGradient( colors: [ colorScheme.primary.withOpacity(0.5), colorScheme.secondary.withOpacity(0.5), ], begin: Alignment.centerLeft, end: Alignment.centerRight, ), ), ),
                 ],
              ),
            ),
          ), // Fim Container Interno
        ), // Fim ClipRRect
      ), // Fim Material
    ); // Fim Container Externo (Sombra)
  }
}