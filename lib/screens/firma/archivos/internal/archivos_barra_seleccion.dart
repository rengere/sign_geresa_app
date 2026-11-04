import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ArchivosBarraSeleccion extends StatelessWidget {
	final int cantidad;
	final int totalFiltrados;
	final VoidCallback onSeleccionarTodos;
	final VoidCallback onCancelar;
	final VoidCallback onDescargar;
	final VoidCallback onCompartir;
	final VoidCallback onEliminar;
	final VoidCallback onSuprimir;

	const ArchivosBarraSeleccion({
		super.key,
		required this.cantidad,
		required this.totalFiltrados,
		required this.onSeleccionarTodos,
		required this.onCancelar,
		required this.onDescargar,
		required this.onCompartir,
		required this.onEliminar,
		required this.onSuprimir,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			decoration: BoxDecoration(
				color: context.primaryPurple,
				borderRadius: BorderRadius.circular(context.radiusMd),
			),
			child: Row(
				children: [
					IconButton(
						tooltip: 'Cancelar selección',
						onPressed: onCancelar,
						style: IconButton.styleFrom(foregroundColor: Colors.white),
						icon: const Icon(Icons.close_rounded),
					),
					Text(
						cantidad == 1 ? '1 seleccionado' : '$cantidad seleccionados',
						style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
					),
					if (cantidad < totalFiltrados) ...[
						const SizedBox(width: 8),
						_Boton(icono: Icons.select_all_rounded, texto: 'Seleccionar los $totalFiltrados', onTap: onSeleccionarTodos),
					],
					const Spacer(),
					_Boton(icono: Icons.download_outlined, texto: 'Descargar', onTap: onDescargar),
					_Boton(icono: Icons.share_outlined, texto: 'Compartir', onTap: onCompartir),
					_Boton(icono: Icons.delete_outline_rounded, texto: 'Eliminar', onTap: onEliminar),
					_Boton(icono: Icons.delete_forever_outlined, texto: 'Suprimir', onTap: onSuprimir),
				],
			),
		);
	}
}

class _Boton extends StatelessWidget {
	final IconData icono;
	final String texto;
	final VoidCallback onTap;

	const _Boton({required this.icono, required this.texto, required this.onTap});

	@override
	Widget build(BuildContext context) {
		return TextButton.icon(
			onPressed: onTap,
			style: TextButton.styleFrom(foregroundColor: Colors.white),
			icon: Icon(icono, size: 18),
			label: Text(texto),
		);
	}
}