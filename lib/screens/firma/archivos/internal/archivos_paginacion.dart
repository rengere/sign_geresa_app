import 'dart:math';

import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ArchivosPaginacion extends StatelessWidget {
	/// Página actual (base 0)
	final int pagina;
	final int totalPaginas;
	final int totalArchivos;
	final int porPagina;
	final ValueChanged<int> onCambiar;

	const ArchivosPaginacion({
		super.key,
		required this.pagina,
		required this.totalPaginas,
		required this.totalArchivos,
		required this.porPagina,
		required this.onCambiar,
	});

	@override
	Widget build(BuildContext context) {
		final desde = pagina * porPagina + 1;
		final hasta = min((pagina + 1) * porPagina, totalArchivos);

		final inicioVentana = (pagina - 2).clamp(0, max(0, totalPaginas - 5)).toInt();
		final finVentana = min(totalPaginas, inicioVentana + 5);

		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
			decoration: BoxDecoration(
				border: Border(top: BorderSide(color: context.dividerColor)),
			),
			child: Row(
				children: [
					Text('Mostrando $desde–$hasta de $totalArchivos', style: Theme.of(context).textTheme.bodyMedium),
					const Spacer(),
					IconButton(
						tooltip: 'Anterior',
						onPressed: pagina > 0 ? () => onCambiar(pagina - 1) : null,
						icon: const Icon(Icons.chevron_left_rounded),
					),
					for (var i = inicioVentana; i < finVentana; i++)
						_BotonPagina(numero: i + 1, activo: i == pagina, onTap: () => onCambiar(i)),
					IconButton(
						tooltip: 'Siguiente',
						onPressed: pagina < totalPaginas - 1 ? () => onCambiar(pagina + 1) : null,
						icon: const Icon(Icons.chevron_right_rounded),
					),
				],
			),
		);
	}
}

class _BotonPagina extends StatelessWidget {
	final int numero;
	final bool activo;
	final VoidCallback onTap;

	const _BotonPagina({required this.numero, required this.activo, required this.onTap});

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 2),
			child: Material(
				color: activo ? context.primaryPurple : Colors.transparent,
				borderRadius: BorderRadius.circular(context.radiusPill),
				child: InkWell(
					borderRadius: BorderRadius.circular(context.radiusPill),
					onTap: onTap,
					child: SizedBox(
						width: 36,
						height: 36,
						child: Center(
							child: Text(
								'$numero',
								style: TextStyle(
									fontSize: 13,
									fontWeight: FontWeight.w600,
									color: activo ? Colors.white : context.textGrey,
								),
							),
						),
					),
				),
			),
		);
	}
}