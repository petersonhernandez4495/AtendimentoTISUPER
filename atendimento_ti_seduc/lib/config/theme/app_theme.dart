// lib/config/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class AppTheme {
  AppTheme._();

  // --- Constantes de Cores ---
  static const Color kBackgroundGradientStart = Color(0xFF121212);
  static const Color kBackgroundGradientEnd = Colors.black;
  static const Color kSurfaceColor = Color(0xA02A2A3E); // Cor original com opacidade (mantida para outros usos)
  static const Color kSurfaceVariant = Color(0xAA546E7A);
  static const Color kPrimaryColor = Color(0xFF7B1FA2);
  static const Color kSecondaryColor = Color(0xFF9C27B0);
  static const Color kTextColor = Colors.white;
  static const Color kSecondaryTextColor = Colors.white70;
  static const Color kErrorColor = Colors.redAccent;
  static const Color kGradientStartColor = Color(0xFFE91E63);
  static const Color kGradientEndColor = Color(0xFFFF8A65);

  // --- NOVA COR OPACA PARA INPUTS ---
  static const Color kInputFillColor = Color(0xFF2A2A3E); // Cor base de kSurfaceColor, mas com alfa FF (opaco)


  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent, // Mantido transparente para o gradiente do background funcionar
    primaryColor: kPrimaryColor,
    fontFamily: GoogleFonts.poppins().fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: kPrimaryColor,
      secondary: kSecondaryColor,
      surface: kSurfaceColor, // Mantém kSurfaceColor para superfícies gerais (Cards, Dialogs, etc.)
      background: kBackgroundGradientStart,
      error: kErrorColor,
      onPrimary: kTextColor,
      onSecondary: kTextColor,
      onSurface: kTextColor,
      onBackground: kTextColor,
      onError: kTextColor,
      surfaceVariant: kSurfaceVariant,
      onSurfaceVariant: kTextColor,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
        headlineSmall: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(color: kTextColor),
        bodyMedium: const TextStyle(color: kSecondaryTextColor),
        labelLarge: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      // Se quiser que os cards usem a cor opaca também, mude aqui:
      // color: kInputFillColor, // Exemplo: Deixa cards opacos também
      // Se quiser que usem a cor com opacidade original:
      // color: kSurfaceColor, // Default pelo colorScheme.surface
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: kTextColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent, // Mantém transparente para gradiente
      elevation: 0,
      iconTheme: const IconThemeData(color: kTextColor),
      titleTextStyle: GoogleFonts.poppins(
        color: kTextColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kInputFillColor, // <-- **MODIFICAÇÃO PRINCIPAL AQUI**
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: kSecondaryTextColor),
      hintStyle: const TextStyle(color: kSecondaryTextColor),
    ),
    iconTheme: const IconThemeData(
      color: kSecondaryTextColor,
      size: 24.0,
    ),
     // Adapta a cor do dropdown para o tema escuro
    canvasColor: const Color(0xFF2A2A3E), // Cor de fundo para o menu dropdown (pode ajustar)
  );

  // Função de Cor de Prioridade (Inalterada)
  static Color? getPriorityColor(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'urgente':
      case 'crítica':
        return Colors.redAccent[400];
      case 'alta':
        return Colors.orangeAccent[400];
      case 'média':
      case 'media':
        return Colors.yellowAccent[400];
      case 'baixa':
        return Colors.greenAccent[400];
      default:
        return null;
    }
  }

  // Função Helper de Cor de Status (Inalterada)
  static Color? getStatusColor(String status) { switch (status.toLowerCase()) { case 'aberto': return Colors.blue[400]; case 'em andamento': return Colors.orange[600]; case 'pendente': return Colors.deepPurple[400]; case 'resolvido': return Colors.green[500]; case 'fechado': return Colors.grey[600]; default: return Colors.grey[500]; } }
}