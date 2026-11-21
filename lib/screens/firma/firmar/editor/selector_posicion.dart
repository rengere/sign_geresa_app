import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/editor_firma_modal.dart';
import 'package:flutter/material.dart';

class SelectorPosicion extends StatelessWidget {
	final PosicionFirma posicionAuto;
	final ValueChanged<PosicionFirma> onElegir;

	const SelectorPosicion({super.key, required this.posicionAuto, required this.onElegir});

	Widget _opcion(BuildContext context, PosicionFirma p, String tooltip) {
		final seleccionado = posicionAuto == p;
		return Tooltip(
			message: tooltip,
			child: InkWell(
				customBorder: const CircleBorder(),
				onTap: () => onElegir(p),
				child: Padding(
					padding: const EdgeInsets.all(6),
					child: Icon(seleccionado ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 22, color: seleccionado ? context.primaryPurple : context.textGrey),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			margin: const EdgeInsets.only(top: 16),
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(color: context.surfaceGrey, borderRadius: BorderRadius.circular(context.radiusMd), border: Border.all(color: context.borderColor)),
			child: Column(
				children: [
					Text('Posición en la página', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textGrey)),
					const SizedBox(height: 8),
					Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
						_opcion(context, PosicionFirma.arribaIzquierda, 'Arriba izquierda'),
						_opcion(context, PosicionFirma.arribaCentro, 'Arriba centro'),
						_opcion(context, PosicionFirma.arribaDerecha, 'Arriba derecha'),
					]),
					Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
						_opcion(context, PosicionFirma.abajoIzquierda, 'Abajo izquierda'),
						_opcion(context, PosicionFirma.abajoCentro, 'Abajo centro'),
						_opcion(context, PosicionFirma.abajoDerecha, 'Abajo derecha'),
					]),
				],
			),
		);
	}
}