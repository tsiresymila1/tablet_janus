import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:janus_client/janus_client.dart';
import 'package:meta/meta.dart';
import 'package:tablet_janus/core/utils/utils.dart';
import 'package:tablet_janus/presentation/pages/springboard.dart';

part 'call_event.dart';

part 'call_state.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  late JanusClient j;
  late WebSocketJanusTransport ws;
  late JanusSession session;
  late JanusVideoCallPlugin videoCallPlugin;
  late JanusTextRoomPlugin textRoomPlugin;
  int room = 1234;


  CallBloc() : super(CallInitial()) {
    on<CallInitEvent>((event, emit) {
      initJanusClient();
    });
    on<CallRegisterEvent>((event, emit) async {
      await videoCallPlugin.register(event.name);
    });
    on<CallHangupReleasedEvent>((event,emit){
      emit(CallHangupState());
    });
    on<CallGetVideoRoomEvent>((event, emit){
      emit(CallVideoRoomState(videoCallPlugin: videoCallPlugin));
    });
    on<CallInitMediaEvent>((event, emit) async {
      await videoCallPlugin.initializeMediaDevices();
      add(CallInitializedMediaEvent(videoCallPlugin: videoCallPlugin));
    });

    on<CallInitializedMediaEvent>((event, emit) async {
      emit(CallInitializedMediaState(videoCallPlugin: event.videoCallPlugin));
    });

    on<CallRemoteTrackEvent>((event, emit) {
      emit(CallRemoteTrackState(event: event.event));
    });

    on<CallTypedMessageEvent>((event, emit) {
      emit(CallTypedMessageState(data: event.data, jsep: event.jsep));
    });

    on<CallErrorEvent>((event, emit) {
      emit(CallErrorState(error: event.error));
    });

    on<CallStartEvent>((event, emit) async {
      logInfo("Calling ...${event.name}");
      var offer = await videoCallPlugin.createOffer(
          audioSend: true, audioRecv: true, videoRecv: true, videoSend: true);
      await videoCallPlugin.call(event.name, offer: offer);
    });

    on<CallAcceptedEvent>((event, emit) async {
      FlutterRingtonePlayer.stop();
      await videoCallPlugin.handleRemoteJsep(event.jsep);
      await videoCallPlugin.acceptCall();
    });

    on<CallHangupEvent>((event, emit) async {
      FlutterRingtonePlayer.stop();
      FlutterRingtonePlayer.play(
          fromAsset: "assets/audio/call_end.wav",
          ios: IosSounds.bell
      );
      await videoCallPlugin.hangup();
      await videoCallPlugin.handleRemoteJsep(event.jsep);
      await videoCallPlugin.dispose();
      session.dispose();
      await initJanusClient();
      var user = GetStorage().read('name');
      if(user != null) {
        await videoCallPlugin.register(user);
      }
      else{
        Get.offAll(()=>SpringBoard());
      }
      add(CallHangupReleasedEvent());
    });

    on<CallRotateCameraEvent>((event,emit) async{
      await videoCallPlugin.switchCamera(
          deviceId: await getCameraDeviceId(event.front));
    });

    on<CallRotatedCameraEvent>((event,emit) {
      emit(CallRotatedCameraState());
    });

    on<CallTextRoomEvent>((event,emit){
        emit(CallTextRoomState(message: event.message));
    });

    add(CallInitEvent());
  }

  initJanusClient() async {
    ws = WebSocketJanusTransport(url: dotenv.get('GATEWAY_URL'));
    j = JanusClient(
        transport: ws,
        iceServers: [
          RTCIceServer( urls: "turn:turn.ezway-technology.com:3478",
              username: "skipper",
              credential: "Visio2021"),
          RTCIceServer( urls: "stun:turn.ezway-technology.com:3478",
              username: "",
              credential: "")
        ],
        isUnifiedPlan: true);
    session = await j.createSession();
    videoCallPlugin = await session.attach<JanusVideoCallPlugin>();
    //setup text room
    textRoomPlugin = await session.attach<JanusTextRoomPlugin>();
    await textRoomPlugin.setup();

    // remote track listener
    videoCallPlugin.remoteTrack?.listen((event) async {
      logInfo("Janus remote track available");
      if (event.track != null && event.flowing == true) {
        add(CallRemoteTrackEvent(event: event));
      }
    });
    //message listener
    videoCallPlugin.typedMessages?.listen((even) async {
      logInfo("Typed message : ${jsonEncode(even.event.plugindata)}");
      Object data = even.event.plugindata?.data;
      if(data is VideoCallIncomingCallEvent){
        FlutterRingtonePlayer.play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.bell
        );
      }
      else if(data is VideoCallCallingEvent){
        FlutterRingtonePlayer.play(
            fromAsset: "assets/audio/tone.wav",
            ios: IosSounds.bell
        );
      }
      else if( data is VideoCallAcceptedEvent){
        FlutterRingtonePlayer.stop();
      }
      else if(data is VideoCallRegisteredEvent){
        textRoomPlugin.onData?.listen((event) {
          if (RTCDataChannelState.RTCDataChannelOpen == event) {
            textRoomPlugin.joinRoom(room, data.result!.username ?? getUuid().v4());
          }
        });
        textRoomPlugin.data?.listen((event) {
          add(CallTextRoomEvent(message:parse(event.text)));
          logInfo("TextRoom : ${jsonEncode(parse(event.text))}");
        });
      }
      add(CallTypedMessageEvent(data: data,jsep: even.jsep));
      videoCallPlugin.handleRemoteJsep(even.jsep);
    }, onError: (error) async {
      logError("Janus Error : ${error.toString()}");
      if (error is JanusError) {
        add(CallErrorEvent(error: error));
      }
    });
  }
}
