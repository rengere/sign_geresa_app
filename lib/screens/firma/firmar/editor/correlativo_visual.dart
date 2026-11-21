import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CorrelativoVisual extends StatelessWidget {
	final String texto;
	final double fuente;
	final double ancho;
	final double alto;

	const CorrelativoVisual({super.key, required this.texto, required this.fuente, required this.ancho, required this.alto});

	@override
	Widget build(BuildContext context) {
		return Container(
			width: ancho, height: alto,
			decoration: BoxDecoration(
				// Fondo blanco con 30% de opacidad (70% transparente)
				color: Colors.white.withValues(alpha: 0.3), 
				// Borde morado con 30% de opacidad
				border: Border.all(color: context.primaryPurple.withValues(alpha: 0.3), width: 1.5), 
				borderRadius: BorderRadius.circular(4),
			),
			child: Stack(
				alignment: Alignment.center,
				children: [
					Positioned(top: 2, right: 2, child: Icon(Icons.drag_indicator, size: 14, color: context.textGrey.withValues(alpha: 0.5))),
					Center(child: Text(texto, style: TextStyle(fontSize: fuente, fontWeight: FontWeight.bold, color: Colors.black, height: 1.0))),
				],
			),
		);
	}
}