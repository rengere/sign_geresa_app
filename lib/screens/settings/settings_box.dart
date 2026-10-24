import 'package:flutter/material.dart';

// ---------------------------------------------------------
// 1. MODELO DE DATOS PARA LAS PESTAÑAS
// ---------------------------------------------------------
class SettingsTabItem {
	final String title;
	final IconData icon;
	final Widget screen;

	const SettingsTabItem({
		required this.title,
		required this.icon,
		required this.screen,
	});
}

// ---------------------------------------------------------
// 2. EL WIDGET PRINCIPAL (El "SettingsScaffold")
// ---------------------------------------------------------
class SettingsScaffold extends StatefulWidget {
	final List<SettingsTabItem> children;

	const SettingsScaffold({
		super.key,
		required this.children,
	});

	@override
	State<SettingsScaffold> createState() => _SettingsScaffoldState();
}

class _SettingsScaffoldState extends State<SettingsScaffold> {
	int _selectedIndex = 0;

	// Paleta de colores hardcodeada para mantener el estilo limpio
	static const Color _borderColor = Color(0xFFE5E7EB);
	static const Color _primaryColor = Color(0xFFF3F4F6);
	static const Color _textColor = Color(0xFF1F2937);
	static const Color _textGrey = Color(0xFF6B7280);

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: Colors.white,
			appBar: AppBar(
				title: const Text(
					'Settings',
					style: TextStyle(
						fontSize: 18,
						fontWeight: FontWeight.w600,
						color: _textColor,
					),
				),
				backgroundColor: Colors.white,
				elevation: 0,
				scrolledUnderElevation: 0,
				shape: const Border(bottom: BorderSide(color: _borderColor)),
				iconTheme: const IconThemeData(color: _textColor),
			),
			body: Row(
				children: [
					// --- SIDEBAR IZQUIERDO ---
					Container(
						width: 250,
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
						decoration: const BoxDecoration(
							border: Border(right: BorderSide(color: _borderColor)),
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								...List.generate(widget.children.length, (index) {
									final isSelected = _selectedIndex == index;
									final tab = widget.children[index];
									
									return Padding(
										padding: const EdgeInsets.only(bottom: 8),
										child: InkWell(
											onTap: () => setState(() => _selectedIndex = index),
											borderRadius: BorderRadius.circular(8),
											child: Container(
												padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
												decoration: BoxDecoration(
													color: isSelected ? _primaryColor : Colors.transparent,
													borderRadius: BorderRadius.circular(8),
												),
												child: Row(
													children: [
														Icon(
															tab.icon,
															size: 20,
															color: isSelected ? _textColor : _textGrey,
														),
														const SizedBox(width: 12),
														Text(
															tab.title,
															style: TextStyle(
																fontSize: 14,
																fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
																color: isSelected ? _textColor : _textGrey,
															),
														),
													],
												),
											),
										),
									);
								}),
							],
						),
					),

					// --- ÁREA DE CONTENIDO DERECHO ---
					Expanded(
						child: Padding(
							padding: const EdgeInsets.all(32),
							// Aquí cargamos dinámicamente la pantalla que corresponda a la pestaña
							child: widget.children[_selectedIndex].screen,
						),
					),
				],
			),
		);
	}
}