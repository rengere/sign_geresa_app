// lib/widgets/action_card.dart
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ActionCard extends StatefulWidget {
	/// Título principal de la tarjeta.
	final String titulo;

	/// Texto descriptivo debajo del título.
	final String descripcion;

	/// Icono o cualquier Widget que se muestre en el recuadro superior.
	final Widget icono;

	/// Color de fondo del recuadro del icono.
	final Color iconBackgroundColor;

	/// Ancho fijo de la tarjeta. Por defecto 320 (diseño original).
	final double width;

	/// Callback al tocar la tarjeta. Opcional.
	final VoidCallback? onTap;

	const ActionCard({
		super.key,
		required this.titulo,
		required this.descripcion,
		required this.icono,
		required this.iconBackgroundColor,
		this.width = 320,
		this.onTap,
	});

	@override
	State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
	// Variable para saber si el mouse está encima
	bool _isHovered = false;

	@override
	Widget build(BuildContext context) {
		// Definimos los colores dependiendo de si el mouse está encima
		final colorBorde = _isHovered ? context.primaryPurple : context.borderColor;
		final colorFondo = _isHovered 
				? context.primaryPurple.withValues(alpha: 0.05) // Fondo morado muy sutil
				: context.surfaceWhite;

		return MouseRegion(
			cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
			onEnter: (_) => setState(() => _isHovered = true),
			onExit: (_) => setState(() => _isHovered = false),
			child: GestureDetector(
				onTap: widget.onTap,
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 200),
					width: widget.width,
					padding: const EdgeInsets.all(32),
					decoration: BoxDecoration(
						color: colorFondo,
						borderRadius: BorderRadius.circular(context.radiusLg),
						border: Border.all(
							color: colorBorde, 
							width: _isHovered ? 1.5 : 1.0 // Borde ligeramente más grueso en hover
						),
						boxShadow: _isHovered
								? [
										BoxShadow(
											color: context.primaryPurple.withValues(alpha: 0.1),
											blurRadius: 10,
											offset: const Offset(0, 4),
										)
									]
								: [],
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							// Recuadro del icono
							Container(
								width: 80,
								height: 80,
								decoration: BoxDecoration(
									color: widget.iconBackgroundColor,
									borderRadius: BorderRadius.circular(20),
								),
								child: Center(child: widget.icono),
							),
							const SizedBox(height: 24),
							Text(
								widget.titulo,
								textAlign: TextAlign.center,
								style: TextStyle(
									color: context.textDark,
									fontSize: 18,
									fontWeight: FontWeight.w600,
								),
							),
							const SizedBox(height: 8),
							Text(
								widget.descripcion,
								textAlign: TextAlign.center,
								style: TextStyle(
									color: context.textGrey,
									fontSize: 14,
									height: 1.4,
								),
							),
						],
					),
				),
			),
		);
	}
}