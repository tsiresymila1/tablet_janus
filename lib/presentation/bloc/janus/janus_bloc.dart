import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'janus_event.dart';
part 'janus_state.dart';

class JanusBloc extends Bloc<JanusEvent, JanusState> {
  JanusBloc() : super(JanusInitial()) {
    on<JanusEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
