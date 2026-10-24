import 'package:flutter/material.dart';

// ==========================================
// EXTENSIONES PARA ACCEDER FÁCILMENTE
// ==========================================
extension AppColorsX on BuildContext {
	Color get primaryPurple => AppTheme.primaryPurple;
	Color get primaryPurpleLight => AppTheme.primaryPurpleLight;
	Color get backgroundLight => AppTheme.backgroundLight;
	Color get surfaceWhite => AppTheme.surfaceWhite;
	Color get surfaceGrey => AppTheme.surfaceGrey;
	
	Color get textDark => AppTheme.textDark;
	Color get textGrey => AppTheme.textGrey;
	Color get textLight => AppTheme.textLight;
	
	Color get accentOrange => AppTheme.accentOrange;
	Color get accentCoral => AppTheme.accentCoral;
	Color get errorRed => AppTheme.errorRed;
	
	Color get borderColor => AppTheme.borderColor;
	Color get dividerColor => AppTheme.dividerColor;
}

extension AppDimensionsX on BuildContext {
	double get radiusSm => AppTheme.radiusSm;
	double get radiusMd => AppTheme.radiusMd;
	double get radiusLg => AppTheme.radiusLg;
	double get radiusXl => AppTheme.radiusXl;
	double get radiusPill => AppTheme.radiusPill;
	
	double get spaceSm => AppTheme.spaceSm;
	double get spaceMd => AppTheme.spaceMd;
	double get spaceLg => AppTheme.spaceLg;
}

class AppTheme {
	// ==========================================
	// 1. PALETA DE COLORES
	// ==========================================
	static const Color primaryPurple = Color(0xFF7B61FF); 
	static const Color primaryPurpleLight = Color(0xFFA78BFA);

	static const Color backgroundLight = Color(0xFFF8F9FA); 
	static const Color surfaceWhite = Color(0xFFFFFFFF); 
	static const Color surfaceGrey = Color(0xFFF3F4F6); 

	static const Color textDark = Color(0xFF1E1E2D); 
	static const Color textGrey = Color(0xFF828282); 
	static const Color textLight = Color(0xFFBDBDBD); 

	static const Color accentOrange = Color(0xFFFF8A65);
	static const Color accentCoral = Color(0xFFE57373);
	static const Color errorRed = Color(0xFFEF5350);

	static const Color borderColor = Color(0xFFEAEAEA);
	static const Color dividerColor = Color(0xFFF0F0F0);

	// ==========================================
	// 2. DIMENSIONES
	// ==========================================
	static const double radiusSm = 8.0;
	static const double radiusMd = 16.0; 
	static const double radiusLg = 24.0;
	static const double radiusXl = 32.0;
	static const double radiusPill = 100.0; // Para botones tipo píldora

	static const double spaceSm = 8.0;
	static const double spaceMd = 16.0;
	static const double spaceLg = 24.0;

