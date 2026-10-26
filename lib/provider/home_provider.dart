import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firmador_geresa/assets/tools/files_manag/json_storage.dart';

// 1. Cambiamos StateNotifier por Notifier
class HomeVisibilityNotifier extends Notifier<Map<String, bool>> {
	
	// 2. En Riverpod 3, el estado inicial se define en el método build()
	@override
	Map<String, bool> build() {
		// Cargamos el estado del JSON. Si una tarjeta no existe, por defecto es TRUE (visible)
		final data = JsonStorage.getJson('home_visibility') as Map<String, dynamic>?;
		if (data != null) {
			return data.map((key, value) => MapEntry(key, value == 1));
		}
		return {};
	}

	// Función para cambiar el estado de una tarjeta
	Future<void> toggleVisibilidad(String nombreTarjeta, bool visible) async {
		// 3. Aquí actualizamos el estado (esto actualiza la UI inmediatamente)
		state = {...state, nombreTarjeta: visible};
		
		// 4. Guardamos en el JSON (1 para true, 0 para false)
		final dataAGuardar = state.map((key, value) => MapEntry(key, value ? 1 : 0));
		await JsonStorage.setJson('home_visibility', dataAGuardar);
	}

	// Helper para saber si una tarjeta debe mostrarse
	bool esVisible(String nombreTarjeta) {
		return state[nombreTarjeta] ?? true;
	}
}

// 5. Usamos NotifierProvider en lugar de StateNotifierProvider
final homeVisibilityProvider = NotifierProvider<HomeVisibilityNotifier, Map<String, bool>>(HomeVisibilityNotifier.new);