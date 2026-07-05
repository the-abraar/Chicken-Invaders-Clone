import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/save_data.dart';
import 'screens/menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SaveData.load();
  runApp(const TrafficTyrantsApp());
}

class TrafficTyrantsApp extends StatelessWidget {
  const TrafficTyrantsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Tyrants',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MenuScreen(),
    );
  }
}
