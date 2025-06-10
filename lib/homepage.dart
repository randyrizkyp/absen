import 'package:absen/absen_masuk.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login.dart';
import 'package:absen/global.dart' as globals;
import 'package:absen/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? pegawai;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPegawai();
  }

  Future<void> _fetchPegawai() async {
    final url = Uri.parse('${ApiService.baseUrl}/pegawai/${globals.globalNip}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            pegawai = data[0];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            pegawai = null;
          });
        }
      } else {
        throw Exception("Gagal ambil data pegawai");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _logout() {
    globals.globalNip = '';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _absen(String jenis) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Tombol Absen $jenis ditekan")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F4F1),
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        backgroundColor: const Color(0xFFFF7C7C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pegawai == null
          ? const Center(child: Text("Data tidak ditemukan"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Informasi Pegawai",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          infoTile("Nama", pegawai!['nama']),
                          infoTile("NIP", pegawai!['nip']),
                          infoTile("Pangkat", pegawai!['pangkat']),
                          infoTile("Jabatan", pegawai!['jabatan']),
                          infoTile("Unit Kerja", pegawai!['unit_kerja']),
                          infoTile("Kd_PD", globals.globalKdpd),
                          infoTile("Token", globals.globalToken),
                          infoTile("Url", globals.globalUrl),
                          infoTile("Lat Kode Unit", globals.latKodeunit),
                          infoTile("Lot Kode Unit", globals.lotKodeunit),
                          infoTile("lat TPT lain", globals.latTptlain),
                          infoTile("lot TPT lain", globals.lotTptlain),
                          infoTile("lat OPD lain", globals.latOpdlain),
                          infoTile("lot OPD lain", globals.lotOpdlain),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AbsenMasukPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text("Absen Masuk"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7C7C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _absen("Pulang"),
                          icon: const Icon(Icons.logout),
                          label: const Text("Absen Pulang"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, softWrap: true)),
        ],
      ),
    );
  }
}
