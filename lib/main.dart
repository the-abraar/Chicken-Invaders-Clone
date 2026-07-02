import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/menu_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MamlaInvadersApp());
}

class MamlaInvadersApp extends StatelessWidget {
  const MamlaInvadersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mamla Invaders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MenuScreen(),
    );
  }
}
