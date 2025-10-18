import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Tutorial video data model
class TutorialVideo {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String videoId; // YouTube video ID
  final List<String> features;

  TutorialVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.videoId,
    required this.features,
  });
}

class AppTutorialPage extends StatefulWidget {
  const AppTutorialPage({super.key});

  @override
  State<AppTutorialPage> createState() => _AppTutorialPageState();
}

class _AppTutorialPageState extends State<AppTutorialPage> {
  // Tutorial video data - replace with your actual YouTube video IDs
  final List<TutorialVideo> tutorialVideos = [
    TutorialVideo(
      id: "dashboard_tutorial",
      title: "Dashboard",
      description: "Learn how to navigate and use the main dashboard",
      icon: Icons.dashboard_outlined,
      videoId: "j5QXvMb9X7g",
      features: [
        "View your dashboard overview",
        "Check inventory status",
        "See expired and expiring supplies",
        "Track fast moving supplies",
      ],
    ),
    TutorialVideo(
      id: "inventory_tutorial",
      title: "Inventory",
      description: "Learn how to manage your supplies and inventory",
      icon: Icons.inventory_2_outlined,
      videoId: "OVBDjVaSN0M",
      features: [
        "Add and Edit supplies ",
        "Check archived and expired supplies",
        "Add and Edit Categories",
        "Manage Brands and Suppliers",
      ],
    ),
    TutorialVideo(
      id: "purchase_order_tutorial",
      title: "Purchase Orders",
      description: "Create and manage purchase orders for your supplies",
      icon: Icons.shopping_cart_outlined,
      videoId: "zbc_HnTr-8M", // Replace with your YouTube video ID
      features: [
        "Creation of Purchase Orders",
        "Add supplies to PO",
        "Track PO status",
        "Receive Orders",
      ],
    ),
    TutorialVideo(
      id: "stock_deduction_tutorial",
      title: "Stock Deduction",
      description: "Deduct stock and manage presets",
      icon: Icons.remove_circle_outlined,
      videoId: "J11NGGS8buQ",
      features: [
        "Deduct supplies from inventory",
        "Create preset templates",
        "Undo deductions",
        "Update stock counts",
      ],
    ),
    TutorialVideo(
      id: "activity_log_tutorial",
      title: "Activity Log",
      description: "Monitor all activities and changes in your app",
      icon: Icons.history_outlined,
      videoId: "T5t8dSb35zg",
      features: [
        "View recent activities",
        "Filter by category",
        "Track user actions",
        "Realtime updates",
      ],
    ),
    TutorialVideo(
      id: "settings_tutorial",
      title: "Settings",
      description: "Configure your app and manage user access",
      icon: Icons.settings_outlined,
      videoId: "RANpaLeww8M",
      features: [
        "Configure app setttings",
        "Set up preferred notifications",
        "Manage User Accounts",
        "Backup and restore data",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
          onPressed: () {
            Navigator.maybePop(context);
          },
        ),
        title: const Text(
          "App Tutorial",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
            color: null,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 768 ? 8.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section (without panel)
              _buildWelcomeSection(theme, scheme),

              const SizedBox(height: 32),

              // Tutorial Sections - Generated from video data
              ...tutorialVideos.map((video) => Column(
                    children: [
                      _buildTutorialSection(theme, scheme, video),
                      const SizedBox(height: 24),
                    ],
                  )),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome to Familee Dental",
          style: AppFonts.sfProStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Learn how to use all the features of your dental practice management app",
          style: AppFonts.sfProStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialSection(
    ThemeData theme,
    ColorScheme scheme,
    TutorialVideo video,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.black)
                .withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  video.icon,
                  size: 24,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: AppFonts.sfProStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.description,
                      style: AppFonts.sfProStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Video Player (if video ID is available)
          if (video.videoId.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showVideoPlayer(context, video),
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  color: theme.dividerColor.withOpacity(0.1),
                ),
                child: Stack(
                  children: [
                    // Video thumbnail placeholder
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            size: 80,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Tap to play video",
                            style: AppFonts.sfProStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Features list
          ...video.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: AppFonts.sfProStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // Show YouTube video player in a dialog
  void _showVideoPlayer(BuildContext context, TutorialVideo video) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _VideoPlayerDialog(video: video);
      },
    );
  }
}

// Separate widget for video player dialog to handle lifecycle properly
class _VideoPlayerDialog extends StatefulWidget {
  final TutorialVideo video;

  const _VideoPlayerDialog({required this.video});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.videoId,
      flags: const YoutubePlayerFlags(
        forceHD: true,
        enableCaption: true,
        controlsVisibleAtStart: true,
        startAt: 0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Stack(
          children: [
            // Video Player - Full screen
            Positioned.fill(
              child: YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Theme.of(context).primaryColor,
                  onReady: () {
                    // Player is ready - force HD quality
                    _controller.setVolume(100);
                  },
                  onEnded: (data) {
                    // Video ended
                  },
                  bottomActions: [
                    CurrentPosition(),
                    ProgressBar(isExpanded: true),
                    RemainingDuration(),
                    PlaybackSpeedButton(),
                    FullScreenButton(),
                  ],
                ),
                builder: (context, player) {
                  return player;
                },
              ),
            ),
            // Close button overlay
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
