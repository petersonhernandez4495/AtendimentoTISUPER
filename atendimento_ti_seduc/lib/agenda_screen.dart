// lib/agenda_screen.dart
import 'package:flutter/material.dart';

// Este é um Widget placeholder simples para a tela de Agenda.
// Ele será exibido quando o item "Agenda" for selecionado no menu principal.
// Substitua o conteúdo do 'build' futuramente pela sua implementação real da agenda
// (ex: calendário, lista de próximas visitas de todos os chamados, etc.).

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Como esta tela é parte do conteúdo exibido pela MainNavigationScreen,
    // ela retorna diretamente o conteúdo, sem Scaffold ou AppBar próprios.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 80, color: Theme.of(context).disabledColor), // Ícone cinza
            const SizedBox(height: 20),
            Text(
              'Agenda',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).disabledColor),
            ),
             const SizedBox(height: 10),
            Text(
              '(Funcionalidade futura: Exibir calendário ou lista de visitas agendadas)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}