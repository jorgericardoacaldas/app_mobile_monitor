import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(home: MapaLojasPage()));
}

class Ponto {
  final DateTime day;
  final String hr;
  final String ts;
  final String codTipoEvento;
  final String dscEvento;
  final int codTipoLocal;
  final int codFilialCc;
  final String nomWorkstation;
  final String txtLogin;

  Ponto({
    required this.day,
    required this.hr,
    required this.ts,
    required this.codTipoEvento,
    required this.dscEvento,
    required this.codTipoLocal,
    required this.codFilialCc, 
    required this.nomWorkstation,
    required this.txtLogin,
  });

  factory Ponto.fromJson(Map<String, dynamic> json) {
    return Ponto(
      day: DateTime.parse(json['day']),
      hr: json['hr'],
      ts: json['ts'],
      codTipoEvento: json['codTipoEvento'],
      dscEvento: json['dscEvento'],
      codTipoLocal: json['codTipoLocal'],
      codFilialCc: json['codFilialCc'],
      nomWorkstation: json['nomWorkstation'],
      txtLogin: json['txtLogin'],
    );
  }
}

class Loja {
  final String siteId;
  final String siteName;
  final String deviceArea;
  final String deviceType;
  final String deviceName;
  final int down;
  final DateTime lastSeen; 
  final double lat;
  final double lon;
  final String cityName;
  final String regionName;

  Loja({
    required this.siteId,
    required this.siteName,
    required this.deviceArea,
    required this.deviceType,
    required this.deviceName,
    required this.down,
    required this.lastSeen, 
    required this.lat,
    required this.lon,
    required this.cityName,
    required this.regionName,
  });

  factory Loja.fromJson(Map<String, dynamic> json) {
    final geo = json['geo_loc'];
    return Loja(
      siteId: json['site_id'].toString(),
      siteName: json['site_name'],
      deviceArea: json['device_area'],
      deviceType: json['device_type'],
      deviceName: json['device_name'],
      down: json['down'],
      lastSeen: DateTime.parse(json['timestamp']), 
      lat: geo['lat'].toDouble(),
      lon: geo['lon'].toDouble(),
      cityName: json['city_name'],
      regionName: json['region_name'],
    );
  }
}

class MapaLojasPage extends StatefulWidget {
  @override
  _MapaLojasPageState createState() => _MapaLojasPageState();
}

class _MapaLojasPageState extends State<MapaLojasPage> {
  List<Loja> _lojas = [];
  bool _loading = true;
  String _search = ''; 
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _carregarLojas();
    _statusTimer = Timer.periodic(Duration(seconds: 10), (Timer t) {
      _carregarLojas();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarLojas() async {
    final lojas = await fetchLojas();
    setState(() {
      _lojas = lojas;
      _loading = false;
    });
  }

  Future<List<Loja>> fetchLojas() async {
    final response = await http.get(Uri.parse('http://localhost:5021/api/Monitoring/all'));

    if (response.statusCode == 200) {
      final List<dynamic> lojasData = json.decode(response.body);
      return lojasData.map((json) => Loja.fromJson(json)).toList();
    } else {
      throw Exception('Erro ao carregar lojas');
    }
  }

  void _mostrarDetalhes(Loja loja) {
    final devicesDaLoja = _lojas.where((d) => d.siteId == loja.siteId).toList();
    final onlineDevices = devicesDaLoja.where((d) => d.down == 0).toList();
    final offlineDevices = devicesDaLoja.where((d) => d.down == 1).toList();

    final uniqueOnlineDevices = <String, Loja>{};
    for (var device in onlineDevices) {
      uniqueOnlineDevices[device.deviceName] = device;
    }
    final uniqueOfflineDevices = <String, Loja>{};
    for (var device in offlineDevices) {
      uniqueOfflineDevices[device.deviceName] = device;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${loja.siteName} (${loja.cityName}/${loja.regionName})",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                "Dispositivos Online",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ...uniqueOnlineDevices.values.map((device) => ListTile(
                    title: Text(device.deviceName),
                    subtitle: Text("${device.deviceType} - ${device.deviceArea}"),
                  )),
              SizedBox(height: 16),
              Text(
                "Dispositivos Offline",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ...uniqueOfflineDevices.values.map((device) => ListTile(
                    title: Text(device.deviceName),
                    subtitle: Text("${device.deviceType} - ${device.deviceArea}"),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final filteredLojas = _lojas.where((loja) => _search.isEmpty || loja.siteId.contains(_search)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Mapa de Lojas"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
              });
              _carregarLojas();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtro por Site ID',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: Icon(Icons.search),
              ), 
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _loading
              ? Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(-23.485733, -46.865479),
                    zoom: 10.0,
                    onTap: (_, __) {},
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: filteredLojas.map((loja) {
                        final devicesDaLoja =
                            _lojas.where((d) => d.siteId == loja.siteId).toList();
                        bool allOnline = devicesDaLoja.isNotEmpty &&
                            devicesDaLoja.every((d) => d.down == 0);
                        bool allOffline = devicesDaLoja.isNotEmpty &&
                            devicesDaLoja.every((d) => d.down == 1);

                        Color iconColor;
                        if (allOnline) {
                          iconColor = Colors.green;
                        } else if (allOffline) {
                          iconColor = Colors.red;
                        } else {
                          iconColor = Colors.yellow;
                        }
                        return Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(loja.lat, loja.lon),
                          child: GestureDetector(
                            onTap: () => _mostrarDetalhes(loja),
                            child: Icon(
                              Icons.location_on,
                              color: iconColor,
                              size: 36,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
          Positioned(
            bottom: 50,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  child: Icon(Icons.add),
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom + 1,
                    );
                  },
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  child: Icon(Icons.remove),
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
