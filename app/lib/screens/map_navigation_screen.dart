import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/user.dart';
import '../models/trip_goal.dart';

// ============================================================
// MAP NAVIGATION SCREEN
// Google Maps + Directions API (cycling mode)
//
// ⚠️  SETUP: Replace 'YOUR_GOOGLE_MAPS_API_KEY' with your key
//    Get key: https://console.cloud.google.com
//    Enable: Maps SDK iOS/Android · Directions API · Places API
//
//    Also add to iOS: ios/Runner/AppDelegate.swift
//      GMSServices.provideAPIKey("YOUR_KEY")
//    And android: android/app/src/main/AndroidManifest.xml
//      <meta-data android:name="com.google.android.geo.API_KEY"
//                 android:value="YOUR_KEY"/>
// ============================================================

const String _kApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
const LatLng  _kUCL   = LatLng(51.5246, -0.1340); // UCL default origin

class MapNavigationScreen extends StatefulWidget {
  final AppUser currentUser;
  final Function(TripGoal)? onGoalSet;
  const MapNavigationScreen({super.key, required this.currentUser, this.onGoalSet});

  @override
  State<MapNavigationScreen> createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  final _mapCompleter = Completer<GoogleMapController>();
  final _searchCtrl   = TextEditingController();
  final _searchFocus  = FocusNode();
  GoogleMapController? _mapCtrl;

  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _suggestions = [];
  bool   _loading       = false;
  bool   _showSuggs     = false;
  double? _distanceKm;
  String  _destName     = '';
  String  _duration     = '';
  LatLng  _origin       = _kUCL;

  // Demo places (used when no real API key)
  static const _demoPlaces = [
    {'name': "Regent's Park",      'lat': 51.5313, 'lng': -0.1570, 'dist': 3.2},
    {'name': 'Hyde Park',          'lat': 51.5073, 'lng': -0.1657, 'dist': 5.8},
    {'name': 'Richmond Park',      'lat': 51.4406, 'lng': -0.2763, 'dist': 18.4},
    {'name': 'Olympic Park',       'lat': 51.5455, 'lng': -0.0160, 'dist': 11.3},
    {'name': 'Hampstead Heath',    'lat': 51.5616, 'lng': -0.1639, 'dist': 6.7},
    {'name': 'Greenwich Park',     'lat': 51.4769, 'lng': -0.0005, 'dist': 10.1},
    {'name': 'Crystal Palace Park','lat': 51.4209, 'lng': -0.0785, 'dist': 14.5},
    {'name': 'Victoria Park',      'lat': 51.5362, 'lng': -0.0383, 'dist': 8.2},
  ];

  @override
  void dispose() { _searchCtrl.dispose(); _searchFocus.dispose(); super.dispose(); }

  void _onSearch(String q) {
    if (q.length < 1) { setState(() { _suggestions = []; _showSuggs = false; }); return; }
    final lower = q.toLowerCase();
    if (_kApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      setState(() {
        _suggestions = _demoPlaces
            .where((p) => (p['name'] as String).toLowerCase().contains(lower))
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        _showSuggs = _suggestions.isNotEmpty;
      });
    } else {
      _livePlacesSearch(q);
    }
  }

