// lib/widgets/ticket_card.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Importar FirebaseAuth para User
import '../config/theme/app_theme.dart';
import '../services/chamado_service.dart'; // <-- Importar para kFieldAdminInativo
import '/detalhes_chamado_screen.dart'; // <-- Importar tela de detalhes para navegação

class TicketCard extends StatelessWidget {
  // Campos de exibição existentes (recebidos do StreamBuilder/Query)
  final String titulo;
  final String prioridade;
  final String status;
  final String creatorName;
  final String dataFormatada;
  final String chamadoId;
  final String? creatorPhone;
  final String? tecnicoResponsavel;
  final String cidade; // Mantido, usado no fallback ou tipo ESCOLA
  final String instituicao; // Mantido, usado no fallback ou tipo ESCOLA
  final String? tipoSolicitante;
  final String? setorSuperintendencia;
  final String? cidadeSuperintendencia;

  // <<< NOVOS CAMPOS NECESSÁRIOS >>>
  final Map<String, dynamic> chamadoData; // Dados completos do documento
  final User? currentUser; // Usuário logado para verificar permissão
  final bool isAdmin; // Flag indicando se o usuário é admin

  // Callbacks (inalterados)
  // ATENÇÃO: O onTap interno agora controla a lógica de acesso.
  // O VoidCallback? onTap passado externamente pode não ser mais necessário
  // ou precisa ser usado com cuidado. Vamos removê-lo por enquanto para evitar confusão.
  // final VoidCallback? onTap;
  final VoidCallback? onDelete; // Manter se houver exclusão para admin

