// File: absen_masuk_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:absen/global.dart' as globals;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:image/image.dart' as img;

class AbsenMasukPage extends StatefulWidget {
  const AbsenMasukPage({super.key});

  @override
  State<AbsenMasukPage> createState() => _AbsenMasukPageState();
}

Future<File> compressImage(File file) async {
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) return file;

  final compressed = img.encodeJpg(image, quality: 60);
  final tempDir = Directory.systemTemp;
  final compressedFile = File('${tempDir.path}/${basename(file.path)}')
    ..writeAsBytesSync(compressed);
  return compressedFile;
}

class _AbsenMasukPageState extends State<AbsenMasukPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  final MapController _mapController = MapController();

  File? _fotoDepan;
  File? _fotoBelakang;
  Position? _posisi;
  bool _loading = false;
  String _status = '';
  bool _kameraAktif = true;

  late String _waktu;
  late final Timer _timer;

  final Color primaryColor = const Color(0xFF263238);
  final Color accentColor = const Color(0xFF4DB6AC);
  final Color bgColor = const Color(0xFFF9F9F9);
  final Color textColor = const Color(0xFF212121);
  final Color buttonColor = const Color(0xFF00796B);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _initCameras();
    _ambilLokasi();

    _waktu = DateFormat('HH:mm:ss').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waktu = DateFormat('HH:mm:ss').format(DateTime.now());
        });
      }
    });
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      final depan = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _controller = CameraController(depan, ResolutionPreset.medium);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _kameraAktif = true;
        });
      }
    }
  }

  Future<void> _ambilLokasi() async {
    LocationPermission izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) {
      izin = await Geolocator.requestPermission();
    }

    final posisi = await Geolocator.getCurrentPosition();
    setState(() {
      _posisi = posisi;
    });
    _mapController.move(LatLng(posisi.latitude, posisi.longitude), 16.0);
  }

  Future<void> _ambilFotoDepanBelakang() async {
    setState(() {
      _loading = true;
      _status = "Mengambil foto depan...";
    });

    try {
      final depan = await _controller!.takePicture();
      final compressedDepan = await compressImage(File(depan.path));
      setState(() {
        _fotoDepan = compressedDepan;
      });

      setState(() {
        _kameraAktif = false;
      });
      await _controller!.dispose();
      _controller = null;

      setState(() {
        _status = "Mengambil foto belakang...";
      });

      final kameraBelakang = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      final controllerBelakang = CameraController(
        kameraBelakang,
        ResolutionPreset.medium,
      );
      await controllerBelakang.initialize();

      final belakang = await controllerBelakang.takePicture();
      final compressedBelakang = await compressImage(File(belakang.path));
      setState(() {
        _fotoBelakang = compressedBelakang;
        _status = "Foto berhasil diambil.";
      });

      await controllerBelakang.dispose();
    } catch (e) {
      setState(() => _status = 'Gagal mengambil foto: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _kirimAbsen() async {
    if (_fotoDepan == null || _fotoBelakang == null || _posisi == null) {
      setState(() => _status = "Foto dan lokasi harus lengkap sebelum kirim.");
      return;
    }

    setState(() {
      _loading = true;
      _status = "Mengirim data absen...";
    });

    try {
      final key = encrypt.Key.fromUtf8('${globals.globalToken}');
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ecb),
      );
      String encryptNip(String nip) {
        final encrypted = encrypter.encrypt(nip);
        return encrypted.base64;
      }

      final uri = Uri.parse('${globals.globalUrl}/post-absen/');
      var request = http.MultipartRequest('POST', uri);
      request.fields['nip'] = encryptNip(globals.globalNip);

      request.files.add(
        await http.MultipartFile.fromPath(
          'foto_depan',
          _fotoDepan!.path,
          filename: basename(_fotoDepan!.path),
        ),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'foto_belakang',
          _fotoBelakang!.path,
          filename: basename(_fotoBelakang!.path),
        ),
      );

      final now = DateTime.now();
      request.fields['latitude'] = _posisi!.latitude.toString();
      request.fields['longitude'] = _posisi!.longitude.toString();
      request.fields['bulan'] = now.month.toString().padLeft(2, '0');
      request.fields['tanggal'] = now.day.toString().padLeft(2, '0');
      request.fields['tahun'] = now.year.toString();
      request.fields['jam'] = DateFormat('HH:mm:ss').format(now);
      request.fields['kd_pd'] = globals.globalKdpd.toString();

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody.body);
        if (data['code'] == 2) {
          setState(() => _status = "Anda Telah Melakukan Absen Masuk");
        } else if (data['code'] == 1) {
          setState(() => _status = "Absen berhasil dikirim!");
        }
      } else {
        setState(
          () => _status = "Gagal kirim absen, status: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() => _status = "Terjadi kesalahan: $e");
    }

    setState(() => _loading = false);
  }

  String get formattedDate {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latLng = _posisi != null
        ? LatLng(_posisi!.latitude, _posisi!.longitude)
        : LatLng(0, 0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Absen Masuk'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$formattedDate | $_waktu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),

            if (_posisi != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(center: latLng, zoom: 16),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: latLng,
                                width: 80,
                                height: 80,
                                child: Column(
                                  children: const [
                                    Text(
                                      "Lokasi Anda",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                    Icon(Icons.location_pin, color: Colors.red),
                                  ],
                                ),
                              ),
                              Marker(
                                point: LatLng(
                                  double.parse(globals.latKodeunit),
                                  double.parse(globals.lotKodeunit),
                                ),
                                width: 80,
                                height: 80,
                                child: Column(
                                  children: const [
                                    Text(
                                      "Kantor Anda",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Icon(
                                      Icons.location_pin,
                                      color: Colors.orange,
                                    ),
                                  ],
                                ),
                              ),
                              if (globals.latTptlain != 0.0 &&
                                  globals.lotTptlain != 0.0)
                                Marker(
                                  point: LatLng(
                                    double.parse(globals.latTptlain),
                                    double.parse(globals.lotTptlain),
                                  ),
                                  width: 80,
                                  height: 80,
                                  child: Column(
                                    children: const [
                                      Text(
                                        "Kantor Anda (TPT Lain)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Icon(
                                        Icons.location_pin,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),
                                ),
                              if (globals.latOpdlain != 0.0 &&
                                  globals.lotOpdlain != 0.0)
                                Marker(
                                  point: LatLng(
                                    double.parse(globals.latOpdlain),
                                    double.parse(globals.lotOpdlain),
                                  ),
                                  width: 80,
                                  height: 80,
                                  child: Column(
                                    children: const [
                                      Text(
                                        "Kantor Anda (OPD Lain)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Icon(
                                        Icons.location_pin,
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: ClipOval(
                          child: Material(
                            color: Colors.white.withOpacity(0.9),
                            child: InkWell(
                              splashColor: Colors.grey,
                              onTap: _ambilLokasi,
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(Icons.refresh, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            if (_kameraAktif &&
                _controller != null &&
                _controller!.value.isInitialized)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 250,
                    height: 290,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            Center(
              child: ElevatedButton.icon(
                icon: Icon(
                  _fotoDepan != null && _fotoBelakang != null
                      ? Icons.send
                      : Icons.camera,
                ),
                label: Text(
                  _fotoDepan != null && _fotoBelakang != null
                      ? "Kirim Absen"
                      : "Ambil Foto Depan & Belakang",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _loading
                    ? null
                    : (_fotoDepan != null && _fotoBelakang != null
                          ? _kirimAbsen
                          : _ambilFotoDepanBelakang),
              ),
            ),

            const SizedBox(height: 10),
            Text(_status, style: TextStyle(color: accentColor)),
            const SizedBox(height: 16),

            if (_fotoDepan != null && _fotoBelakang != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _fotoPreview("Foto Depan", _fotoDepan!),
                  _fotoPreview("Foto Belakang", _fotoBelakang!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _fotoPreview(String label, File file) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(file, height: 150, width: 150, fit: BoxFit.cover),
        ),
      ],
    );
  }
}
