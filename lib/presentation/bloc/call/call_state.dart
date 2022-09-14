part of 'call_bloc.dart';

@immutable
abstract class CallState {}

class CallInitial extends CallState {}

class CallHangupState extends CallState {}

class CallInitializedMediaState extends CallState {
  final JanusVideoCallPlugin videoCallPlugin;

  CallInitializedMediaState({required this.videoCallPlugin});
}

class CallVideoRoomState extends CallState {
  final JanusVideoCallPlugin videoCallPlugin;

  CallVideoRoomState({required this.videoCallPlugin});
}

class CallRemoteTrackState extends CallState {
  final RemoteTrack event;
  CallRemoteTrackState({required this.event});
}

class CallTypedMessageState extends CallState {
  final Object data ;
  final RTCSessionDescription? jsep;
  CallTypedMessageState({required this.data, this.jsep});
}

class CallErrorState extends CallState {
  final JanusError error ;

  CallErrorState({required this.error});
}

class CallRotatedCameraState extends CallState{

}

class CallTextRoomState extends CallState {
  final Map message;
  CallTextRoomState({required this.message});
}
