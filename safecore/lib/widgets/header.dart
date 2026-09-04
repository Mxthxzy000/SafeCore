import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget {
  final String pageTitle;

  const CustomHeader({Key? key, required this.pageTitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isLoginOrSignup = pageTitle == 'Login' || pageTitle == 'Cadastro';

    return Container(
      height: 100,
      color: Color(0xFF014D90),
      child: Row(
        mainAxisAlignment: isLoginOrSignup
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (!isLoginOrSignup)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Image.asset('assets/logo-branca.webp', height: 80),
            ),
          if (!isLoginOrSignup)
            Expanded(
              child: Center(
                child: Text(
                  pageTitle,
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          if (isLoginOrSignup)
            Center(child: Image.asset('assets/logo-branca.webp', height: 80)),
        ],
      ),
    );
  }
}
