import 'dart:convert';
import 'dart:io'; // <-- IMPORTANTE PARA USAR Platform.pathSeparator
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';
import 'package:firmador_geresa/data/rutas_carpetas_docs.dart';
import 'package:firmador_geresa/screens/firma/archivos/internal/box_ver_archivos.dart';
import 'package:firmador_geresa/screens/firma/archivos/internal/ruta_desplegable.dart';
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
							tipo: "firmados",
						),
					),

					if (rutasFirmados.isNotEmpty) ...[
						const SizedBox(height: 24),
						Text(
							'Rutas Alternativas (Firmados)',
							style: TextStyle(
								fontSize: 16,
								fontWeight: FontWeight.bold,
								color: context.textDark,
							),
						),
						const SizedBox(height: 12),
						...rutasFirmados.map((rutaData) {
							final rutaBaseAlt = rutaData['ruta'] as String;
							
							// --- LÓGICA PARA EXTRAER EL NOMBRE ---
							final partes = rutaBaseAlt.split(Platform.pathSeparator);
							String nombreCarpeta = partes.last;
							if (nombreCarpeta.startsWith('_')) {
								nombreCarpeta = nombreCarpeta.substring(1);
							}
							
							final rutaCompleta = '$rutaBaseAlt$firmados';
							
							return RutaDesplegable(
								tituloRuta: nombreCarpeta, // <-- Mostramos solo el nombre
								rutaCompleta: rutaCompleta,
								tipo: 'firmados',
							);
						}).toList(),
					],
				],
			),
		);
	}
}