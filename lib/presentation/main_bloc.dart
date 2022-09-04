import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:janus_client/janus_client.dart';
import 'package:tablet_janus/presentation/bloc/call/call_bloc.dart';
import 'package:tablet_janus/presentation/bloc/janus/janus_bloc.dart';
import 'package:tablet_janus/presentation/bloc/login/login_bloc.dart';
import 'package:tablet_janus/presentation/pages/incomming_call.dart';

import '../core/utils/utils.dart';
import '../injector.dart';

class MainBloc extends StatefulWidget {
  final Widget? widget;

  const MainBloc({super.key, required this.widget});

  @override
  State<MainBloc> createState() => _MainBlocState();
}

class _MainBlocState extends State<MainBloc> {
  AlertDialog? incomingDialog;

  @override
  void initState() {
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.landscapeRight,
    //   DeviceOrientation.landscapeLeft,
    // ]);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => sl.get<JanusBloc>()),
          BlocProvider(create: (context) => sl.get<LoginBloc>()),
          BlocProvider(create: (context) => sl.get<CallBloc>())
        ],
        child: BlocConsumer(
            bloc: sl.get<CallBloc>(),
            listener: (context, state) async {
              if (state is CallTypedMessageState) {
                logInfo("Janus typedMessages Event : ${state.data.toString()}");
                if (state.data is VideoCallRegisteredEvent) {
                  Fluttertoast.showToast(msg: "User register");
                } else if (state.data is VideoCallIncomingCallEvent) {
                  Fluttertoast.showToast(msg: "Incoming call ...");
                  var data = state.data as VideoCallIncomingCallEvent;
                  Get.offAll(() => IncomingCallScreen(
                      caller: data.result!.username!, jsep: state.jsep));
                }
                else if(state.data is VideoCallHangupEvent){
                  context.read<CallBloc>().add(CallHangupEvent());
                }
                else {
                  Fluttertoast.showToast(
                      msg:
                          "Janus typedMessages Event : ${state.data.toString()}");
                }
              }
              else if(state is CallErrorState){
                Get.dialog(AlertDialog(
                  actions: [
                    TextButton(
                        onPressed: () async {
                          if(Get.isDialogOpen!){
                            Get.back();
                          }
                        },
                        child: const Text('Okay'))
                  ],
                  title: const Text('Whoops!'),
                  content: Text(state.error.error),
                ));
              }
            },
            builder: (context, state) {
              return widget.widget ?? Container();
            }));
  }
}
