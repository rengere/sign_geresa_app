// lib/screens/home/tab_scaffold.dart
import 'package:firmador_geresa/assets/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FirmaTabItem {
	final String title;
	final IconData icon;
	final Widget screen;

	const FirmaTabItem({
		required this.title,
		required this.icon,
		required this.screen,
	});
}

class TabScaffold extends StatelessWidget {
	final List<FirmaTabItem> children;

	const TabScaffold({
		super.key,
		required this.children,
	});

	@override
	Widget build(BuildContext context) {
		return DefaultTabController(
			length: children.length,
			child: Scaffold(
				backgroundColor: context.backgroundLight,
				body: Stack(
					children: [
						Positioned.fill(
							child: SafeArea(
								bottom: false,
								child: TabBarView(
									physics: const NeverScrollableScrollPhysics(),
									children: children.map((tab) => tab.screen).toList(),
								),
							),
						),
						Positioned(
							bottom: 0,
							left: 0,
							right: 0,
							child: Center(
								child: FractionallySizedBox(
									widthFactor: 0.7,
									child: Container(
										height: 50,
										decoration: BoxDecoration(
											color: context.surfaceGrey,
											borderRadius: BorderRadius.circular(context.radiusLg),
											boxShadow: AppTheme.shadowMd,
											border: Border.all(
												color: context.borderColor,
												width: 1,
											),
										),
										child: Padding(
											padding: const EdgeInsets.only(bottom: 15),
											child: ClipRRect(
												borderRadius: BorderRadius.circular(context.radiusLg),
												child: TabBar(
													indicator: const BoxDecoration(
														color: AppTheme.primaryPurple,
														borderRadius: BorderRadius.zero,
													),
													indicatorSize: TabBarIndicatorSize.tab,
													dividerColor: Colors.transparent,
													labelColor: Colors.white,
													unselectedLabelColor: AppTheme.textGrey,
													labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
													unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
													tabs: children.map((tab) {
														return Tab(
															child: Row(
																mainAxisAlignment: MainAxisAlignment.center,
																children: [
																	Icon(tab.icon, size: 20),
																	const SizedBox(width: 8),
																	Text(tab.title),
																],
															),
														);
													}).toList(),
												),
											),
										),
									),
								),
							),
						),

						

					],
				),
			),
		);
	}
}