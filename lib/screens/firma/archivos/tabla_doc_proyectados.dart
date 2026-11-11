import 'dart:convert';
import 'dart:io'; // <-- IMPORTANTE PARA USAR Platform.pathSeparator
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';
import 'package:firmador_geresa/screens/firma/archivos/internal/box_ver_archivos.dart';
import 'package:firmador_geresa/screens/firma/archivos/internal/ruta_desplegable.dart';
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
				.toList();

		return SingleChildScrollView(
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					// TABLA PRINCIPAL
					SizedBox(
						height: 500,
						child: BoxVerArchivos(
							rutaCarpeta: rutaFinal,
							tipo: "proyectados",
						),
					),

					if (rutasProyectados.isNotEmpty) ...[
						const SizedBox(height: 24),
						Text(
							'Rutas Alternativas (Proyectados)',
							style: TextStyle(
								fontSize: 16,
								fontWeight: FontWeight.bold,
								color: context.textDark,
							),
						),
						const SizedBox(height: 12),
						...rutasProyectados.map((rutaData) {
							final rutaBaseAlt = rutaData['ruta'] as String;
							
							// --- LÓGICA PARA EXTRAER EL NOMBRE ---
							// 1. Dividimos por el separador de rutas de Windows (\)
							final partes = rutaBaseAlt.split(Platform.pathSeparator);
							// 2. Tomamos la última parte (el nombre de la carpeta)
							String nombreCarpeta = partes.last;
							// 3. Si empieza con _, se lo quitamos
							if (nombreCarpeta.startsWith('_')) {
								nombreCarpeta = nombreCarpeta.substring(1);
							}
							
							final rutaCompleta = '$rutaBaseAlt$proyectados';
							
							return RutaDesplegable(
								tituloRuta: nombreCarpeta, // <-- Mostramos solo el nombre
								rutaCompleta: rutaCompleta,
								tipo: 'proyectados',
							);
						}).toList(),
					],
				],
			),
		);
	}
}