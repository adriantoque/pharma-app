import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What this app is, its version, and the open-source licences it ships under.
///
/// The version is read once in [initState]; under `flutter_test` there is no
/// platform channel behind the plugin, so the lookup is allowed to fail and the
/// row simply omits the number, exactly as the Profile tile does.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (_) {
      // Left null: the screen still reads without a version line.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const Center(child: _AppMark()),
                const SizedBox(height: 16),
                Text(
                  'PharmaGuide',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                if (_version != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Version $_version',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'A pharmacy counter app: a medicine price list, point of sale, '
                  'order approval and reporting, with an offline mode for when '
                  'the connection drops.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Open source licences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'PharmaGuide',
                      applicationVersion: _version,
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
}

/// The launcher mark, drawn from the packaged icon asset.
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/baseIcon.png',
        fit: BoxFit.cover,
        // The asset may not carry an image in a stripped build; the tinted
        // square is what remains, which still reads as the app's mark.
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.local_pharmacy_outlined,
          size: 48,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
