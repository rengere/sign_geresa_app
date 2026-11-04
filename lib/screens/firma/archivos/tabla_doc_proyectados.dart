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

		return BoxVerArchivos(
			rutaCarpeta: rutaFinal,
			tipo: "proyectados"
		);
	}
}