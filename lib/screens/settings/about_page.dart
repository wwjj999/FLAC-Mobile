import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotiflac_android/constants/app_info.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsing App Bar with back button
          SliverAppBar(
            expandedHeight: 120 + topPadding,
            collapsedHeight: kToolbarHeight,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = 120 + topPadding;
                final minHeight = kToolbarHeight + topPadding;
                final expandRatio = ((constraints.maxHeight - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);
                final animation = AlwaysStoppedAnimation(expandRatio);
                return FlexibleSpaceBar(
                  expandedTitleScale: 1.0,
                  titlePadding: EdgeInsets.zero,
                  title: SafeArea(
                    child: Container(
                      alignment: Alignment.bottomLeft,
                      padding: EdgeInsets.only(
                        left: Tween<double>(begin: 56, end: 24).evaluate(animation),
                        bottom: Tween<double>(begin: 12, end: 16).evaluate(animation),
                      ),
                      child: Text('About',
                        style: TextStyle(
                          fontSize: Tween<double>(begin: 20, end: 28).evaluate(animation),
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // App info card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(Icons.music_note, size: 32, color: colorScheme.onPrimaryContainer)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(AppInfo.appName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text('v${AppInfo.version}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSecondaryContainer)),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),

          // GitHub section
          SliverToBoxAdapter(child: _SectionHeader(title: 'GitHub')),
          SliverList(delegate: SliverChildListDelegate([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.phone_android, color: colorScheme.onSurfaceVariant),
              title: Text('${AppInfo.appName} Mobile'),
              subtitle: Text('github.com/${AppInfo.githubRepo}'),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: () => _launchUrl(AppInfo.githubUrl),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.computer, color: colorScheme.onSurfaceVariant),
              title: Text('Original ${AppInfo.appName}'),
              subtitle: Text('github.com/${AppInfo.originalAuthor}/SpotiFLAC'),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: () => _launchUrl(AppInfo.originalGithubUrl),
            ),
          ])),

          // Credits section
          SliverToBoxAdapter(child: _SectionHeader(title: 'Credits')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                _CreditRow(label: 'Mobile Version', value: AppInfo.mobileAuthor),
                const SizedBox(height: 12),
                _CreditRow(label: 'Original Project', value: AppInfo.originalAuthor),
              ]),
            ),
          ),

          // Copyright
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(AppInfo.copyright,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
  );
}

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;
  const _CreditRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }
}
