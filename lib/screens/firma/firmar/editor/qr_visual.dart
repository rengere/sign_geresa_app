import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';

class QrVisual extends StatelessWidget {
	static const double ancho = 150;
	static const double alto = 44.8;
	static const double ladoQr = 36.96;
	static const double margen = 1.6;
	static const double separacion = 2;
	static const double margenInferiorUrl = 3.2;
	static const double fuenteUrl = 8;
	static const double xUrl = margen + ladoQr + separacion;
	static const double anchoUrl = ancho - xUrl - margen;
	final String url;
	final bool resaltadoRojo;
	final bool mostrarBorde;

	const QrVisual({super.key, required this.url, this.resaltadoRojo = false, this.mostrarBorde = true});

	static Widget imagenQr(String url) => QrImageView(data: url, version: QrVersions.auto, size: ladoQr, padding: const EdgeInsets.all(3.2), backgroundColor: Colors.white);

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			width: ancho,
			height: alto,
			child: DecoratedBox(
				decoration: BoxDecoration(
					color: Colors.white,
					border: mostrarBorde ? Border.all(color: resaltadoRojo ? Colors.red : context.primaryPurple, width: 0.7) : null,
				),
				child: Padding(
					padding: const EdgeInsets.all(margen),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.end,
						children: [
							imagenQr(url),
							const SizedBox(width: separacion),
							Expanded(
								child: Padding(
									padding: const EdgeInsets.only(bottom: margenInferiorUrl),
									child: FittedBox(
										alignment: Alignment.bottomLeft,
										fit: BoxFit.scaleDown,
										child: Text(
											url,
											maxLines: 1,
											softWrap: false,
											style: const TextStyle(fontSize: fuenteUrl, height: 1.1, color: Colors.black),
										),
									),
								),
							),
						],
					),
				),
			),
		);
	}
}
