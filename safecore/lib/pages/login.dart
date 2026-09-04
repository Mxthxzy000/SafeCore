import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Importando TapGestureRecognizer
import '../widgets/header.dart'; // Importando o widget CustomHeader
import 'cadastro.dart'; // Importando a página de cadastro

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF07549B);
    const verde = Color(0xFF7ED321);
    const fundo = Color(0xFFE9E9E9);

    return Scaffold(
      backgroundColor: fundo,
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER CUSTOMIZADO =================
            CustomHeader(pageTitle: "Login"), // Usando o CustomHeader
            // ================= CARD LOGIN =================
            Expanded(
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 12,
                        offset: const Offset(3, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TITULO
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: const BoxDecoration(
                          color: azul,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                        ),
                        child: const Text(
                          "Login",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 15),
                        child: Column(
                          children: [
                            Image.asset(
                              './assets/SafeCore-M&S.webp',
                              width: 150,
                            ),
                            const SizedBox(height: 20),
                            campoLogin(
                              icon: Icons.email_outlined,
                              texto: "Email",
                              hint: "EmailTeste@gmail.com",
                            ),
                            const SizedBox(height: 10),
                            campoLogin(
                              icon: Icons.lock_outline,
                              texto: "Senha",
                              hint: "Senha123",
                              senha: true,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: 190,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: verde,
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Avançar",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(color: azul, fontSize: 14),
                                children: [
                                  const TextSpan(
                                    text:
                                        "Caso ainda não tenha uma conta,\nclique ",
                                  ),
                                  TextSpan(
                                    text: "aqui",
                                    style: const TextStyle(
                                      color: verde,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CadastroPage(),
                                          ),
                                        );
                                      },
                                  ),
                                  const TextSpan(text: " para criar uma"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget campoLogin({
    required IconData icon,
    required String texto,
    required String hint,
    bool senha = false,
  }) {
    const azul = Color(0xFF07549B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: azul, size: 30),
            const SizedBox(width: 8),
            Text(texto, style: const TextStyle(color: azul, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          obscureText: senha,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF4F4F4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
