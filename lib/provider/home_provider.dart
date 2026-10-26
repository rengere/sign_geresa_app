import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';

class HomeVisibilityNotifier extends Notifier<Map<String, bool>> {
	
	@override
	Map<String, bool> build() {
		final data = JsonStorage.getJson('home_visibility') as Map<String, dynamic>?;
		if (data != null) {
			return data.map((key, value) => MapEntry(key, value == 1));
		}
		return {};
	}

	// Función para cambiar el estado de una tarjeta
	Future<void> toggleVisibilidad(String nombreTarjeta, bool visible) async {
		state = {...state, nombreTarjeta: visible};
		
		final dataAGuardar = state.map((key, value) => MapEntry(key, value ? 1 : 0));
		await JsonStorage.setJson('home_visibility', dataAGuardar);
	}

	bool esVisible(String nombreTarjeta) {
		return state[nombreTarjeta] ?? true;
	}
}

final homeVisibilityProvider = NotifierProvider<HomeVisibilityNotifier, Map<String, bool>>(HomeVisibilityNotifier.new);