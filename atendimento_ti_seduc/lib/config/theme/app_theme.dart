// lib/config/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._(); 

  static const Color kWinBackground = Color(0xFFD3D3D3); 
  static const Color kWinSurface = Color(0xFFFFFFFF);   
  static const Color kWinPrimaryText = Color(0xFF201F1E); 
  static const Color kWinSecondaryText = Color(0xFF555555); 
  static const Color kWinAccent = Color(0xFF0078D4);     
  static const Color kWinError = Color(0xFFD32F2F);      
  static const Color kWinInputBorder = Color(0xFFACACAC); 
  static const Color kWinInputFillOpaque = Color(0xFFFFFFFF); 
  static const Color kWinDivider = Color(0xFFD1D1D1);    
  static const Color kWinLighterAccent = Color(0xFF5094E0); 

  // Nova cor para o status "Finalizado"
  static const Color kWinStatusFinalizadoBackground = Color(0xFF616161); // Cinza Escuro (Material Grey 700)

  static const Color kBackgroundGradientStart = kWinBackground;
  static const Color kBackgroundGradientEnd = kWinBackground;
  static const Color kSurfaceColor = kWinSurface; 
  static const Color kSurfaceVariant = Color(0xFFE0E0E0); 
  static const Color kPrimaryColor = kWinAccent;        
  static const Color kSecondaryColor = kWinLighterAccent;  
  static const Color kTextColor = kWinPrimaryText;      
  static const Color kSecondaryTextColor = kWinSecondaryText; 
  static const Color kErrorColor = kWinError;           
  static const Color kInputFillColor = kWinInputFillOpaque;
  static const Color kGradientStartColor = kWinAccent; 
  static const Color kGradientEndColor = kWinLighterAccent; 

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: kWinBackground,
    primaryColor: kPrimaryColor, 
    fontFamily: GoogleFonts.openSans().fontFamily,
    colorScheme: ColorScheme.light( 
      primary: kPrimaryColor,       
      secondary: kSecondaryColor,   
      surface: kSurfaceColor,       
      background: kWinBackground,
      error: kErrorColor,           
      onPrimary: Colors.white,      
      onSecondary: Colors.white,    
      onSurface: kTextColor,        
      onBackground: kTextColor,     
      onError: Colors.white,        
      surfaceVariant: kSurfaceVariant,
      onSurfaceVariant: kTextColor,
    ),
    textTheme: GoogleFonts.openSansTextTheme(
      ThemeData.light().textTheme,
    ).copyWith(
      headlineSmall: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 22),
      headlineMedium: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 26),
      titleLarge: TextStyle(color: kTextColor.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 20),
      bodyLarge: TextStyle(color: kTextColor, fontSize: 14),
      bodyMedium: TextStyle(color: kSecondaryTextColor, fontSize: 14),
      labelLarge: TextStyle(color: kTextColor, fontWeight: FontWeight.normal, fontSize: 14),
    ),
    cardTheme: CardTheme(
      elevation: 1.0,
      color: kSurfaceColor, 
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: const BorderSide(color: kWinDivider, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor, 
        foregroundColor: Colors.white, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        textStyle: GoogleFonts.openSans(fontWeight: FontWeight.normal, fontSize: 14),
        elevation: 2,
      ),
    ),
     outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryColor, 
        side: BorderSide(color: kPrimaryColor.withOpacity(0.7), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        textStyle: GoogleFonts.openSans(fontWeight: FontWeight.normal, fontSize: 14),
      )
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryColor, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
        ),
        textStyle: GoogleFonts.openSans(fontWeight: FontWeight.normal, fontSize: 14),
      )
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kWinBackground,
      elevation: 0, 
      iconTheme: IconThemeData(color: kTextColor), 
      titleTextStyle: GoogleFonts.openSans(
        color: kTextColor, 
        fontSize: 18,
        fontWeight: FontWeight.normal, 
      ),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kInputFillColor, 
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      border: OutlineInputBorder( 
        borderRadius: BorderRadius.circular(4.0),
        borderSide: const BorderSide(color: kWinInputBorder),
      ),
      enabledBorder: OutlineInputBorder( 
        borderRadius: BorderRadius.circular(4.0),
        borderSide: const BorderSide(color: kWinInputBorder),
      ),
      focusedBorder: OutlineInputBorder( 
        borderRadius: BorderRadius.circular(4.0),
        borderSide: BorderSide(color: kPrimaryColor, width: 1.5), 
      ),
      labelStyle: TextStyle(color: kSecondaryTextColor), 
      hintStyle: TextStyle(color: kSecondaryTextColor.withOpacity(0.8)),
      errorStyle: TextStyle(color: kErrorColor), 
    ),
    iconTheme: IconThemeData( 
      color: kSecondaryTextColor, 
      size: 22.0,
    ),
    dividerTheme: const DividerThemeData( 
      color: kWinDivider,
      thickness: 1,
    ),
    canvasColor: kSurfaceColor, 
    chipTheme: ChipThemeData( 
      backgroundColor: const Color(0xFFE0E0E0),
      labelStyle: TextStyle(color: kTextColor.withOpacity(0.8), fontSize: 12), 
      secondaryLabelStyle: TextStyle(color: kSecondaryTextColor, fontSize: 12), 
      selectedColor: kPrimaryColor, 
      disabledColor: Colors.grey.shade300,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      iconTheme: IconThemeData(color: kSecondaryTextColor, size: 16), 
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kPrimaryColor, 
      foregroundColor: Colors.white,
      elevation: 2,
    )
  );

  static Color? getPriorityColor(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'urgente':
      case 'crítica':
        return Colors.red.shade600;
      case 'alta':
        return Colors.orange.shade700;
      case 'média':
      case 'media':
        return Colors.amber.shade700; 
      case 'baixa':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600; 
    }
  }

  static Color? getStatusColor(String status) { 
    switch (status.toLowerCase()) {
      case 'aberto':
        return Colors.blue.shade600; 
      case 'em andamento': 
      case 'em análise':   
        return Colors.orange.shade700;
      case 'pendente':
        return Colors.deepPurple.shade400; 
      case 'solucionado': // Mantido para o fluxo do requerente
        return Colors.green.shade600;
      case 'resolvido': // Pode ser um alias de Solucionado ou um passo intermediário
        return Colors.green.shade600; 
      case 'finalizado': // NOVO STATUS PARA ADMIN
        return kWinStatusFinalizadoBackground; // Cinza Escuro
      case 'fechado':
        return Colors.grey.shade700; // Um cinza um pouco diferente de finalizado
      case 'cancelado':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade500;
    }
  }
}