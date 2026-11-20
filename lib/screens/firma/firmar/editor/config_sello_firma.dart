import 'package:flutter/material.dart';

/// Configuración centralizada del sello visual de firma y visto bueno.
/// Cambia aquí cualquier texto, tamaño, color o formato del sello,
/// sin tocar `editor_firma_modal.dart`.
class ConfigSelloFirma {
	// ── Tamaños del sello ────────────────────────────────────────────
	static const double anchoFirma = 240;
	static const double altoFirma = 100;
	static const double ladoImagen = 54;
	static const double margen = 5;

	static const double anchoCorrelativo = 50;
	static const double altoCorrelativo = 70;

	// ── Sello de firma: textos ───────────────────────────────────────
	static const String labelFirmadoPor = 'Firmado digitalmente por:';
	static const String labelDni = 'FIR (DNI %s) hard';
	static const String labelFechaHoraFolios = 'F: %s | H: %s | Folios: %s';
	static const String labelMotivo = 'Motivo: %s';

	// ── Sello de firma: placeholders (sin hardware) ──────────────────
	static const String placeholderNombre = '----------------------------------';
	static const String placeholderDni = '-------------';

	// ── Sello de firma: estilos ──────────────────────────────────────
	static const double fuenteNormal = 6.5;
	static const double alturaLineaNormal = 1.0;

	static const Color colorTextoNormal = Colors.black;
	static const Color colorTextoPlaceholder = Colors.red;

	// ── Sello de visto bueno ─────────────────────────────────────────
	static const double ladoSelloVb = 56;
	static const double fuenteDireccionVb = 5;
	static const double fuenteFechaVb = 4.5;
	static const double fuenteMotivoVb = 5;
	static const double alturaLineaVb = 1.1;
	static const String motivoVbFallback = 'Visto\nbueno';

	// ── Formato de fecha ─────────────────────────────────────────────
	/// dd/MM/yyyy
	static String formatearFecha(DateTime fecha) {
		final d = fecha.day.toString().padLeft(2, '0');
		final m = fecha.month.toString().padLeft(2, '0');
		final y = fecha.year.toString();
		return '$d/$m/$y';
	}

	/// HH:mm
	static String formatearHora(DateTime fecha) {
		final h = fecha.hour.toString().padLeft(2, '0');
		final m = fecha.minute.toString().padLeft(2, '0');
		return '$h:$m';
	}

	// ── Helpers para construir textos con formato ───────────────────
	static String textoDni(String dni) => labelDni.replaceFirst('%s', dni);

	static String textoFechaHoraFolios(String fecha, String hora, int folios) =>
			labelFechaHoraFolios
				.replaceFirst('%s', fecha)
				.replaceFirst('%s', hora)
				.replaceFirst('%s', '$folios');

	static String textoMotivo(String motivo) => labelMotivo.replaceFirst('%s', motivo);
}