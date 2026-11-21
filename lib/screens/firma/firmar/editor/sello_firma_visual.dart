import 'dart:typed_data';

import 'package:firmador_geresa/screens/firma/firmar/editor/config_sello_firma.dart';
import 'package:flutter/material.dart';

class SelloFirmaVisual extends StatelessWidget {
	final bool esModoVistoBueno;
	final bool hardwareDisponible;
	final String nombreFirmante;
	final String dniFirmante;
	final String cargoSeleccionado;
	final String motivoSeleccionado;
	final String direccionOficina;
	final int totalPaginas;
	final Uint8List imagenFirmaBytes;
	final Uint8List imagenVistoBuenoBytes;
	final double anchoFirma;
	final double altoFirma;
	final double ladoImagen;

	const SelloFirmaVisual({
		super.key,
		required this.esModoVistoBueno,
		required this.hardwareDisponible,
		required this.nombreFirmante,
		required this.dniFirmante,
		required this.cargoSeleccionado,
		required this.motivoSeleccionado,
		required this.direccionOficina,
		required this.totalPaginas,
		required this.imagenFirmaBytes,
		required this.imagenVistoBuenoBytes,
		required this.anchoFirma,
		required this.altoFirma,
		required this.ladoImagen,
	});

	String _motivoVbParaSello() {
		final motivo = motivoSeleccionado.trim();
		if (motivo.isEmpty) return ConfigSelloFirma.motivoVbFallback;
		final palabras = motivo.split(RegExp(r'\s+'));
		if (palabras.length == 2) return '${palabras[0]}\n${palabras[1]}';
		return motivo;
	}

	@override
	Widget build(BuildContext context) {
		final ahora = DateTime.now();
		final fechaStr = ConfigSelloFirma.formatearFecha(ahora);
		final horaStr = ConfigSelloFirma.formatearHora(ahora);

		final colorTexto = hardwareDisponible ? ConfigSelloFirma.colorTextoNormal : ConfigSelloFirma.colorTextoPlaceholder;
		final nombreMostrar = hardwareDisponible ? nombreFirmante : ConfigSelloFirma.placeholderNombre;
		final dniMostrar = hardwareDisponible ? dniFirmante : ConfigSelloFirma.placeholderDni;

		final estiloNormal = TextStyle(fontSize: ConfigSelloFirma.fuenteNormal, color: colorTexto, height: ConfigSelloFirma.alturaLineaNormal);

		Image _imagenFirma({double? size}) {
			final bytes = esModoVistoBueno ? imagenVistoBuenoBytes : imagenFirmaBytes;
			return Image.memory(bytes, width: size ?? ladoImagen, height: size ?? ladoImagen, fit: BoxFit.contain, filterQuality: FilterQuality.high);
		}

		if (esModoVistoBueno) {
			const double ladoSello = ConfigSelloFirma.ladoSelloVb;
			return SizedBox(
				width: anchoFirma, height: altoFirma,
				child: Align(
					alignment: Alignment.centerLeft,
					child: Container(
						width: ladoSello, height: ladoSello,
						decoration: const BoxDecoration(shape: BoxShape.circle),
						child: Stack(
							alignment: Alignment.center,
							children: [
								Positioned.fill(child: _imagenFirma()),
								Padding(
									padding: const EdgeInsets.symmetric(horizontal: 8),
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											if (direccionOficina.isNotEmpty) ...[
												Text(direccionOficina.toUpperCase(), style: const TextStyle(fontSize: ConfigSelloFirma.fuenteDireccionVb, color: Colors.black, fontWeight: FontWeight.bold, height: 1.0), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
												const SizedBox(height: 1),
											],
											Text(fechaStr, style: const TextStyle(fontSize: ConfigSelloFirma.fuenteFechaVb, color: Colors.black, height: 1.0), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
											const SizedBox(height: 2),
											Text(_motivoVbParaSello(), style: const TextStyle(fontSize: ConfigSelloFirma.fuenteMotivoVb, color: Colors.black, fontWeight: FontWeight.bold, height: ConfigSelloFirma.alturaLineaVb), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
										],
									),
								),
							],
						),
					),
				),
			);
		}

		return SizedBox(
			width: anchoFirma, height: altoFirma,
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.center,
				children: [
					SizedBox(width: ladoImagen, height: ladoImagen, child: _imagenFirma()),
					const SizedBox(width: 8),
					Expanded(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(ConfigSelloFirma.labelFirmadoPor, style: estiloNormal),
								Text(nombreMostrar, style: estiloNormal),
								if (cargoSeleccionado.isNotEmpty) Text(cargoSeleccionado, style: estiloNormal),
								Text(ConfigSelloFirma.textoDni(dniMostrar), style: estiloNormal),
								Text(ConfigSelloFirma.textoFechaHoraFolios(fechaStr, horaStr, totalPaginas), style: estiloNormal),
								Text(ConfigSelloFirma.textoMotivo(motivoSeleccionado), style: estiloNormal),
							],
						),
					),
				],
			),
		);
	}
}