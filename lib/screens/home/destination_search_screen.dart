import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../models/location_model.dart';
import '../../widgets/custom_text_field.dart';

/// Screen for searching and selecting destination
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _searchController = TextEditingController();
  List<LocationModel> _searchResults = [];
  List<LocationModel> _recentAddresses = [];
  List<LocationModel> _favoriteLocations = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentAndFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecentAndFavorites() {
    setState(() {
      _recentAddresses = StorageService.getRecentAddresses();
      _favoriteLocations = StorageService.getFavoriteLocations();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final location = await LocationService.getCoordinatesFromAddress(query);
      if (location != null) {
        setState(() {
          _searchResults = [location];
        });
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _selectLocation(LocationModel location) async {
    await StorageService.addRecentAddress(location);
    if (mounted) {
      Navigator.of(context).pop(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Destination'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomTextField(
              controller: _searchController,
              hint: 'Search for a place',
              prefixIcon: Icons.search,
            ),
          ),
          // Content
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
                    ),
                  )
                : _searchController.text.isEmpty
                    ? _buildSuggestions()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Favorite locations
        if (_favoriteLocations.isNotEmpty) ...[
          const Text(
            'Favorites',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          ..._favoriteLocations.map((location) => _buildLocationTile(
                location,
                Icons.favorite,
                AppColors.primaryPink,
              )),
          const SizedBox(height: 24),
        ],
        // Recent addresses
        if (_recentAddresses.isNotEmpty) ...[
          const Text(
            'Recent',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          ..._recentAddresses.map((location) => _buildLocationTile(
                location,
                Icons.history,
                AppColors.grey,
              )),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: AppColors.grey),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _searchResults
          .map((location) => _buildLocationTile(
                location,
                Icons.location_on,
                AppColors.primaryPink,
              ))
          .toList(),
    );
  }

  Widget _buildLocationTile(
    LocationModel location,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          location.name ?? location.address,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: location.name != null
            ? Text(location.address)
            : null,
        onTap: () => _selectLocation(location),
      ),
    );
  }
}

