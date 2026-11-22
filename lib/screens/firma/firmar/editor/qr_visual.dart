import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';

class QrVisual extends StatelessWidget {
	final String url;
	final bool resaltadoRojo;

	const QrVisual({super.key, required this.url, this.resaltadoRojo = false});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(8),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.9),
				border: Border.all(
					color: resaltadoRojo ? Colors.red : context.primaryPurple, 
					width: resaltadoRojo ? 2.0 : 1.0,
				),
				borderRadius: BorderRadius.circular(4),
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					QrImageView(
						data: url,
						version: QrVersions.auto,
						size: 60.0,
					),
					const SizedBox(width: 8),
					Flexible(
						child: Text(
							url,
							style: TextStyle(fontSize: 10, color: context.textDark),
							maxLines: 3,
							overflow: TextOverflow.ellipsis,
						),
					),
				],
			),
		);
	}
}