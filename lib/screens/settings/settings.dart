import 'package:firmador_geresa/screens/settings/general/general_sgts.dart';
import 'package:firmador_geresa/screens/settings/nxc/nextcloud_sgts.dart';
import 'package:firmador_geresa/screens/settings/settings_box.dart';
import 'package:flutter/material.dart';

class Settings extends StatelessWidget {
	const Settings({super.key});

	@override
	Widget build(BuildContext context) {
		return const SettingsScaffold(
			children: [
				SettingsTabItem(
					title: 'General',
					icon: Icons.settings_outlined,
					screen: GeneralStgs(),
				),

				SettingsTabItem(
					title: 'Nextcloud',
					icon: Icons.cloud_download,
					screen: NextcloudStgs(),
				),
				// SettingsTabItem(
				// 	title: 'Data',
				// 	icon: Icons.dns_outlined,
				// 	screen: Center(child: Text('Componentes de Data aquí')),
				// ),
				// SettingsTabItem(
				// 	title: 'About',
				// 	icon: Icons.info_outline,
				// 	screen: Center(child: Text('Componentes de About aquí')),
				// ),
			],
		);
	}
}