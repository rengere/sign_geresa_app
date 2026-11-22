import 'package:firmador_geresa/assets/tools/files_manag/file_route.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';

String obtenerRutaNextcloud() {
	String ruta = JsonStorage.getString('ruta_nextcloud') ?? '';
	
	// Si la ruta está vacía, usar la ruta por defecto (folderPath)
	if (ruta.trim().isEmpty) {
		ruta = folderPath;
	} else {
		ruta = ruta.trim();
	}

	// Eliminar la barra final (ya sea \ o /) si existe
	if (ruta.endsWith('\\') || ruta.endsWith('/')) {
		ruta = ruta.substring(0, ruta.length - 1);
	}
	
	return ruta;
}