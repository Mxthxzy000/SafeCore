import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget {
  final String pageTitle;

  const CustomHeader({super.key, required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    final isLoginOrSignup = pageTitle == 'Login' || pageTitle == 'Cadastro';

    return Container(
      height: 118,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF014D90),
            Color(0xFF0A6CC5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F5EC8),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment:
              isLoginOrSignup ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (!isLoginOrSignup)
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/logo-branca.webp', height: 64),
                ),
              ),
            if (!isLoginOrSignup)
              Expanded(
                child: Center(
                  child: Text(
                    pageTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            if (isLoginOrSignup)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('assets/logo-branca.webp', height: 74),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
