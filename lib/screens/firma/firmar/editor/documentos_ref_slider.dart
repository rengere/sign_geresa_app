import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/screens/firma/firmar/editor/documento_referencial.dart' show DocumentoReferencial;

class DocumentosSidebar extends StatelessWidget {
	final VoidCallback? onCerrar;
	final String nombreArchivo;
	final List<DocumentoReferencial> referenciales;
	final ValueChanged<String> onEliminar;
	final void Function(int oldIndex, int newIndex) onReorder;

	const DocumentosSidebar({
		super.key,
		required this.nombreArchivo,
		required this.referenciales,
		required this.onEliminar,
		required this.onReorder,
		this.onCerrar,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			width: 220,
			decoration: BoxDecoration(color: context.surfaceGrey.withValues(alpha: 0.5), border: Border(right: BorderSide(color: context.borderColor))),
			child: Column(
				children: [
					Container(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Text('Documentos referenciales', style: TextStyle(fontWeight: FontWeight.bold, color: context.textDark))), IconButton(tooltip: 'Cerrar panel', onPressed: onCerrar, icon: const Icon(Icons.close))])),
					Container(
						margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
						padding: const EdgeInsets.all(8),
						decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.primaryPurple)),
						child: Row(
							children: [
								Icon(Icons.lock_outline, size: 20, color: context.primaryPurple),
								const SizedBox(width: 8),
								Expanded(child: Text(nombreArchivo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
							],
						),
					),
					Expanded(
						child: ReorderableListView.builder(
							buildDefaultDragHandles: false,
							itemCount: referenciales.length,
							onReorder: onReorder,
							itemBuilder: (context, index) {
								final doc = referenciales[index];
								return Container(
									key: ValueKey(doc.id),
									margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
									padding: const EdgeInsets.all(8),
									decoration: BoxDecoration(color: context.surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.borderColor)),
									child: Row(
										children: [
											ReorderableDragStartListener(index: index, child: Icon(Icons.drag_indicator, size: 20, color: context.textGrey)),
											const SizedBox(width: 8),
											Expanded(child: Text(doc.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.textDark))),
											IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => onEliminar(doc.id), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
										],
									),
								);
							},
						),
					),
				],
			),
		);
	}
}
