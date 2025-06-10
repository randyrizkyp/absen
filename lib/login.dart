import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:absen/global.dart' as globals;
import 'package:absen/api_service.dart';
import 'homepage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool rememberMe = false;
  bool _obscurePassword = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadLoginData();
  }

  Future<void> loadLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    final isRemembered = prefs.getBool('remember_me') ?? false;

    if (isRemembered) {
      setState(() {
        rememberMe = true;
        usernameController.text = prefs.getString('username') ?? '';
        passwordController.text = prefs.getString('password') ?? '';
      });
    }
  }

  Future<void> saveLoginData(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', rememberMe);
    if (rememberMe) {
      await prefs.setString('username', username);
      await prefs.setString('password', password);
    } else {
      await prefs.remove('username');
      await prefs.remove('password');
    }
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    setState(() {
      errorMessage = '';
    });

    final url = Uri.parse('${ApiService.baseUrl}/users/$username');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0] == password) {
          globals.globalNip = username;

          final kdpd = Uri.parse('${ApiService.baseUrl}/pegawai/$username');
          final kdpdResponse = await http.get(kdpd);
          final kdpdData = jsonDecode(kdpdResponse.body);
          globals.globalKdpd = kdpdData[0]['kode_pd'];
          globals.globalKdunit = kdpdData[0]['kode_unit'];
          globals.latKodeunit = kdpdData[0]['lat_kode_unit'] ?? '0.0';
          globals.lotKodeunit = kdpdData[0]['lot_kode_unit'] ?? '0.0';
          globals.latTptlain = kdpdData[0]['lat_tpt_lain'] ?? '0.0';
          globals.lotTptlain = kdpdData[0]['lot_tpt_lain'] ?? '0.0';
          globals.latOpdlain = kdpdData[0]['lat_opd_lain'] ?? '0.0';
          globals.lotOpdlain = kdpdData[0]['lot_opd_lain'] ?? '0.0';

          final baseApi = Uri.parse(
            '${ApiService.baseUrl}/token/${globals.globalKdpd}',
          );
          final baseApiResponse = await http.get(baseApi);
          final baseApiData = jsonDecode(baseApiResponse.body);
          globals.globalToken = baseApiData[0]['token'];
          globals.globalUrl = baseApiData[0]['url'];

          await saveLoginData(username, password);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          setState(() {
            errorMessage = 'Password salah';
          });
        }
      } else {
        setState(() {
          errorMessage = 'Username tidak ada';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F4F1),
      body: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: MediaQuery.of(context).viewInsets.bottom > 0 ? -100 : -20,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/top_wave.png',
              width: double.infinity,
              height: 350,
              fit: BoxFit.fill,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 145),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'e-absensi',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'NIP',
                      prefixIcon: Icon(Icons.person_outline),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF7C7C)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color.fromARGB(255, 222, 205, 205),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF7C7C)),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFFFF7C7C),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (value) {
                          setState(() {
                            rememberMe = value!;
                          });
                        },
                      ),
                      const Text("Remember Me"),
                      const Spacer(),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7C7C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFF9F4F1),
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (MediaQuery.of(context).viewInsets.bottom == 0)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'e-absensi v1.0 Kab. Lampung Utara © 2025',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
