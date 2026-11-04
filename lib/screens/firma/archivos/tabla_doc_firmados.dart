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

		// 3. Se la pasamos como prop al Box
		return BoxVerArchivos(
			rutaCarpeta: rutaFinal,
			tipo: "firmados"
		);
	}
}