  const TicketCard({
    super.key,
    // Campos existentes
    required this.titulo,
    required this.prioridade,
    required this.status,
    required this.creatorName,
    required this.dataFormatada,
    required this.chamadoId,
    required this.cidade, // Manter ou tornar opcional 'String?'
    required this.instituicao, // Manter ou tornar opcional 'String?'
    this.creatorPhone,
    this.tecnicoResponsavel,
    // this.onTap, // Removido temporariamente
    this.onDelete,
    this.tipoSolicitante,
    this.setorSuperintendencia,
    this.cidadeSuperintendencia,

    // <<< NOVOS PARÂMETROS OBRIGATÓRIOS >>>
    required this.chamadoData,
    required this.currentUser,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // Obtém tema e cores
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color textoSecundarioCor = colorScheme.onSurfaceVariant;
    final Color? corStatus = AppTheme.getStatusColor(status);
    final Color corPrioridade = AppTheme.getPriorityColor(prioridade) ?? colorScheme.primary;
    final BorderRadius borderRadius = BorderRadius.circular(12.0);

    // <<< VERIFICA ESTADO DE INATIVIDADE >>>
    final bool isInativo = chamadoData[kFieldAdminInativo] ?? false;

    // Define quais informações de localidade mostrar baseado no tipo
    // (Lógica existente mantida)
     String? localPrincipalLabel; // Ex: Instituição ou Setor
     String? localPrincipalValue;
     IconData? localPrincipalIcon;
     String? localSecundarioLabel; // Ex: Cidade
     String? localSecundarioValue;
     IconData? localSecundarioIcon;

     if (tipoSolicitante == 'ESCOLA') {
       localPrincipalIcon = Icons.business_outlined;
       localPrincipalValue = instituicao;
       localSecundarioIcon = Icons.location_city_outlined;
       localSecundarioValue = cidade;
     } else if (tipoSolicitante == 'SUPERINTENDENCIA') {
       localPrincipalIcon = Icons.meeting_room_outlined; // Ícone para Setor
       localPrincipalValue = setorSuperintendencia;
       localSecundarioIcon = Icons.location_city_rounded; // Ícone para Cidade SUPER
       localSecundarioValue = cidadeSuperintendencia;
     } else {
       // Fallback
       localPrincipalIcon = Icons.business_outlined;
       localPrincipalValue = instituicao;
       localSecundarioIcon = Icons.location_city_outlined;
       localSecundarioValue = cidade;
     }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 1.5,
      child: InkWell(
        // <<< LÓGICA DE ACESSO NO onTap >>>
        onTap: () {
          if (isAdmin) {
            // Admin sempre pode acessar os detalhes
             print("Admin acessando detalhes de $chamadoId (Inativo: $isInativo)");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetalhesChamadoScreen( // Certifique-se que o nome da tela está correto
                  chamadoId: chamadoId,
                  // Opcional: Passar dados já carregados para evitar nova leitura inicial
                  // chamadoData: chamadoData,
                ),
              ),
            );
          } else {
            // É Requisitante (ou outro não-admin)
            if (isInativo) {
              // Chamado está inativo, bloquear acesso
              print("Requisitante bloqueado de acessar detalhes de $chamadoId (Inativo)");
              ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove snackbar anterior se houver
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Este chamado está inativo e não pode ser acessado.'),
                  backgroundColor: Colors.orange.shade800,
                  duration: const Duration(seconds: 3),
                ),
              );
              // NÃO NAVEGAR
            } else {
              // Chamado está ativo, permitir acesso
              print("Requisitante acessando detalhes de $chamadoId (Ativo)");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetalhesChamadoScreen(
                    chamadoId: chamadoId,
                    // chamadoData: chamadoData, // Opcional
                 ),
                ),
              );
            }
          }
        }, // Fim onTap
        borderRadius: borderRadius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra Lateral de Prioridade
            Container(
              width: 10.0,
              color: corPrioridade,
            ),

            // Conteúdo Principal do Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 15, right: 10, top: 15.0, bottom: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start, // Alinha ao topo
                  children: [
                    // PARTE SUPERIOR: Título, TAG INATIVO e Excluir
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding( // Ícone de Prioridade/Problema
                            padding: const EdgeInsets.only(top: 3.0),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: corPrioridade.withOpacity(0.1),
                              child: Icon(Icons.report_problem_outlined, size: 15, color: corPrioridade),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded( // Título
                            child: Text(
                              titulo,
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // <<< TAG INATIVO (Visível para todos) >>>
                          if (isInativo)
                             Padding(
                               padding: const EdgeInsets.only(left: 8.0), // Espaço antes da tag
                               child: Chip(
                                 label: const Text('INATIVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                 backgroundColor: Colors.red.shade700,
                                 padding: EdgeInsets.zero,
                                 labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                 visualDensity: VisualDensity.compact,
                                 materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                 side: BorderSide.none,
                               ),
                             ),
                           // Botão Excluir (se aplicável)
                          if (onDelete != null)
                             InkWell(
                               onTap: onDelete,
                               borderRadius: BorderRadius.circular(20),
                               child: Padding(
                                 padding: const EdgeInsets.all(4.0),
                                 child: Icon(Icons.close_rounded, color: AppTheme.kErrorColor.withOpacity(0.7), size: 18),
                               ),
                             ),
                          ],
                        ),
                    const SizedBox(height: 14.0),

                    // PARTE DO MEIO: Prioridade e Status (inalterado)
                     Row(
                       children: [
                         Expanded(
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(Icons.label_important_outline, size: 13, color: textoSecundarioCor),
                               const SizedBox(width: 4),
                               //Text('Prioridade:', style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor)),
                               const SizedBox(width: 4),
                               Flexible(
                                 child: Text(
                                   prioridade,
                                   style: textTheme.bodySmall?.copyWith(color: corPrioridade, fontWeight: FontWeight.bold),
                                   overflow: TextOverflow.ellipsis,
                                   maxLines: 1,
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(width: 8),
                         Chip(
                           label: Text(status.toUpperCase()),
                           labelStyle: textTheme.labelSmall?.copyWith(
                             color: corStatus != null && corStatus.computeLuminance() > 0.5
                               ? Colors.black.withOpacity(0.7)
                               : Colors.white.withOpacity(0.9),
                             fontWeight: FontWeight.w600,
                             letterSpacing: 0.5,
                           ),
                           backgroundColor: corStatus?.withOpacity(0.9),
                           padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                           visualDensity: VisualDensity.compact,
                           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                           side: BorderSide.none,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                         ),
                       ],
                     ),

                    const SizedBox(height: 15.0),
                    Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)),
                    const SizedBox(height: 12.0),

                    // INFORMAÇÕES INFERIORES (COM LÓGICA CONDICIONAL - inalterado)
                    // Linha 1: Criador e Data
                     Row(
                       crossAxisAlignment: CrossAxisAlignment.center,
                       children: [
                         Expanded(
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
                         const SizedBox(width: 10),
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
                    const SizedBox(height: 6.0),

                    // Linha 2: Instituição OU Setor (CONDICIONAL)
                    if (localPrincipalValue != null && localPrincipalValue.isNotEmpty && localPrincipalIcon != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(localPrincipalIcon, size: 13, color: textoSecundarioCor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localPrincipalValue,
                                style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Linha 3: Cidade (ESCOLA ou SUPER - CONDICIONAL)
                    if (localSecundarioValue != null && localSecundarioValue.isNotEmpty && localSecundarioIcon != null)
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           Icon(localSecundarioIcon, size: 13, color: textoSecundarioCor),
                           const SizedBox(width: 6),
                           Expanded(
                             child: Text(
                               localSecundarioValue,
                               style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),


                    // Linha 4 & 5: Telefone e Técnico (Opcional - Coluna - inalterado)
                    if ((creatorPhone != null && creatorPhone!.isNotEmpty) || (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (creatorPhone != null && creatorPhone!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty) ? 4.0 : 0,
                                ),
                                child: Row(
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
                              ),
                            if (tecnicoResponsavel != null && tecnicoResponsavel!.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.engineering_outlined, size: 13, color: textoSecundarioCor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Téc: $tecnicoResponsavel',
                                      style: textTheme.bodySmall?.copyWith(color: textoSecundarioCor, fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
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