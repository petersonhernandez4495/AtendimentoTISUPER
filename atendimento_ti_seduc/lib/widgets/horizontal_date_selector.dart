// lib/widgets/horizontal_date_selector.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Removido import não utilizado: import '../config/theme/app_theme.dart';
// Removido import não utilizado: import 'dart:ui'; // Já importado por material.dart

// Callback para notificar a seleção de data
typedef DateSelectedCallback = void Function(DateTime? selectedDate);

class HorizontalDateSelector extends StatefulWidget {
  final DateTime? initialSelectedDate; // Data inicial opcionalmente selecionada
  final DateSelectedCallback onDateSelected; // Função chamada ao selecionar/desselecionar

  const HorizontalDateSelector({
    super.key,
    this.initialSelectedDate,
    required this.onDateSelected,
  });

  @override
  State<HorizontalDateSelector> createState() => _HorizontalDateSelectorState();
}

class _HorizontalDateSelectorState extends State<HorizontalDateSelector> {
  DateTime? _currentlySelectedDate; // Armazena a data atualmente selecionada
  List<DateTime> _dateCarouselItems = []; // Lista de datas exibidas no carrossel
  final ScrollController _scrollController = ScrollController(); // Controlador de scroll

  // Constantes para cálculo de layout e scroll
  static const double _itemWidth = 55.0; // Largura de cada item
  static const double _itemHorizontalMargin = 4.0; // Margem horizontal de cada item
  static const double _itemSpacing = _itemHorizontalMargin * 2; // Espaçamento total (margem dos dois lados)
  static const double _itemTotalWidth = _itemWidth + _itemSpacing; // Largura total ocupada por um item

  @override
  void initState() {
    super.initState();
    _currentlySelectedDate = widget.initialSelectedDate; // Define a data inicial
    _generateDateCarouselItems(); // Gera a lista de datas a serem exibidas
    // Após o primeiro frame, rola para a data selecionada (se houver)
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  // Atualiza a data selecionada se o widget pai fornecer uma nova data inicial
  @override
  void didUpdateWidget(covariant HorizontalDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedDate != oldWidget.initialSelectedDate) {
      setState(() { _currentlySelectedDate = widget.initialSelectedDate; });
      // Rola para a nova data selecionada após a atualização do estado
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
    }
  }

  // Gera a lista de datas, centralizada em hoje, com 'daysAround' dias para cada lado
  void _generateDateCarouselItems({int daysAround = 7}) {
    _dateCarouselItems = [];
    final centerDate = DateTime.now();
    // Adiciona dias anteriores
    for (int i = daysAround; i > 0; i--) {
      _dateCarouselItems.add(centerDate.subtract(Duration(days: i)));
    }
    // Adiciona o dia atual
    _dateCarouselItems.add(centerDate);
    // Adiciona dias posteriores
    for (int i = 1; i <= daysAround; i++) {
      _dateCarouselItems.add(centerDate.add(Duration(days: i)));
    }
  }

