import 'dart:io'; // <-- IMPORTANTE para Platform.pathSeparator
import 'package:firmador_geresa/assets/theme/app_theme.dart'; // <-- IMPORTANTE para context.spaceLg
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';
import 'package:firmador_geresa/screens/firma/archivos/internal/box_ver_archivos.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/tools/files_manag/folder_path_nxc.dart';

class TablaDocProyectados extends StatelessWidget {
	const TablaDocProyectados({super.key});

	@override
	Widget build(BuildContext context) {
		final rutaBase = obtenerRutaNextcloud();
		final rutaFinal = '$rutaBase$proyectados';

		final rutasJson = JsonStorage.getJson('rutas_alternativas');
		List<Map<String, dynamic>> rutasAlternativas = [];
		if (rutasJson != null) {
			rutasAlternativas = List<Map<String, dynamic>>.from(rutasJson);
		}

		final rutasProyectados = rutasAlternativas
				.where((r) => r['proyectados'] == true)
				.map((r) {
					final rutaBaseAlt = r['ruta'] as String;
					final partes = rutaBaseAlt.split(Platform.pathSeparator);
					String nombreCarpeta = partes.last;
					if (nombreCarpeta.startsWith('_')) {
						nombreCarpeta = nombreCarpeta.substring(1);
					}

					return {
						'ruta': '$rutaBaseAlt$proyectados',
						'nombre': nombreCarpeta,
					};
				})
				.toList();

		return Padding(
			padding: EdgeInsets.all(context.spaceLg),
			child: BoxVerArchivos(
				rutaCarpetaPrincipal: rutaFinal,
				tipo: "proyectados",
				rutasAlternativas: rutasProyectados,
			),
		);
	}
}