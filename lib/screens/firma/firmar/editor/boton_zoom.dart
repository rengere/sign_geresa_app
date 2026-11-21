import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BotonZoom extends StatelessWidget {
	final IconData icono;
	final String tooltip;
	final VoidCallback onTap;

	const BotonZoom({super.key, required this.icono, required this.tooltip, required this.onTap});

	@override
	Widget build(BuildContext context) {
		return Material(
			color: context.surfaceWhite,
			elevation: 2,
			borderRadius: BorderRadius.circular(context.radiusMd),
			child: IconButton(icon: Icon(icono, size: 20), tooltip: tooltip, color: context.textDark, onPressed: onTap),
		);
	}
}