import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_card/flutter_smart_card.dart';

/// Servicio de detección de DNIe/lector mediante polling cada 2 segundos.
/// No lee el certificado; solo verifica si hay lector + tarjeta disponibles.
/// Se pausa mientras se está firmando para no competir con Java por el lector.
class DetectorDnieService {
	final FlutterSmartCard _smartCard = FlutterSmartCard();
	final Duration _intervalo;

	Timer? _timer;
	bool _activo = false;
	bool _pausado = false;

	bool? _ultimoEstado;

	void Function(bool disponible)? onCambioHardware;

	DetectorDnieService({Duration intervalo = const Duration(seconds: 2)})
			: _intervalo = intervalo;

	void iniciar() {
		if (_activo) return;
		_activo = true;
		_pausado = false;
		_verificarAhora();
		_timer = Timer.periodic(_intervalo, (_) {
			if (!_pausado) _verificarAhora();
		});
	}

	void detener() {
		_activo = false;
		_pausado = false;
		_timer?.cancel();
		_timer = null;
	}

	void pausar() {
		_pausado = true;
	}

	void reanudar() {
		if (!_activo) return;
		_pausado = false;
		_verificarAhora();
	}

	Future<void> _verificarAhora() async {
		if (!_activo || _pausado) return;

		bool disponible = false;
		try {
			final lectores = await _smartCard.listReaders();
			debugPrint('[Detector] Lectores encontrados: $lectores');

			if (lectores.isNotEmpty) {
				final conectado = await _smartCard.connect(lectores.first);
				debugPrint('[Detector] connect() devolvió: $conectado');
				disponible = conectado;
				try {
					await _smartCard.disconnect();
				} catch (_) {
					// Ignorar errores al desconectar.
				}
			}
		} catch (e) {
			debugPrint('[Detector] Error: $e');
			disponible = false;
		}

		if (_ultimoEstado != disponible) {
			_ultimoEstado = disponible;
			onCambioHardware?.call(disponible);
		}
	}
}