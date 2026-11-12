import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'box_ver_archivos.dart';

class RutaDesplegable extends StatelessWidget {
	final String tituloRuta;
	final String rutaCompleta;
	final String tipo;

	const RutaDesplegable({
		super.key,
		required this.tituloRuta,
		required this.rutaCompleta,
		required this.tipo,
	});

	@override
	Widget build(BuildContext context) {
		return Card(
			margin: const EdgeInsets.only(bottom: 16),
			elevation: 0,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(context.radiusMd),
				side: BorderSide(color: context.borderColor),
			),
			clipBehavior: Clip.antiAlias,
			child: ExpansionTile(
				initiallyExpanded: true,
				title: Text(
					tituloRuta,
					style: TextStyle(
						fontSize: 14,
						fontWeight: FontWeight.w600,
						color: context.textDark,
					),
				),
				iconColor: context.primaryPurple,
				collapsedIconColor: context.textGrey,
				backgroundColor: context.surfaceWhite,
				collapsedBackgroundColor: context.surfaceGrey,
				children: [
					SizedBox(
						height: 400,
						child: Padding(
							padding: const EdgeInsets.all(16.0),
							child: BoxVerArchivos(
								rutaCarpetaPrincipal: rutaCompleta, // <-- CORREGIDO AQUÍ
								tipo: tipo,
							),
						),
					),
				],
			),
		);
	}
}