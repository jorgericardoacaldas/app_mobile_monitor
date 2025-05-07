import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(home: MapaLojasPage()));
}

class Loja {
  final String siteId;
  final List<DeviceGroup> deviceGroups;
  final String siteName;
  final double lat;
  final double lon;
  final String cityName;
  final String regionName;

  Loja({
    required this.siteId,
    required this.deviceGroups,
    required this.siteName,
    required this.lat,
    required this.lon,
    required this.cityName,
    required this.regionName,
  });

  factory Loja.fromJson(Map<String, dynamic> json) {
    List<DeviceGroup> groups =
        (json['deviceGroups'] as List)
            .map((g) => DeviceGroup.fromJson(g))
            .toList();

    final firstDevice = groups.first.devices.first;
    return Loja(
      siteId: json['siteId'].toString(),
      deviceGroups: groups,
      siteName: firstDevice.siteName,
      lat: firstDevice.lat,
      lon: firstDevice.lon,
      cityName: firstDevice.cityName,
      regionName: firstDevice.regionName,
    );
  }
}

class DeviceGroup {
  final String deviceArea;
  final List<LojaDevice> devices;

  DeviceGroup({required this.deviceArea, required this.devices});

  factory DeviceGroup.fromJson(Map<String, dynamic> json) {
    return DeviceGroup(
      deviceArea: json['deviceArea'],
      devices:
          (json['devices'] as List).map((d) => LojaDevice.fromJson(d)).toList(),
    );
  }
}

class LojaDevice {
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

  LojaDevice({
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

  factory LojaDevice.fromJson(Map<String, dynamic> json) {
    final geo = json['geo_loc'];
    return LojaDevice(
      siteId: json['site_id'].toString(),
      siteName: json['site_name'],
      deviceArea: json['device_area'],
      deviceType: json['device_type'],
      deviceName: json['device_name'],
      down: json['down'],
      lastSeen: DateTime.parse(json['timestamp']),
      lat: (geo['lat'] as num).toDouble(),
      lon: (geo['lon'] as num).toDouble(),
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
    try {
      final lojas = await fetchLojas();
      setState(() {
        _lojas = lojas;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<List<Loja>> fetchLojas() async {
    final response = await http.get(
      Uri.parse('http://localhost:5021/api/Monitoring/all'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> lojasData = json.decode(response.body);
      return lojasData.map((json) => Loja.fromJson(json)).toList();
    } else {
      throw Exception('Erro ao carregar lojas');
    }
  }

  void _mostrarDetalhes(Loja loja) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Padding(
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
                  // Itera nos grupos (deviceArea)
                  ...loja.deviceGroups.map((group) {
                    // Separa dispositivos online e offline do grupo
                    final onlineDevices =
                        group.devices.where((d) => d.down == 0).toList();
                    final offlineDevices =
                        group.devices.where((d) => d.down == 1).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.deviceArea,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (onlineDevices.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            "Dispositivos Online",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ...onlineDevices.map(
                            (device) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(device.deviceName),
                              subtitle: Text(device.deviceType),
                            ),
                          ),
                        ],
                        if (offlineDevices.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            "Dispositivos Offline",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ...offlineDevices.map(
                            (device) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(device.deviceName),
                              subtitle: Text(device.deviceType),
                            ),
                          ),
                        ],
                        SizedBox(height: 16),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
    );
  }

  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final filteredLojas =
        _lojas
            .where((loja) => _search.isEmpty || loja.siteId.contains(_search))
            .toList();

    // Filtrar lojas online, offline e parcialmente online
    _lojas.where((loja) {
      final allDevices = loja.deviceGroups.expand((group) => group.devices);
      return allDevices.isNotEmpty &&
          allDevices.every((device) => device.down == 0);
    }).toList();

    _lojas.where((loja) {
      final allDevices = loja.deviceGroups.expand((group) => group.devices);
      return allDevices.isNotEmpty &&
          allDevices.every((device) => device.down == 1);
    }).toList();

    _lojas.where((loja) {
      final allDevices =
          loja.deviceGroups.expand((group) => group.devices).toList();
      if (allDevices.isEmpty) return false;
      final hasOnline = allDevices.any((device) => device.down == 0);
      final hasOffline = allDevices.any((device) => device.down == 1);
      return hasOnline && hasOffline;
    }).toList();

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
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Lojas',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Filtro por Loja ID',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
            ),
            // Lojas Online
            ListTile(
              title: Text(
                'Lojas Online (${filteredLojas.where((loja) {
                  final allDevices = loja.deviceGroups.expand((group) => group.devices);
                  return allDevices.isNotEmpty && allDevices.every((device) => device.down == 0);
                }).length})',
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ...filteredLojas
                .where((loja) {
                  final allDevices = loja.deviceGroups.expand(
                    (group) => group.devices,
                  );
                  return allDevices.isNotEmpty &&
                      allDevices.every((device) => device.down == 0);
                })
                .map(
                  (loja) => ListTile(
                    title: Text(loja.siteName),
                    subtitle: Text("${loja.cityName}/${loja.regionName}"),
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarDetalhes(loja);
                    },
                  ),
                ),
            Divider(),
            // Lojas parcialmente online
            ListTile(
              title: Text(
                'Lojas Parcialmente Online (${filteredLojas.where((loja) {
                  final allDevices = loja.deviceGroups.expand((group) => group.devices).toList();
                  if (allDevices.isEmpty) return false;
                  final hasOnline = allDevices.any((device) => device.down == 0);
                  final hasOffline = allDevices.any((device) => device.down == 1);
                  return hasOnline && hasOffline;
                }).length})',
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ...filteredLojas
                .where((loja) {
                  final allDevices =
                      loja.deviceGroups
                          .expand((group) => group.devices)
                          .toList();
                  if (allDevices.isEmpty) return false;
                  final hasOnline = allDevices.any(
                    (device) => device.down == 0,
                  );
                  final hasOffline = allDevices.any(
                    (device) => device.down == 1,
                  );
                  return hasOnline && hasOffline;
                })
                .map(
                  (loja) => ListTile(
                    title: Text(loja.siteName),
                    subtitle: Text("${loja.cityName}/${loja.regionName}"),
                    leading: Icon(Icons.error, color: Colors.yellow),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarDetalhes(loja);
                    },
                  ),
                ),
            Divider(),
            // Lojas Offline
            ListTile(
              title: Text(
                'Lojas Offline (${filteredLojas.where((loja) {
                  final allDevices = loja.deviceGroups.expand((group) => group.devices);
                  return allDevices.isNotEmpty && allDevices.every((device) => device.down == 1);
                }).length})',
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ...filteredLojas
                .where((loja) {
                  final allDevices = loja.deviceGroups.expand(
                    (group) => group.devices,
                  );
                  return allDevices.isNotEmpty &&
                      allDevices.every((device) => device.down == 1);
                })
                .map(
                  (loja) => ListTile(
                    title: Text(loja.siteName),
                    subtitle: Text("${loja.cityName}/${loja.regionName}"),
                    leading: Icon(Icons.error, color: Colors.red),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarDetalhes(loja);
                    },
                  ),
                ),
          ],
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
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers:
                        filteredLojas.map((loja) {
                          List<LojaDevice> allDevices =
                              loja.deviceGroups
                                  .expand((group) => group.devices)
                                  .toList();
                          bool allOnline =
                              allDevices.isNotEmpty &&
                              allDevices.every((d) => d.down == 0);
                          bool allOffline =
                              allDevices.isNotEmpty &&
                              allDevices.every((d) => d.down == 1);
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
