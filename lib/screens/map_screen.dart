import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/department_provider.dart';
import '../models/department.dart';
import 'department_detail_screen.dart';

/// Interactive map screen showing nearby government agencies
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _userPosition;
  bool _loadingLocation = true;
  String? _locationError;
  Department? _selectedDepartment;

  // Default to Washington D.C.
  static const LatLng _defaultCenter = LatLng(38.8977, -77.0365);

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location services disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _loadingLocation = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location permission permanently denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _userPosition = position;
        _loadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          12,
        ),
      );
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'Could not get location';
      });
    }
  }

  Set<Marker> _buildMarkers(List<Department> departments) {
    final markers = <Marker>{};

    for (final dept in departments) {
      final loc = dept.location;
      if (loc == null || loc.latitude == null || loc.longitude == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(dept.id),
          position: LatLng(loc.latitude!, loc.longitude!),
          infoWindow: InfoWindow(
            title: dept.shortName,
            snippet: dept.category.displayName,
            onTap: () {
              setState(() => _selectedDepartment = dept);
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getCategoryHue(dept.category),
          ),
          onTap: () {
            setState(() => _selectedDepartment = dept);
          },
        ),
      );
    }

    return markers;
  }

  double _getCategoryHue(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return BitmapDescriptor.hueRed;
      case DepartmentCategory.education:
        return BitmapDescriptor.hueBlue;
      case DepartmentCategory.transportation:
        return BitmapDescriptor.hueOrange;
      case DepartmentCategory.finance:
        return BitmapDescriptor.hueGreen;
      case DepartmentCategory.security:
        return BitmapDescriptor.hueViolet;
      case DepartmentCategory.environment:
        return BitmapDescriptor.hueCyan;
      case DepartmentCategory.defense:
        return BitmapDescriptor.hueRose;
      case DepartmentCategory.justice:
        return BitmapDescriptor.hueMagenta;
      case DepartmentCategory.veterans:
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1609.34; // miles
  }

  List<Department> _sortByDistance(List<Department> departments) {
    if (_userPosition == null) return departments;

    final withLocation = departments.where((d) =>
        d.location != null &&
        d.location!.latitude != null &&
        d.location!.longitude != null).toList();

    withLocation.sort((a, b) {
      final distA = _calculateDistance(
        _userPosition!.latitude,
        _userPosition!.longitude,
        a.location!.latitude!,
        a.location!.longitude!,
      );
      final distB = _calculateDistance(
        _userPosition!.latitude,
        _userPosition!.longitude,
        b.location!.latitude!,
        b.location!.longitude!,
      );
      return distA.compareTo(distB);
    });

    return withLocation;
  }

  void _openDirections(Department department) async {
    final loc = department.location;
    if (loc == null) return;

    String url;
    if (loc.latitude != null && loc.longitude != null) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}';
    } else {
      url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(loc.formattedAddress)}';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DepartmentProvider>(
        builder: (context, provider, child) {
          final departments = provider.allDepartments
              .where((d) =>
                  d.location != null &&
                  d.location!.latitude != null &&
                  d.location!.longitude != null)
              .toList();

          return Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _userPosition != null
                      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                      : _defaultCenter,
                  zoom: 11,
                ),
                markers: _buildMarkers(departments),
                myLocationEnabled: _userPosition != null,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onTap: (_) {
                  setState(() => _selectedDepartment = null);
                },
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.arrow_back, size: 20),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${departments.length} agencies on map',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_loadingLocation)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  else if (_locationError != null)
                                    Icon(Icons.location_off, color: Colors.grey[400], size: 18)
                                  else
                                    const Icon(Icons.my_location, color: Colors.green, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // My Location FAB
              Positioned(
                right: 16,
                bottom: _selectedDepartment != null ? 230 : 100,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'my_location',
                      backgroundColor: Colors.white,
                      onPressed: () {
                        if (_userPosition != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(_userPosition!.latitude, _userPosition!.longitude),
                              13,
                            ),
                          );
                        } else {
                          _getUserLocation();
                        }
                      },
                      child: Icon(
                        Icons.my_location,
                        color: _userPosition != null ? Colors.blue : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'fit_all',
                      backgroundColor: Colors.white,
                      onPressed: () {
                        if (departments.isNotEmpty) {
                          _fitAllMarkers(departments);
                        }
                      },
                      child: const Icon(Icons.zoom_out_map, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // Bottom list
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomSheet(departments, provider),
              ),

              // Selected department card
              if (_selectedDepartment != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 100,
                  child: _buildSelectedCard(_selectedDepartment!, provider),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomSheet(List<Department> departments, DepartmentProvider provider) {
    final sorted = _sortByDistance(departments);

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final dept = sorted[index];
                String? distanceText;
                if (_userPosition != null) {
                  final dist = _calculateDistance(
                    _userPosition!.latitude,
                    _userPosition!.longitude,
                    dept.location!.latitude!,
                    dept.location!.longitude!,
                  );
                  distanceText = '${dist.toStringAsFixed(1)} mi';
                }

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDepartment = dept);
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(dept.location!.latitude!, dept.location!.longitude!),
                        14,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDepartment?.id == dept.id
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedDepartment?.id == dept.id
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dept.shortName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _selectedDepartment?.id == dept.id
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black87,
                          ),
                        ),
                        if (distanceText != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            distanceText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCard(Department department, DepartmentProvider provider) {
    String? distanceText;
    if (_userPosition != null && department.location != null) {
      final dist = _calculateDistance(
        _userPosition!.latitude,
        _userPosition!.longitude,
        department.location!.latitude!,
        department.location!.longitude!,
      );
      distanceText = '${dist.toStringAsFixed(1)} miles away';
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(department.category),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        department.shortName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        department.category.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedDepartment = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (department.location != null)
              Text(
                department.location!.formattedAddress,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (distanceText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 14, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(
                      distanceText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openDirections(department),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Directions'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DepartmentDetailScreen(department: department),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
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

  void _fitAllMarkers(List<Department> departments) {
    if (departments.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final dept in departments) {
      final lat = dept.location!.latitude!;
      final lng = dept.location!.longitude!;
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
    }

    // Include user position
    if (_userPosition != null) {
      minLat = min(minLat, _userPosition!.latitude);
      maxLat = max(maxLat, _userPosition!.latitude);
      minLng = min(minLng, _userPosition!.longitude);
      maxLng = max(maxLng, _userPosition!.longitude);
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  IconData _getCategoryIcon(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return Icons.health_and_safety;
      case DepartmentCategory.education:
        return Icons.school;
      case DepartmentCategory.transportation:
        return Icons.directions_car;
      case DepartmentCategory.finance:
        return Icons.account_balance;
      case DepartmentCategory.security:
        return Icons.security;
      case DepartmentCategory.environment:
        return Icons.eco;
      case DepartmentCategory.agriculture:
        return Icons.agriculture;
      case DepartmentCategory.socialServices:
        return Icons.people;
      case DepartmentCategory.defense:
        return Icons.shield;
      case DepartmentCategory.justice:
        return Icons.gavel;
      case DepartmentCategory.commerce:
        return Icons.store;
      case DepartmentCategory.labor:
        return Icons.work;
      case DepartmentCategory.energy:
        return Icons.bolt;
      case DepartmentCategory.housing:
        return Icons.home;
      case DepartmentCategory.veterans:
        return Icons.military_tech;
      case DepartmentCategory.other:
        return Icons.category;
    }
  }
}
