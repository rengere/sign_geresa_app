
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio de detección del DNIe mediante la API Java.
///
/// Consulta periódicamente el endpoint /lector/titular.
/// No utiliza flutter_smart_card para detectar el lector.
///
/// Permite pausar el polling durante la firma digital para
/// evitar conflictos de acceso al DNIe.
class DetectorDnieService {
	static const String _baseUrl = 'http://127.0.0.1:8426';

	final Duration _intervalo;

	Timer? _timer;

	bool _activo = false;
	bool _pausado = false;
	bool _verificando = false;

	bool? _ultimoEstado;

	int _generacion = 0;

	void Function(bool disponible)? onCambioHardware;

	DetectorDnieService({
		Duration intervalo = const Duration(seconds: 2),
	}) : _intervalo = intervalo;

	/// Inicia la detección periódica del DNIe.
	void iniciar() {
		if (_activo) return;

		_activo = true;
		_pausado = false;
		_ultimoEstado = null;

		_generacion++;

		debugPrint('[Detector] Iniciando detección mediante Java');

		_verificarAhora();

		_timer = Timer.periodic(_intervalo, (_) {
			_verificarAhora();
		});
	}

	/// Detiene completamente el polling.
	void detener() {
		_activo = false;
		_pausado = false;

		_generacion++;

		_timer?.cancel();
		_timer = null;

		debugPrint('[Detector] Detección detenida');
	}

	/// Pausa temporalmente la detección.
	///
	/// Se utiliza cuando comienza una operación de firma.
	void pausar() {
		if (!_activo) return;

		_pausado = true;
		_generacion++;

		debugPrint('[Detector] Detección pausada');
	}

	/// Reanuda la detección y ejecuta una comprobación.
	void reanudar() {
		if (!_activo) return;

		_pausado = false;
		_generacion++;

		debugPrint('[Detector] Detección reanudada');

		_verificarAhora();
	}

	/// Comprueba si Java puede acceder al certificado del DNIe.
	Future<void> _verificarAhora() async {
		if (!_activo || _pausado || _verificando) {
			return;
		}

		_verificando = true;

		final generacionActual = _generacion;

		bool disponible = false;

		try {
			final uri = Uri.parse('$_baseUrl/lector/titular');

			final respuesta = await http.get(uri).timeout(
				const Duration(seconds: 5),
			);

			if (respuesta.statusCode == 200) {
				final datos = jsonDecode(respuesta.body);

				if (datos is Map &&
					datos['sujeto'] != null &&
					datos['sujeto'].toString().trim().isNotEmpty) {
					disponible = true;

					debugPrint(
						'[Detector] DNIe detectado correctamente',
					);
				} else {
					debugPrint(
						'[Detector] No se encontró certificado de firma',
					);
				}
			} else {
				debugPrint(
					'[Detector] DNIe no disponible. HTTP ${respuesta.statusCode}',
				);

				try {
					final error = jsonDecode(respuesta.body);

					if (error is Map && error['detail'] != null) {
						debugPrint(
							'[Detector] Detalle: ${error['detail']}',
						);
					}
				} catch (_) {
					// La respuesta no contiene un error JSON válido.
				}
			}
		} on TimeoutException {
			debugPrint(
				'[Detector] Tiempo de espera agotado consultando Java',
			);
		} catch (e) {
			debugPrint(
				'[Detector] Error de detección: $e',
			);
		} finally {
			_verificando = false;
		}

		// Ignorar respuestas antiguas si el detector fue
		// pausado, detenido o reiniciado durante la consulta.
		if (!_activo ||
			_pausado ||
			generacionActual != _generacion) {
			return;
		}

		// Notificar únicamente cuando cambia la disponibilidad.
		if (_ultimoEstado != disponible) {
			_ultimoEstado = disponible;

			debugPrint(
				'[Detector] Estado del DNIe: '
				'${disponible ? "CONECTADO" : "DESCONECTADO"}',
			);

			onCambioHardware?.call(disponible);
		}
	}
}
