import 'package:firmador_geresa/assets/tools/files_manag/file_route.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';

String obtenerRutaNextcloud() {
	final ruta = JsonStorage.getString('ruta_nextcloud');
	return (ruta == null || ruta.trim().isEmpty) 
			? folderPath 
			: ruta.trim();
}