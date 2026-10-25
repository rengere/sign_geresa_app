import 'package:firmador_geresa/screens/home/home_screen.dart';
import 'package:firmador_geresa/screens/nav/update_button.dart';
import 'package:firmador_geresa/screens/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:firmador_geresa/assets/theme/app_theme.dart';

class NaviBar extends StatefulWidget {
	const NaviBar({super.key});

	@override
	State<NaviBar> createState() => _NaviBarState();
}

class _NaviBarState extends State<NaviBar> {
	int _selectedIndex = 0;

	// Clave global para controlar el Navigator interno del área de contenido
	final GlobalKey<NavigatorState> _contentNavigatorKey = GlobalKey<NavigatorState>();

	void _onItemSelected(int index) {
		if (_selectedIndex != index) {
			setState(() {
				_selectedIndex = index;
			});
			// Si cambiamos de tab, volvemos a la raíz del Navigator interno
			_contentNavigatorKey.currentState?.popUntil((route) => route.isFirst);
		}
	}

	// YA NO TIENE 'index'. La posición en la lista es su índice.
	late final List<_TabData> _tabs = [
		_TabData(
			icon: Icons.home_rounded,
			label: 'Inicio',
			screen: const HomeScreen(),
		),
		_TabData(
			icon: Icons.bar_chart_rounded,
			label: 'Stats',
			screen: const Center(child: Text("screen 2", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
		),
		// _TabData(
		// 	icon: Icons.chat_bubble_outline_rounded,
		// 	label: 'Chat',
		// 	screen: const Center(child: Text("screen 3", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
		// ),
		// _TabData(
		// 	icon: Icons.folder_outlined,
		// 	label: 'Files',
		// 	screen: const Center(child: Text("screen 4", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
		// ),
		// _TabData(
		// 	icon: Icons.folder_outlined,
		// 	label: 'Filesss',
		// 	screen: const Center(child: Text("screen 5", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
		// ),
		_TabData(
			icon: Icons.settings_outlined,
			label: 'Config.',
			screen: const Settings()
		),
	];

	@override
	Widget build(BuildContext context) {
		// El último tab (Settings) se queda fijo abajo
		final List<_TabData> mainTabs = _tabs.sublist(0, _tabs.length - 1);
		final _TabData settingsTab = _tabs.last;

		return Scaffold(
			backgroundColor: context.backgroundLight,

			// btn actualizar
			floatingActionButton: const Padding(
				padding: EdgeInsets.only(top: 10, right: 10),
				child: UpdateButton(), 
			),
			floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
			
			body: Row(
				children: [

					// SIDEBAR
					Container(
						width: 90,
						margin: const EdgeInsets.all(16),
						decoration: BoxDecoration(
							color: context.primaryPurple,
							borderRadius: BorderRadius.circular(32),
							boxShadow: AppTheme.shadowMd,
						),
						child: Column(
							children: [
								Expanded(
									child: ScrollConfiguration(
										behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
										child: SingleChildScrollView(
											padding: const EdgeInsets.symmetric(vertical: 24),
											child: Column(
												children: mainTabs.asMap().entries.map((entry) {
													final int index = entry.key;
													final _TabData tab = entry.value;
													
													return Padding(
														padding: const EdgeInsets.only(bottom: 12),
														child: _SidebarIcon(
															icon: tab.icon,
															label: tab.label,
															isSelected: _selectedIndex == index,
															onTap: () => _onItemSelected(index),
														),
													);
												}).toList(),
											),
										),
									),
								),
								
								// Settings fijo abajo
								Padding(
									padding: const EdgeInsets.only(bottom: 24),
									child: _SidebarIcon(
										icon: settingsTab.icon,
										label: settingsTab.label,
										// Para Settings, el índice es el último de la lista original
										isSelected: _selectedIndex == _tabs.length - 1,
										onTap: () => _onItemSelected(_tabs.length - 1),
									),
								),
							],
						),
					),

					// ==========================================
					// ÁREA PRINCIPAL
					// ==========================================
					Expanded(
						child: Container(
							margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
							decoration: BoxDecoration(
								color: context.surfaceWhite,
								borderRadius: BorderRadius.circular(32),
							),
							child: ClipRRect(
								borderRadius: BorderRadius.circular(32),
								child: Navigator(
									key: _contentNavigatorKey,
									onGenerateRoute: (settings) {
										// La pantalla inicial es el tab seleccionado por su índice
										return MaterialPageRoute(
											builder: (context) => KeyedSubtree(
												key: ValueKey<int>(_selectedIndex),
												child: _tabs[_selectedIndex].screen,
											),
										);
									},
								),
							),
						),
					),
				],
			),
		);
	}
}

// ==========================================
// CLASE DE DATOS PARA CADA TAB (SIN INDEX)
// ==========================================
class _TabData {
	final IconData icon;
	final String label;
	final Widget screen;

	_TabData({
		required this.icon,
		required this.label,
		required this.screen,
	});
}

// ==========================================
// WIDGET DEL ICONO DEL SIDEBAR (CON PADDING AJUSTADO)
// ==========================================
class _SidebarIcon extends StatefulWidget {
	final IconData icon;
	final String label;
	final bool isSelected;
	final VoidCallback onTap;

	const _SidebarIcon({
		required this.icon,
		required this.label,
		required this.isSelected,
		required this.onTap,
	});

	@override
	State<_SidebarIcon> createState() => _SidebarIconState();
}

class _SidebarIconState extends State<_SidebarIcon> {
	bool _isHovered = false;

	@override
	Widget build(BuildContext context) {
		final bool showLabel = widget.isSelected || _isHovered;

		return MouseRegion(
			onEnter: (_) => setState(() => _isHovered = true),
			onExit: (_) => setState(() => _isHovered = false),
			cursor: SystemMouseCursors.click,
			child: GestureDetector(
				onTap: widget.onTap,
				behavior: HitTestBehavior.opaque,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						AnimatedContainer(
							duration: const Duration(milliseconds: 300),
							width: 56,
							height: 52, // Altura ajustada para no sobreponer el texto
							decoration: BoxDecoration(
								color: widget.isSelected ? Colors.white : Colors.transparent,
								borderRadius: BorderRadius.circular(16),
								boxShadow: widget.isSelected ? AppTheme.shadowSm : [],
							),
							child: Icon(
								widget.icon,
								color: widget.isSelected
									? context.primaryPurple
									: Colors.white.withOpacity(_isHovered ? 1.0 : 0.7),
								size: 24,
							),
						),
						const SizedBox(height: 2), // Separación mínima
						AnimatedOpacity(
							duration: const Duration(milliseconds: 200),
							opacity: showLabel ? 1.0 : 0.0,
							child: Text(
								widget.label,
								style: const TextStyle(
									color: Colors.white,
									fontSize: 10,
									fontWeight: FontWeight.w600,
									height: 1.0,
								),
							),
						),
					],
				),
			),
		);
	}
}