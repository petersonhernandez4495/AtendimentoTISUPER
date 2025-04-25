// lib/config/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class AppTheme {
  AppTheme._();

  // --- Constantes de Cores (Mantidas) ---
  static const Color kBackgroundGradientStart = Color(0xFF121212);
  static const Color kBackgroundGradientEnd = Colors.black;
  static const Color kSurfaceColor = Color(0xA02A2A3E);
  static const Color kSurfaceVariant = Color(0xAA546E7A); // Usada na AppBar anteriormente
  static const Color kPrimaryColor = Color(0xFF7B1FA2);
  static const Color kSecondaryColor = Color(0xFF9C27B0);
  static const Color kTextColor = Colors.white;
  static const Color kSecondaryTextColor = Colors.white70;
  static const Color kErrorColor = Colors.redAccent;
  static const Color kGradientStartColor = Color(0xFFE91E63);
  static const Color kGradientEndColor = Color(0xFFFF8A65);


  static final ThemeData darkTheme = ThemeData(
    // ... (Restante do ThemeData mantido igual) ...
     brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, primaryColor: kPrimaryColor, fontFamily: GoogleFonts.poppins().fontFamily, colorScheme: const ColorScheme.dark( primary: kPrimaryColor, secondary: kSecondaryColor, surface: kSurfaceColor, background: kBackgroundGradientStart, error: kErrorColor, onPrimary: kTextColor, onSecondary: kTextColor, onSurface: kTextColor, onBackground: kTextColor, onError: kTextColor, surfaceVariant: kSurfaceVariant, onSurfaceVariant: kTextColor, ), textTheme: GoogleFonts.poppinsTextTheme( ThemeData.dark().textTheme,).copyWith( headlineSmall: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold), headlineMedium: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold), titleLarge: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.bold), bodyLarge: const TextStyle(color: kTextColor), bodyMedium: const TextStyle(color: kSecondaryTextColor), labelLarge: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),), cardTheme: CardTheme( elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(16.0), ),), elevatedButtonTheme: ElevatedButtonThemeData( style: ElevatedButton.styleFrom( backgroundColor: kPrimaryColor, foregroundColor: kTextColor, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12.0), ), padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold), ),), appBarTheme: AppBarTheme( backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: kTextColor), titleTextStyle: GoogleFonts.poppins( color: kTextColor, fontSize: 18, fontWeight: FontWeight.w600, ),), inputDecorationTheme: InputDecorationTheme( filled: true, fillColor: kSurfaceColor, contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), border: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none,), enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none, ), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5), ), labelStyle: const TextStyle(color: kSecondaryTextColor), hintStyle: const TextStyle(color: kSecondaryTextColor), ), iconTheme: const IconThemeData( color: kSecondaryTextColor, size: 24.0,),
  );

  // --- FUNÇÃO DE COR DE PRIORIDADE COM CORES VIVAS ---
  static Color? getPriorityColor(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'urgente':
      case 'crítica':
        // return Colors.redAccent[700]; // Anterior
        return Colors.redAccent[400]; // <<< VERMELHO VIVO (Accent 400 é bem brilhante)
      case 'alta':
        // return Colors.orangeAccent[700]; // Anterior
        return Colors.orangeAccent[400]; // <<< LARANJA VIVO
      case 'média':
      case 'media':
        // return Colors.yellowAccent[700]; // Anterior
        return Colors.yellowAccent[400]; // <<< AMARELO VIVO
      case 'baixa':
        // return Colors.cyanAccent[400]; // Anterior
        return Colors.greenAccent[400]; // <<< VERDE VIVO
      default:
        return null; // Sem cor específica / Sem sombra colorida
    }
  }
  // ----------------------------------------------------

  // Função Helper de Cor de Status (Mantida)
  static Color? getStatusColor(String status) { switch (status.toLowerCase()) { case 'aberto': return Colors.blue[400]; case 'em andamento': return Colors.orange[600]; case 'pendente': return Colors.deepPurple[400]; case 'resolvido': return Colors.green[500]; case 'fechado': return Colors.grey[600]; default: return Colors.grey[500]; } }
}