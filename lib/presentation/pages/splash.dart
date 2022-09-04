import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:tablet_janus/presentation/bloc/call/call_bloc.dart';
import 'package:tablet_janus/presentation/pages/call.dart';
import 'package:tablet_janus/presentation/pages/springboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    Timer(const Duration(seconds: 5), () {
      var user = GetStorage().read('name');
      if(user != null){
        var user = GetStorage().read('name');
        context.read<CallBloc>().add(CallRegisterEvent(name:user));
        Get.offAll(() => const MakeCallScreen());
      }else{
        Get.offAll(() => SpringBoard());
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset("assets/images/vibook.png"),
      ),
    );
  }
}
