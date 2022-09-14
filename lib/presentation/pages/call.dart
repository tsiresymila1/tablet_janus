import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:janus_client/janus_client.dart';
import 'package:tablet_janus/core/utils/utils.dart';
import 'package:wakelock/wakelock.dart';

import '../../injector.dart';
import '../bloc/call/call_bloc.dart';

class MakeCallScreen extends StatefulWidget {
  const MakeCallScreen({Key? key}) : super(key: key);

  @override
  State<MakeCallScreen> createState() => _MakeCallScreenState();
}

class _MakeCallScreenState extends State<MakeCallScreen> {
  List<String> userNameDisplayMap = [];
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  final TextEditingController nameController = TextEditingController();
  MediaStream? remoteVideoStream;
  bool isFront = true;
  JanusVideoCallPlugin? videoCallPlugin;
  bool isCalling = false;
  String currentUser = "";

  Future initializeRemoteVideo() async {
    await _remoteVideoRenderer.initialize();
    MediaStream? tempVideo = await createLocalMediaStream('remoteVideoStream');
    setState(() {
      remoteVideoStream = tempVideo;
    });
  }

  Future<void> cleanUpWebRTCStuff() async {
    setState(() {
      _localRenderer.srcObject = null;
      _remoteVideoRenderer.srcObject = null;
    });
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

  bool isMe(data){
    var username = GetStorage().read('user');
    return data['username'] == username;
  }

  void handleRoomData(Map<dynamic, dynamic>? data) {
    if (data != null) {
      if (data['textroom'] == 'leave') {
        setState(() {
          Future.delayed(const Duration(seconds: 1)).then((value) {
            userNameDisplayMap.remove(data['username']);
          });
        });

      }
      if (data['textroom'] == 'join') {
        if(!isMe(data)){
          setState(() {
            userNameDisplayMap.remove(data['username']);
            userNameDisplayMap.add(data['username']);
          });
        };
      }
      if (data['participants'] != null) {
        setState(() {
          userNameDisplayMap = [];
        });
        for (var element in (data['participants'] as List<dynamic>)) {
          setState(() {
            userNameDisplayMap.add(element['username']);
          });
        }
      }
    }
    logInfo(userNameDisplayMap);
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
        if (state is CallTextRoomState) {
          handleRoomData(state.message);
        } else if (state is CallVideoRoomState) {
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
            setState(() {
              userNameDisplayMap = [];
            });
            await destroy();
          }
        } else if (state is CallErrorState) {
          setState(() {
            isCalling = false;
            destroy();
          });
        } else if (state is CallRotatedCameraState) {
          if (videoCallPlugin != null) {
            setState(() {
              isCalling = true;
              _localRenderer.srcObject =
                  videoCallPlugin?.webRTCHandle?.localStream;
            });
          }
        }
      },
      builder: (context, state) => Scaffold(
        appBar: !isCalling? AppBar(
          title: const Text("Contact"),
        ): null,
        drawer: const Drawer(),
        body: Stack(children: [
          !isCalling
              ? Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                        itemCount: userNameDisplayMap.length,
                        itemBuilder: (context, index) {
                          var user = userNameDisplayMap[index] ;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                            child: ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(user ?? ""),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  nameController.text = user ?? "";
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
                          );
                        }),
                  ))
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
                                icon:
                                    const Icon(Icons.flip_camera_android_sharp),
                                color: Colors.white,
                                onPressed: () async {
                                  context.read<CallBloc>().add(
                                      CallRotateCameraEvent(front: !isFront));
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
