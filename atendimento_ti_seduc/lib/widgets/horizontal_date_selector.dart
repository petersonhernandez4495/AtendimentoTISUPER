// lib/widgets/horizontal_date_selector.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme/app_theme.dart';
import 'dart:ui';

typedef DateSelectedCallback = void Function(DateTime? selectedDate);

class HorizontalDateSelector extends StatefulWidget {
  final DateTime? initialSelectedDate;
  final DateSelectedCallback onDateSelected;

  const HorizontalDateSelector({
    super.key,
    this.initialSelectedDate,
    required this.onDateSelected,
  });

  @override
  State<HorizontalDateSelector> createState() => _HorizontalDateSelectorState();
}

class _HorizontalDateSelectorState extends State<HorizontalDateSelector> {
  DateTime? _currentlySelectedDate;
  List<DateTime> _dateCarouselItems = [];
  final ScrollController _scrollController = ScrollController();

  // Constantes para cálculo de layout e rolagem
  static const double _itemWidth = 55.0;
  static const double _itemHorizontalMargin = 4.0;
  static const double _itemSpacing = _itemHorizontalMargin * 2;
  static const double _itemTotalWidth = _itemWidth + _itemSpacing;

  @override
  void initState() {
    super.initState();
    _currentlySelectedDate = widget.initialSelectedDate;
    _generateDateCarouselItems();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  @override
  void didUpdateWidget(covariant HorizontalDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedDate != oldWidget.initialSelectedDate) {
      setState(() {
        _currentlySelectedDate = widget.initialSelectedDate;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
    }
  }


  void _generateDateCarouselItems({int daysAround = 7}) { // Diminuí o range padrão
    _dateCarouselItems = [];
    final centerDate = DateTime.now(); // Baseado sempre em hoje para gerar o range
    for (int i = daysAround; i > 0; i--) {
      _dateCarouselItems.add(centerDate.subtract(Duration(days: i)));
    }
    _dateCarouselItems.add(centerDate);
    for (int i = 1; i <= daysAround; i++) {
      _dateCarouselItems.add(centerDate.add(Duration(days: i)));
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  void _scrollToSelectedDate() {
     if (!_scrollController.hasClients || !context.mounted || context.findRenderObject() == null) return;
     int targetIndex = -1;
     DateTime targetDate = _currentlySelectedDate ?? DateTime.now();
     for (int i = 0; i < _dateCarouselItems.length; i++) {
        if (_isSameDay(_dateCarouselItems[i], targetDate)) {
          targetIndex = i;
          break;
        }
     }
     if (targetIndex != -1) {
        final double viewportWidth = MediaQuery.of(context).size.width; // Usa MediaQuery
        double targetOffset = (targetIndex * _itemTotalWidth) + (_itemWidth / 2) - (viewportWidth / 2);
        targetOffset = targetOffset.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent
        );
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
     }
  }

  Widget _buildDateItem(BuildContext context, DateTime date) {
    final bool isSelected = _currentlySelectedDate != null && _isSameDay(date, _currentlySelectedDate!);
    final bool isToday = _isSameDay(date, DateTime.now());
    final String dayNumber = DateFormat('d', 'pt_BR').format(date);
    final String dayAbbreviation = DateFormat('E', 'pt_BR').format(date).toUpperCase();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        DateTime? newSelectedDate = isSelected ? null : date;
        setState(() { _currentlySelectedDate = newSelectedDate; });
        widget.onDateSelected(newSelectedDate);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
      },
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: _itemWidth,
        margin: EdgeInsets.symmetric(horizontal: _itemHorizontalMargin),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : (isToday ? colorScheme.surfaceVariant : colorScheme.surface.withOpacity(0.8)),
          borderRadius: BorderRadius.circular(8.0),
          border: isSelected ? Border.all(color: colorScheme.primary, width: 1.5) : (isToday ? Border.all(color: colorScheme.outline.withOpacity(0.5), width: 1.0) : null),
        ),
        child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Text( dayNumber, style: theme.textTheme.titleMedium?.copyWith( fontWeight: FontWeight.bold, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface, ), ), const SizedBox(height: 2), Text( dayAbbreviation, style: theme.textTheme.bodySmall?.copyWith( color: isSelected ? colorScheme.onPrimary.withOpacity(0.8) : colorScheme.onSurface.withOpacity(0.7), ), ), ], ),
      ),
    );
 }


  @override
  Widget build(BuildContext context) {
     if (_dateCarouselItems.isEmpty) { _generateDateCarouselItems(); }

     // --- CÁLCULO DO PADDING DINÂMICO ---
     final double screenWidth = MediaQuery.of(context).size.width;
     // Largura total necessária para todos os itens (+ padding inicial/final extra de 10)
     final double totalContentWidth = (_dateCarouselItems.length * _itemTotalWidth) + 20;
     // Calcula o padding horizontal necessário para centralizar, se o conteúdo for menor que a tela
     double horizontalPadding = (screenWidth - totalContentWidth) / 2;
     // Garante que o padding não seja negativo e tenha um mínimo (ex: 8.0)
     horizontalPadding = horizontalPadding.clamp(8.0, double.infinity);
     // ------------------------------------

    return Container(
      height: 75, // Altura fixa do carrossel
      // Opcional: cor de fundo para a área do carrossel
      // color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        // --- APLICA O PADDING CALCULADO ---
        // Usa o padding dinâmico ou um mínimo de 8.0
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        // ---------------------------------
        itemCount: _dateCarouselItems.length,
        itemBuilder: (context, index) {
          final date = _dateCarouselItems[index];
          // Não precisa mais do padding extra aqui dentro do itemBuilder
          return _buildDateItem(context, date);
        },
      ),
    );
  }

   @override
   void dispose() {
     _scrollController.dispose();
     super.dispose();
   }
}