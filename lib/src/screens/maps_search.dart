import 'dart:async';
import 'dart:ui';

import 'package:cleadr/src/services/services.dart';
import 'package:cleadr/src/util/place.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

class MapsSearchScreen extends StatefulWidget {
  final Function(LatLng) onDestinationClicked;
  final Place destinationPlace;

  const MapsSearchScreen({
    super.key,
    required this.onDestinationClicked,
    required this.destinationPlace,
  });

  @override
  State<StatefulWidget> createState() => _MapsSearchScreenState();
}

class _MapsSearchScreenState extends State<MapsSearchScreen> {
  bool _isSearching = false;

  late final TextEditingController _searchBarController;
  late final FocusNode _searchBar;
  late List<Place> _placePredictionsBuffer;
  late List<Place> _placePredictions;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initSearchBar();
  }

  @override
  void dispose() {
    _disposeSearchBar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isSearching
            ? Scaffold(
                body: Column(
                  // Search results
                  children: [
                    Container(
                      height: 130,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _placePredictions.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.06),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.place_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              // Place
                              title: Text(
                                _placePredictions[index].name!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              // Address
                              subtitle: Text(
                                _placePredictions[index].formatted_address ??
                                    "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              onTap: () {
                                _isSearching = false;
                                widget.onDestinationClicked(
                                  LatLng(
                                    latitude: _placePredictions[index].lat!,
                                    longitude: _placePredictions[index].lng!,
                                  ),
                                );
                                _searchBar.unfocus();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            : Container(),

        // Glassmorphic Search bar
        Positioned(
          left: 16,
          right: 16,
          top: 54,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 52,
                decoration: BoxDecoration(
                  color: _isSearching
                      ? Colors.white.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: _isSearching
                        ? Colors.blueAccent.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
            child: Row(
              children: [
                // Back / Logo (Left)
                _isSearching
                    ? IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                        onPressed: () {
                          _searchBar.unfocus();
                          setState(() {});
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 14.0, right: 10.0),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                // Search textfield
                Expanded(
                  child: TextField(
                    controller: _searchBarController,
                    focusNode: _searchBar,
                    decoration: const InputDecoration(
                      hintText: 'Search places, streets...',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    onTap: () {
                      _isSearching = true;
                      setState(() {});
                    },
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        if (kDebugMode) {
                          _debounce?.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 400), () {
                            _fetchPlacePredictions(text);
                          });
                        } else {
                          _fetchPlacePredictions(text);
                        }
                      } else {
                        _placePredictions.clear();
                        setState(() {});
                      }
                    },
                    onEditingComplete: () {
                      if (_searchBarController.text.isNotEmpty) {
                        _fetchPlacePredictions(_searchBarController.text);
                      } else {
                        _placePredictions.clear();
                        setState(() {});
                      }
                    },
                  ),
                ),

                // Cancel / Clear
                _searchBarController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                        onPressed: () {
                          _searchBarController.clear();
                          _placePredictionsBuffer.clear();
                          _placePredictions.clear();
                          setState(() {});
                        },
                      )
                    : const Padding(
                        padding: EdgeInsets.only(right: 14.0),
                        child: Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
);
  }

  void _initSearchBar() {
    _searchBarController = TextEditingController();
    _searchBar = FocusNode();
    _placePredictions = [];
    _searchBar.addListener(() {
      _isSearching = _searchBar.hasFocus;
      setState(() {});
    });
  }

  void _disposeSearchBar() {
    _searchBar.dispose();
    _searchBarController.dispose();
  }

  Future<void> _fetchPlacePredictions(String query) async {
    _placePredictionsBuffer = await Services.fetchPlacePredictions(query);

    if (_searchBarController.text.isNotEmpty) {
      _placePredictions = _placePredictionsBuffer;
    }

    setState(() {});
  }
}
