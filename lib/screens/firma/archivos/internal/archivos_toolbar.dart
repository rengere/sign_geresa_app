import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ArchivosToolbar extends StatelessWidget {
	final TextEditingController controller;
	final ValueChanged<String> onCambioTexto;
	final VoidCallback onLimpiarTexto;
	final DateTimeRange? rango;
	final VoidCallback onElegirRango;
	final VoidCallback onLimpiarRango;
	final VoidCallback onRefrescar;
	final int total;
	final int encontrados;

	const ArchivosToolbar({
		super.key,
		required this.controller,
		required this.onCambioTexto,
		required this.onLimpiarTexto,
		required this.rango,
		required this.onElegirRango,
		required this.onLimpiarRango,
		required this.onRefrescar,
		required this.total,
		required this.encontrados,
	});

	String _fecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

	String get _contador {
		final palabra = total == 1 ? 'archivo' : 'archivos';
		if (encontrados == total) return '$total $palabra';
		return '$encontrados de $total $palabra';
	}

	@override
	Widget build(BuildContext context) {
		final r = rango;

		return Row(
			children: [
				Flexible(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 420),
						child: TextField(
							controller: controller,
							onChanged: onCambioTexto,
							decoration: InputDecoration(
								hintText: 'Buscar por nombre de archivo',
								prefixIcon: const Icon(Icons.search_rounded),
								suffixIcon: controller.text.isEmpty
										? null
										: IconButton(
												tooltip: 'Limpiar',
												onPressed: onLimpiarTexto,
												icon: const Icon(Icons.close_rounded, size: 18),
											),
							),
						),
					),
				),
				SizedBox(width: context.spaceMd),
				if (r == null)
					OutlinedButton.icon(
						onPressed: onElegirRango,
						icon: const Icon(Icons.calendar_month_outlined, size: 18),
						label: const Text('Filtrar por fecha'),
					)
				else ...[
					ElevatedButton.icon(
						onPressed: onElegirRango,
						icon: const Icon(Icons.calendar_month_outlined, size: 18),
						label: Text('${_fecha(r.start)} – ${_fecha(r.end)}'),
					),
					IconButton(
						tooltip: 'Quitar filtro de fecha',
						onPressed: onLimpiarRango,
						icon: const Icon(Icons.close_rounded, size: 18),
					),
				],
				const Spacer(),
				Text(_contador, style: Theme.of(context).textTheme.titleSmall),
				SizedBox(width: context.spaceSm),
				IconButton(
					tooltip: 'Actualizar',
					onPressed: onRefrescar,
					icon: const Icon(Icons.refresh_rounded),
				),
			],
		);
	}
}