	// ==========================================
	// 3. SOMBRAS
	// ==========================================
	static const List<BoxShadow> shadowSm = [
		BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
	];
	static const List<BoxShadow> shadowMd = [
		BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 8)),
	];

	// ==========================================
	// 4. THEME DATA
	// ==========================================
	static ThemeData get lightTheme {
		return ThemeData(
			useMaterial3: true,
			brightness: Brightness.light,

			primaryColor: primaryPurple,
			scaffoldBackgroundColor: backgroundLight,
			canvasColor: backgroundLight,

			colorScheme: const ColorScheme.light(
				primary: primaryPurple,
				onPrimary: Colors.white,
				secondary: primaryPurpleLight,
				onSecondary: Colors.white,
				surface: surfaceWhite,
				onSurface: textDark,
				surfaceContainerHighest: surfaceGrey,
				error: errorRed,
				onError: Colors.white,
				outline: borderColor,
			),

			textTheme: const TextTheme(
				displayLarge: TextStyle(color: textDark, fontSize: 48, fontWeight: FontWeight.w800),
				headlineLarge: TextStyle(color: textDark, fontSize: 32, fontWeight: FontWeight.w700),
				headlineMedium: TextStyle(color: textDark, fontSize: 24, fontWeight: FontWeight.w700),
				titleLarge: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w700),
				titleMedium: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w600),
				titleSmall: TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.w600),
				bodyLarge: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w500),
				bodyMedium: TextStyle(color: textGrey, fontSize: 14),
				bodySmall: TextStyle(color: textLight, fontSize: 12),
				labelLarge: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
			),

			// ==========================================
			// BOTONES
			// ==========================================
			// Botón sólido (ej. botones de acción, "bedroom" activo)
			elevatedButtonTheme: ElevatedButtonThemeData(
				style: ElevatedButton.styleFrom(
					backgroundColor: primaryPurple,
					foregroundColor: Colors.white,
					elevation: 0,
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
					textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
				),
			),

			// Botón outline (ej. "living room" inactivo)
			outlinedButtonTheme: OutlinedButtonThemeData(
				style: OutlinedButton.styleFrom(
					foregroundColor: textGrey,
					side: BorderSide.none, // En la imagen no tienen borde, solo fondo
					backgroundColor: surfaceGrey,
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
					textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
				),
			),

			// Botón de texto (para menús, opciones sutiles)
			textButtonTheme: TextButtonThemeData(
				style: TextButton.styleFrom(
					foregroundColor: primaryPurple,
					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
					textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
				),
			),

			// Botones de icono (Sidebar, Header icons como el de la campana o mail)
			iconButtonTheme: IconButtonThemeData(
				style: IconButton.styleFrom(
					foregroundColor: textGrey,
					highlightColor: primaryPurple.withOpacity(0.1),
					padding: const EdgeInsets.all(12),
					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
				),
			),

			// ==========================================
			// INPUTS (Barra de búsqueda)
			// ==========================================
			inputDecorationTheme: InputDecorationTheme(
				filled: true,
				fillColor: surfaceGrey,
				contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
				hintStyle: const TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.w500),
				prefixIconColor: textGrey,
				border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(radiusXl),
					borderSide: BorderSide.none,
				),
				enabledBorder: OutlineInputBorder(
					borderRadius: BorderRadius.circular(radiusXl),
					borderSide: BorderSide.none,
				),
				focusedBorder: OutlineInputBorder(
					borderRadius: BorderRadius.circular(radiusXl),
					borderSide: const BorderSide(color: primaryPurple, width: 1.5),
				),
			),

			// ==========================================
			// SWITCHES & SLIDERS
			// ==========================================
			switchTheme: SwitchThemeData(
				thumbColor: WidgetStateProperty.resolveWith((states) {
					if (states.contains(WidgetState.selected)) return primaryPurple;
					return Colors.white;
				}),
				trackColor: WidgetStateProperty.resolveWith((states) {
					if (states.contains(WidgetState.selected)) return primaryPurple.withOpacity(0.2);
					return surfaceGrey;
				}),
				trackOutlineColor: WidgetStateProperty.resolveWith((states) {
					if (states.contains(WidgetState.selected)) return Colors.transparent;
					return borderColor;
				}),
			),

			sliderTheme: SliderThemeData(
				activeTrackColor: primaryPurple,
				inactiveTrackColor: surfaceGrey,
				thumbColor: primaryPurple,
				overlayColor: primaryPurple.withOpacity(0.1),
				trackHeight: 6,
				thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
			),

			// ==========================================
			// CHIPS (Para etiquetas de habitaciones o tags)
			// ==========================================
			chipTheme: ChipThemeData(
				backgroundColor: surfaceGrey,
				selectedColor: primaryPurple,
				disabledColor: surfaceGrey,
				labelStyle: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w600),
				secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
				padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
				side: BorderSide.none,
			),

			// ==========================================
			// AVATARES (Para la sección de Members)
			// ==========================================
			// Nota: Flutter no tiene un "AvatarTheme" directo, 
			// pero configuramos el CircleAvatar por defecto.
			// Aquí lo dejamos listo para que uses CircleAvatar con estos colores.

			// ==========================================
			// CARDS Y CONTENEDORES
			// ==========================================
			cardTheme: CardThemeData(
				color: surfaceWhite,
				surfaceTintColor: Colors.transparent,
				elevation: 0,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(radiusMd),
				),
				margin: EdgeInsets.zero,
			),

			// ==========================================
			// OTROS
			// ==========================================
			dividerTheme: const DividerThemeData(
				color: dividerColor,
				thickness: 1,
			),

			tooltipTheme: TooltipThemeData(
				decoration: BoxDecoration(
					color: textDark,
					borderRadius: BorderRadius.circular(radiusSm),
				),
				textStyle: const TextStyle(color: Colors.white, fontSize: 12),
			),
		);
	}
}