  // Verifica se duas datas representam o mesmo dia (ignora a hora)
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  // Rola a lista horizontal para centralizar a data selecionada (ou hoje)
  void _scrollToSelectedDate() {
    // Garante que o scroll controller e o contexto estão prontos
    if (!_scrollController.hasClients || !context.mounted || context.findRenderObject() == null) return;

    int targetIndex = -1;
    // Usa a data selecionada ou hoje como alvo
    DateTime targetDate = _currentlySelectedDate ?? DateTime.now();

    // Encontra o índice da data alvo na lista
    for (int i = 0; i < _dateCarouselItems.length; i++) {
      if (_isSameDay(_dateCarouselItems[i], targetDate)) {
        targetIndex = i;
        break;
      }
    }

    // Se encontrou o índice, calcula e anima o scroll
    if (targetIndex != -1) {
      final double viewportWidth = MediaQuery.of(context).size.width;
      // Calcula o offset para centralizar o item alvo
      double targetOffset = (targetIndex * _itemTotalWidth) + (_itemTotalWidth / 2) - (viewportWidth / 2);

      // Garante que o offset esteja dentro dos limites do scroll
      targetOffset = targetOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent
      );

      // Anima o scroll até o offset calculado
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // Constrói a aparência de um único item de data no carrossel
  Widget _buildDateItem(BuildContext context, DateTime date) {
    // Determina os estados do item (selecionado, hoje)
    final bool isSelected = _currentlySelectedDate != null && _isSameDay(date, _currentlySelectedDate!);
    final bool isToday = _isSameDay(date, DateTime.now());

    // Formata os textos do dia e abreviação
    final String dayNumber = DateFormat('d', 'pt_BR').format(date);
    final String dayAbbreviation = DateFormat('E', 'pt_BR').format(date).toUpperCase();

    // Obtém o tema e esquema de cores atual
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define a decoração do item com base nos estados
    Decoration? itemDecoration;
    if (isSelected) {
      // Selecionado: Cor primária com borda
      itemDecoration = BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colorScheme.primary, width: 1.5),
      );
    } else if (isToday) {
      // Hoje (não selecionado): Cor variante da superfície com borda sutil
      itemDecoration = BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colorScheme.outline.withOpacity(0.5), width: 1.0),
      );
    } else {
      // Padrão (nem selecionado, nem hoje): Gradiente cinza escuro
      itemDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[850]!.withOpacity(0.5),
            Colors.black.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8.0),
      );
    }

    // Define as cores do texto com base na seleção
    final Color textColor = isSelected ? colorScheme.onPrimary : colorScheme.onSurface;
    final Color secondaryTextColor = isSelected ? colorScheme.onPrimary.withOpacity(0.8) : colorScheme.onSurface.withOpacity(0.7);

    // --- INÍCIO DA CORREÇÃO ---
    // Envolve o InkWell com um widget Material transparente.
    // Isso fornece o contexto necessário para o InkWell desenhar seus efeitos (splash).
    return Material(
      color: Colors.transparent, // O fundo visual já é tratado pela decoração do Container interno
      child: InkWell(
        onTap: () {
          // Alterna a seleção: se já estava selecionado, deseleciona (null), senão seleciona a data clicada
          DateTime? newSelectedDate = isSelected ? null : date;
          // Atualiza o estado interno para refletir a nova seleção
          setState(() { _currentlySelectedDate = newSelectedDate; });
          // Notifica o widget pai sobre a mudança na seleção
          widget.onDateSelected(newSelectedDate);
          // Rola para a data recém-selecionada (ou para hoje se deselecionado)
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
        },
        // Aplica o mesmo borderRadius ao InkWell para que o efeito de toque siga as bordas
        borderRadius: BorderRadius.circular(8.0),
        // O Container interno contém o conteúdo visual e a decoração
        child: Container(
          width: _itemWidth,
          margin: EdgeInsets.symmetric(horizontal: _itemHorizontalMargin),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: itemDecoration, // Aplica a decoração calculada acima
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayNumber,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor, // Cor dinâmica do texto principal
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dayAbbreviation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor, // Cor dinâmica do texto secundário
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // --- FIM DA CORREÇÃO ---
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
      // Garante que a lista de itens seja gerada se estiver vazia
      if (_dateCarouselItems.isEmpty) { _generateDateCarouselItems(); }

      // Calcula o padding horizontal para tentar centralizar o conteúdo quando possível
      final double screenWidth = MediaQuery.of(context).size.width;
      final double totalContentWidth = (_dateCarouselItems.length * _itemTotalWidth); // Largura total de todos os itens
      // Calcula o padding necessário para centralizar, limitado a um mínimo de 8.0
      double horizontalPadding = (screenWidth - totalContentWidth) / 2;
      horizontalPadding = horizontalPadding.clamp(8.0, double.infinity);

    // Container principal que define a altura do seletor
    return Container(
      height: 75,
      // ListView horizontal para exibir os itens de data
      child: ListView.builder(
        controller: _scrollController, // Usa o controlador de scroll
        scrollDirection: Axis.horizontal, // Define a direção do scroll
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding), // Aplica o padding calculado
        itemCount: _dateCarouselItems.length, // Número de itens na lista
        itemBuilder: (context, index) {
          // Para cada índice, obtém a data correspondente e constrói o widget do item
          final date = _dateCarouselItems[index];
          return _buildDateItem(context, date); // Chama a função atualizada para construir o item
        },
      ),
    );
  }

  // Libera o controlador de scroll quando o widget é descartado
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}