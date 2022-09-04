import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/janus_client.dart';
import 'package:wakelock/wakelock.dart';

import '../../injector.dart';
import '../bloc/call/call_bloc.dart';
import '../widgets/button_widget.dart';

class MakeCallScreen extends StatefulWidget {
  const MakeCallScreen({Key? key}) : super(key: key);

  @override
  State<MakeCallScreen> createState() => _MakeCallScreenState();
}

class _MakeCallScreenState extends State<MakeCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  final TextEditingController nameController = TextEditingController();
  MediaStream? remoteVideoStream;
  bool isFront = true;
  JanusVideoCallPlugin? videoCallPlugin;
  bool isCalling = false;

  Future initializeRemoteVideo() async {
    await _remoteVideoRenderer.initialize();
    MediaStream? tempVideo = await createLocalMediaStream('remoteVideoStream');
    setState(() {
      remoteVideoStream = tempVideo;
    });
  }

  Future<void> cleanUpWebRTCStuff() async {
    _localRenderer.srcObject = null;
    _remoteVideoRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteVideoRenderer.dispose();
  }

  Future destroy() async {
    if (videoCallPlugin != null) {
      // await stopAllTracksAndDispose(videoCallPlugin?.webRTCHandle?.localStream);
      // await stopAllTracksAndDispose(remoteVideoStream);
      // videoCallPlugin?.dispose();
    }
    setState(() {
      isCalling = false;
    });
  }

  @override
  void initState() {
    Wakelock.enable();
    super.initState();
  }

  @override
  void dispose() {
    Wakelock.disable();
    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await _localRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      bloc: sl.get<CallBloc>()..add(CallGetVideoRoomEvent()),
      listener: (context, state) async {
        if (state is CallVideoRoomState) {
          setState(() {
            videoCallPlugin = state.videoCallPlugin;
          });
        } else if (state is CallInitializedMediaState) {
          setState(() {
            videoCallPlugin = state.videoCallPlugin;
            _localRenderer.srcObject =
                state.videoCallPlugin.webRTCHandle?.localStream;
          });
          context
              .read<CallBloc>()
              .add(CallStartEvent(name: nameController.text));
        } else if (state is CallRemoteTrackState) {
          await initializeRemoteVideo();
          remoteVideoStream?.addTrack(state.event.track!);
          await _remoteVideoRenderer.initialize();
          setState(() {
            _remoteVideoRenderer.srcObject = remoteVideoStream;
          });
        } else if (state is CallTypedMessageState) {
          if (state.data is VideoCallCallingEvent) {
            setState(() {
              isCalling = true;
            });
          } else if (state.data is VideoCallAcceptedEvent) {
            setState(() {
              isCalling = true;
            });
          } else if (state.data is VideoCallHangupEvent) {
            await destroy();
          }
        }  else if(state is CallErrorState){
          setState(() {
            isCalling = false;
            destroy();
          });
        }
        else if(state is CallRotatedCameraState){
          if(videoCallPlugin != null){
            setState(() {
              isCalling = true;
              _localRenderer.srcObject =
                  videoCallPlugin?.webRTCHandle?.localStream;
            });
          }
        }
      },
      builder: (context, state) => Scaffold(
        body: Stack(children: [
          !isCalling
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: SizedBox(
                            width: 400,
                            child: TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                  hintText: "Name",
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide:
                                      const BorderSide(width: 1, color: Colors.teal)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide:
                                          const BorderSide(width: 1,color: Colors.teal)),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 200,
                            child: ButtonWidget(
                              title: "Call",
                              onPress: () async {
                                _localRenderer.initialize().then((value) {
                                  context
                                      .read<CallBloc>()
                                      .add(CallInitMediaEvent());
                                  setState(() {
                                    isCalling = true;
                                  });
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.black,
                                child: RTCVideoView(
                                  _remoteVideoRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: 180,
                          width: 120,
                          child: RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
          isCalling
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 30,
                            child: IconButton(
                                icon: const Icon(Icons.call_end),
                                color: Colors.white,
                                onPressed: () async {
                                  context
                                      .read<CallBloc>()
                                      .add(CallHangupEvent());
                                  destroy();
                                })),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircleAvatar(
                            backgroundColor: Colors.teal,
                            radius: 30,
                            child: IconButton(
                                icon: const Icon(Icons.flip_camera_android_sharp),
                                color: Colors.white,
                                onPressed: () async {
                                  context
                                      .read<CallBloc>()
                                      .add(CallRotateCameraEvent(front: !isFront));
                                  setState(() {
                                    isFront = !isFront;
                                  });
                                })),
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  width: 0,
                  height: 0,
                )
        ]),
      ),
    );
  }
}