  Future<void> _livePlacesSearch(String q) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(q)}&location=51.5246,-0.1340'
      '&radius=60000&key=$_kApiKey',
    );
    try {
      final res = await http.get(url);
      final data = jsonDecode(res.body) as Map;
      setState(() {
        _suggestions = (data['predictions'] as List)
            .take(6)
            .map((p) => {'name': p['description'], 'place_id': p['place_id']})
            .toList();
        _showSuggs = _suggestions.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _selectPlace(Map<String, dynamic> p) async {
    setState(() { _loading = true; _showSuggs = false; });
    _searchCtrl.text = p['name'];
    _searchFocus.unfocus();
    _destName = p['name'];

    if (_kApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      final dest = LatLng(p['lat'] as double, p['lng'] as double);
      final dist = p['dist'] as double;
      _drawDemoRoute(dest, dist);
    } else {
      await _geocodeThenRoute(p['place_id']);
    }
  }

  void _drawDemoRoute(LatLng dest, double dist) {
    setState(() {
      _distanceKm  = dist;
      _duration    = '${(dist / 20 * 60).toInt()} min (cycling est.)';
      _markers = {
        Marker(markerId: const MarkerId('origin'), position: _origin,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: '📍 Start (UCL)')),
        Marker(markerId: const MarkerId('dest'), position: dest,
            infoWindow: InfoWindow(title: '🏁 $_destName')),
      };
      _polylines = {
        Polyline(polylineId: const PolylineId('route'), points: [_origin, dest],
            color: AppTheme.green, width: 4,
            patterns: [PatternItem.dash(18), PatternItem.gap(10)]),
      };
      _loading = false;
    });
    _fitBounds(_origin, dest);
  }

  Future<void> _geocodeThenRoute(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId&fields=geometry&key=$_kApiKey',
    );
    final res  = await http.get(url);
    final data = jsonDecode(res.body) as Map;
    final loc  = data['result']['geometry']['location'];
    await _getDirections(LatLng(loc['lat'], loc['lng']));
  }

  Future<void> _getDirections(LatLng dest) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${_origin.latitude},${_origin.longitude}'
      '&destination=${dest.latitude},${dest.longitude}'
      '&mode=bicycling&key=$_kApiKey',
    );
    try {
      final res  = await http.get(url);
      final data = jsonDecode(res.body) as Map;
      if (data['status'] == 'OK') {
        final leg = data['routes'][0]['legs'][0];
        final pts = _decode(data['routes'][0]['overview_polyline']['points']);
        setState(() {
          _distanceKm = (leg['distance']['value'] as int) / 1000.0;
          _duration   = leg['duration']['text'];
          _markers = {
            Marker(markerId: const MarkerId('o'), position: _origin,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: 'Start')),
            Marker(markerId: const MarkerId('d'), position: dest,
                infoWindow: InfoWindow(title: _destName)),
          };
          _polylines = {
            Polyline(polylineId: const PolylineId('r'),
                points: pts, color: AppTheme.green, width: 5),
          };
          _loading = false;
        });
        _fitBounds(_origin, dest);
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        [a.latitude,  b.latitude ].reduce((x, y) => x < y ? x : y) - 0.01,
        [a.longitude, b.longitude].reduce((x, y) => x < y ? x : y) - 0.01,
      ),
      northeast: LatLng(
        [a.latitude,  b.latitude ].reduce((x, y) => x > y ? x : y) + 0.01,
        [a.longitude, b.longitude].reduce((x, y) => x > y ? x : y) + 0.01,
      ),
    );
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  List<LatLng> _decode(String enc) {
    final pts = <LatLng>[];
    int i = 0, lat = 0, lng = 0;
    while (i < enc.length) {
      int b, s = 0, r = 0;
      do { b = enc.codeUnitAt(i++) - 63; r |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      lat += (r & 1) != 0 ? ~(r >> 1) : (r >> 1);
      s = 0; r = 0;
      do { b = enc.codeUnitAt(i++) - 63; r |= (b & 0x1f) << s; s += 5; } while (b >= 0x20);
      lng += (r & 1) != 0 ? ~(r >> 1) : (r >> 1);
      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  void _setGoal() {
    if (_distanceKm == null) return;
    final goal = TripGoal(
      userId: widget.currentUser.id,
      destinationName: _destName,
      targetDistanceKm: _distanceKm!,
      estimatedDuration: _duration,
      date: DateTime.now(),
    );
    widget.onGoalSet?.call(goal);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🚴 Trip goal set: ${_distanceKm!.toStringAsFixed(1)} km → $_destName'),
      backgroundColor: AppTheme.greenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = _distanceKm != null && !_loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan Your Ride'), backgroundColor: AppTheme.white),
      body: Stack(children: [

        // ── Google Map ──────────────────────────────────────
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: _kUCL, zoom: 13),
          onMapCreated: (c) { _mapCompleter.complete(c); _mapCtrl = c; },
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),

        // ── Search overlay ──────────────────────────────────
        Positioned(top: 12, left: 12, right: 12, child: Column(children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0,4))],
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(color: AppTheme.black),
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Where do you want to ride?',
                prefixIcon: const Icon(Icons.search, color: AppTheme.green),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 18, color: AppTheme.grey),
                        onPressed: () { _searchCtrl.clear();
                          setState(() { _suggestions=[]; _showSuggs=false;
                            _markers={}; _polylines={}; _distanceKm=null; }); })
                    : null,
                filled: false, border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Suggestions dropdown
          if (_showSuggs && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,4))],
              ),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(children: [
                    const Icon(Icons.place, color: AppTheme.green, size: 13),
                    const SizedBox(width: 6),
                    Text(_kApiKey == 'YOUR_GOOGLE_MAPS_API_KEY'
                        ? 'Demo destinations · Add API key for live search'
                        : 'Google Places results',
                        style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
                  ])),
                ..._suggestions.map((s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, color: AppTheme.green, size: 18),
                  title: Text(s['name'], style: const TextStyle(fontSize: 13, color: AppTheme.black)),
                  onTap: () => _selectPlace(s),
                )),
              ]),
            ),
        ])),

        // ── Loading spinner ─────────────────────────────────
        if (_loading) const Center(child: CircularProgressIndicator(color: AppTheme.green)),

        // ── Route result panel ──────────────────────────────
        if (hasRoute)
          Positioned(bottom: 0, left: 0, right: 0, child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: AppTheme.greyLight, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),

              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.greenLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.flag, color: AppTheme.greenDark, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Destination', style: TextStyle(fontSize: 11, color: AppTheme.grey)),
                  Text(_destName, style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14, color: AppTheme.black),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),

              const SizedBox(height: 14),
              Row(children: [
                _statTile(Icons.straighten, '${_distanceKm!.toStringAsFixed(1)} km', 'Distance'),
                const SizedBox(width: 10),
                _statTile(Icons.timer_outlined, _duration, 'Est. Time'),
                const SizedBox(width: 10),
                _statTile(Icons.local_fire_department,
                    '${(_distanceKm! * 35).toInt()} kcal', 'Est. Cal'),
              ]),

              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _setGoal,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text("Set as Today's Trip Goal"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green, foregroundColor: AppTheme.black,
                    shape: const StadiumBorder(), elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('This sets your single-trip goal for today',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey),
                  textAlign: TextAlign.center),
            ]),
          )),
      ]),
    );
  }

  Widget _statTile(IconData icon, String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppTheme.greenLight,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: AppTheme.greenDark, size: 18),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
            color: AppTheme.black), textAlign: TextAlign.center),
        Text(lbl, style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
      ]),
    ),
  );
}
