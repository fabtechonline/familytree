import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';

/// About screen: app identity, version, developer details and a contact email.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const _email = 'fabtechonline@gmail.com';
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<void> _emailDeveloper() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=${Uri.encodeComponent('Riza app')}',
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/branding/icon_master.png',
                    width: 88,
                    height: 88,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.account_tree_rounded,
                        size: 88,
                        color: AppColors.seed),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Riza',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Your family, beautifully connected',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                if (_version.isNotEmpty)
                  Text('Version $_version',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Developer'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.person_rounded),
              title: Text('Farhad Bux'),
              subtitle: Text('Fabtech Online'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_rounded),
              title: const Text('Contact'),
              subtitle: const Text(_email),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: _emailDeveloper,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Legal'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl('https://www.riza.co.za/privacy'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_rounded),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl('https://www.riza.co.za/terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: Text('© 2026 Farhad Bux. All rights reserved.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
