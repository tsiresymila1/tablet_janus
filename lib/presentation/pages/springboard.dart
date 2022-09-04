import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../bloc/call/call_bloc.dart';
import '../widgets/button_widget.dart';
import 'call.dart';

class SpringBoard extends StatelessWidget {
  SpringBoard({Key? key}) : super(key: key);

  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                "assets/images/noveup.png",
                width: 400,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 400 ,
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(width: 0.5, color: Colors.teal)
                    )
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: ButtonWidget(
                title: "Login",
                onPress: () {
                  if (nameController.text.trim() != "") {
                    GetStorage().write('name', nameController.text);
                    context.read<CallBloc>().add(CallRegisterEvent(name:nameController.text));
                    Get.offAll(() => const MakeCallScreen());
                  } else {
                    Fluttertoast.showToast(msg: "Nam not valid");
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
