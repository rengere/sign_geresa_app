import 'dart:io';
import 'package:firmador_geresa/assets/theme/app_theme.dart'; // <-- AÑADIDO
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';
import 'package:firmador_geresa/screens/firma/archivos/internal/box_ver_archivos.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';

class TablaDocFirmados extends StatelessWidget {
	const TablaDocFirmados({super.key});

	@override
	Widget build(BuildContext context) {
		final rutaBase = obtenerRutaNextcloud();
		final rutaFinal = '$rutaBase$firmados';

		final rutasJson = JsonStorage.getJson('rutas_alternativas');
		List<Map<String, dynamic>> rutasAlternativas = [];
		if (rutasJson != null) {
			rutasAlternativas = List<Map<String, dynamic>>.from(rutasJson);
		}

		final rutasFirmados = rutasAlternativas
				.where((r) => r['firmados'] == true)
				.map((r) {
					final rutaBaseAlt = r['ruta'] as String;
					final partes = rutaBaseAlt.split(Platform.pathSeparator);
					String nombreCarpeta = partes.last;
					if (nombreCarpeta.startsWith('_')) {
						nombreCarpeta = nombreCarpeta.substring(1);
					}

					return {
						'ruta': '$rutaBaseAlt$firmados',
						'nombre': nombreCarpeta,
					};
				})
				.toList();

		return Padding(
			padding: EdgeInsets.all(context.spaceLg),
			child: BoxVerArchivos(
				rutaCarpetaPrincipal: rutaFinal,
				tipo: "firmados",
				rutasAlternativas: rutasFirmados,
			),
		);
	}
}