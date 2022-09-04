import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:material_color_gen/material_color_gen.dart';
import 'package:tablet_janus/presentation/main_bloc.dart';
import 'package:tablet_janus/presentation/pages/splash.dart';

import 'core/utils/utils.dart';
import 'injector.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await dotenv.load(fileName: ".env");
  logInfo(dotenv.get('GATEWAY_URL'));
  setupDependency();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Janus Tablet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal.toMaterialColor(),
      ),
      builder: (ctx, widget){
          return MainBloc(widget: widget);
      },
      home: const SplashScreen(),
    );
  }
}
