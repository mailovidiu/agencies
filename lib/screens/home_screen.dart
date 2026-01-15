import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/department_provider.dart';
import '../models/department.dart';
import '../providers/auth_provider.dart';
import '../widgets/department_card.dart';
import '../widgets/auth_guard.dart';

import 'admin_screen.dart';
import 'favorites_screen.dart';
import 'department_detail_screen.dart';
import 'category_screen.dart';
import 'department_compare_screen.dart';
import 'profile_screen.dart';

/// Modern home screen with enhanced visual design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSearchResults = false;
  late AnimationController _fabAnimationController;
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DepartmentProvider>().initialize();
    });
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 200 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    } else if (_scrollController.offset <= 200 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _showSearchResults = query.isNotEmpty;
    });
    if (query.isNotEmpty) {
      context.read<DepartmentProvider>().searchDepartments(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<DepartmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.departments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading departments...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(context, provider);
          }

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildModernAppBar(context),
                  if (_showSearchResults) ...[
                    _buildSearchResults(context, provider),
                  ] else ...[
                    _buildHeroSection(context),
                    _buildQuickActionsSection(context),
                    _buildPopularSection(context, provider),
                    _buildPromotionalAdCard(context),
                    _buildCategoriesSection(context, provider),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
              if (_showFab)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: ScaleTransition(
                    scale: _fabAnimationController,
                    child: FloatingActionButton(
                      onPressed: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: const Icon(Icons.arrow_upward),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'US Government',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: false,
          titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        _buildAppBarActions(context),
      ],
    );
  }

  Widget _buildAppBarActions(BuildContext context) {
    return Row(
      children: [
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  authProvider.isAuthenticated && authProvider.isAdmin
                      ? Icons.admin_panel_settings
                      : Icons.login,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthGuard(
                        requireAdmin: true,
                        child: AdminScreen(),
                      ),
                    ),
                  );
                },
                tooltip: authProvider.isAuthenticated && authProvider.isAdmin
                    ? 'Admin Panel'
                    : 'Admin Login',
              ),
            );
          },
        ),
        Consumer<DepartmentProvider>(
          builder: (context, provider, child) {
            final favoriteCount = provider.favoriteDepartments.length;
            return Container(
              margin: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FavoritesScreen(),
                          ),
                        );
                      },
                      tooltip: 'My Favorites',
                    ),
                  ),
                  if (favoriteCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          favoriteCount > 99 ? '99+' : favoriteCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search departments and agencies...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade400),
                          onPressed: () {
                            _searchController.clear();
                            context.read<DepartmentProvider>().clearFilters();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Welcome Text
            Text(
              'Explore Federal Services',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Discover departments, agencies, and services across the US government. Get AI-powered insights and comparisons.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    icon: Icons.compare_arrows,
                    title: 'Compare',
                    subtitle: 'AI-powered insights',
                    gradient: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DepartmentCompareScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    icon: Icons.favorite,
                    title: 'Favorites',
                    subtitle: 'Your saved items',
                    gradient: [
                      const Color(0xFFfa709a),
                      const Color(0xFFfee140),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSection(BuildContext context, DepartmentProvider provider) {
    final popularDepts = provider.popularDepartments;
    
    if (popularDepts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Popular Departments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: popularDepts.length,
              itemBuilder: (context, index) {
                final department = popularDepts[index];
                return Container(
                  width: 300,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildModernPopularCard(context, department, provider),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModernPopularCard(
    BuildContext context, 
    Department department, 
    DepartmentProvider provider,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToDetail(context, department, provider),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getCategoryIcon(department.category),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: provider.isFavorite(department.id)
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          provider.isFavorite(department.id) 
                              ? Icons.favorite 
                              : Icons.favorite_border,
                          color: provider.isFavorite(department.id) 
                              ? Colors.red 
                              : Colors.grey,
                          size: 22,
                        ),
                        onPressed: () => provider.toggleFavorite(department.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  department.shortName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    department.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    department.category.displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionalAdCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4C63D2),
                  Color(0xFF7B68EE),
                  Color(0xFF9B59B6),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Text(
                        'Sponsored',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Utility Tracker — Smart AI Meter Reading & Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  'Track your electricity, water, and gas with just a photo. Get instant AI readings, smart insights, and usage forecasts — all in one app.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _launchUtilityTrackerApp,
                    icon: Icon(
                      defaultTargetPlatform == TargetPlatform.iOS 
                          ? Icons.apple 
                          : Icons.android,
                      size: 20,
                    ),
                    label: Text(
                      defaultTargetPlatform == TargetPlatform.iOS 
                          ? 'View on App Store' 
                          : 'View on Google Play',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4C63D2),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context, DepartmentProvider provider) {
    final categories = provider.getAvailableCategories();
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Browse by Category',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.95, // Increased height relative to width
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final departmentCount = provider.allDepartments
                  .where((dept) => dept.category == category)
                  .length;
              
              return _buildModernCategoryCard(context, category, departmentCount);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernCategoryCard(
    BuildContext context, 
    DepartmentCategory category, 
    int departmentCount,
  ) {
    final colors = _getCategoryGradient(category);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryScreen(category: category),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    category.displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors[0].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$departmentCount dept${departmentCount != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors[0],
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, DepartmentProvider provider) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _searchController.clear();
                      provider.clearFilters();
                      setState(() {
                        _showSearchResults = false;
                      });
                    },
                    tooltip: 'Back',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Results',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${provider.filteredDepartments.length} department${provider.filteredDepartments.length != 1 ? 's' : ''} found',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    provider.clearFilters();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (provider.filteredDepartments.isEmpty)
            _buildEmptySearchState(context)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: provider.filteredDepartments.length,
              itemBuilder: (context, index) {
                final department = provider.filteredDepartments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: DepartmentCard(
                    department: department,
                    isFavorite: provider.isFavorite(department.id),
                    onFavoriteToggle: () => provider.toggleFavorite(department.id),
                    onTap: () => _navigateToDetail(context, department, provider),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No departments found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or browse categories',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DepartmentProvider provider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, Department department, DepartmentProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartmentDetailScreen(department: department),
      ),
    );
  }

  Future<void> _launchUtilityTrackerApp() async {
    final String url = defaultTargetPlatform == TargetPlatform.iOS 
        ? 'https://apps.apple.com/us/app/utility-meter-tracker/id6746415150'
        : 'https://play.google.com/store/apps/details?id=com.trendmobile.metering';
    
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<Color> _getCategoryGradient(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case DepartmentCategory.education:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case DepartmentCategory.transportation:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case DepartmentCategory.finance:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case DepartmentCategory.security:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case DepartmentCategory.environment:
        return [const Color(0xFF00c6ff), const Color(0xFF0072ff)];
      case DepartmentCategory.agriculture:
        return [const Color(0xFF88d3ce), const Color(0xFF6e45e2)];
      case DepartmentCategory.socialServices:
        return [const Color(0xFFfbc2eb), const Color(0xFFa6c1ee)];
      case DepartmentCategory.defense:
        return [const Color(0xFF30cfd0), const Color(0xFF330867)];
      case DepartmentCategory.justice:
        return [const Color(0xFFa8edea), const Color(0xFFfed6e3)];
      case DepartmentCategory.commerce:
        return [const Color(0xFFff9a9e), const Color(0xFFfecfef)];
      case DepartmentCategory.labor:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case DepartmentCategory.energy:
        return [const Color(0xFFffecd2), const Color(0xFFfcb69f)];
      case DepartmentCategory.housing:
        return [const Color(0xFFa1c4fd), const Color(0xFFC2e9fb)];
      case DepartmentCategory.veterans:
        return [const Color(0xFFfbc7d4), const Color(0xFF9796f0)];
      case DepartmentCategory.other:
        return [const Color(0xFFe0c3fc), const Color(0xFF8ec5fc)];
    }
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
        return Icons.attach_money;
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
        return Icons.business;
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