import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../data/services/api_service.dart';
import '../../data/services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  final ApiService apiService;
  final SettingsService settingsService;
  final ThemeController themeController;

  const SettingsPage({
    Key? key,
    required this.apiService,
    required this.settingsService,
    required this.themeController,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _urlController;
  final TextEditingController _cookiesController = TextEditingController();

  Map<String, dynamic>? _status;
  bool _statusLoading = true;
  bool _urlTesting = false;
  bool? _urlTestResult;
  bool _cookiesSaving = false;
  bool _cookiesClearing = false;
  bool _showCookiesPaste = false;

  late int _autoDownloadLimit;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.settingsService.apiUrl);
    _autoDownloadLimit = widget.settingsService.autoDownloadLimit;
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _statusLoading = true);
    final status = await widget.apiService.getStatus();
    if (mounted) setState(() { _status = status; _statusLoading = false; });
  }

  Future<void> _testAndSaveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() { _urlTesting = true; _urlTestResult = null; });
    final ok = await ApiService.checkConnection(url);
    if (!mounted) return;
    if (ok) {
      widget.apiService.updateBaseUrl(url);
      await widget.settingsService.setApiUrl(url);
      _loadStatus();
    }
    setState(() { _urlTesting = false; _urlTestResult = ok; });
  }

  Future<void> _saveCookies() async {
    final content = _cookiesController.text.trim();
    if (content.isEmpty) return;
    setState(() => _cookiesSaving = true);
    final ok = await widget.apiService.uploadCookies(content);
    if (mounted) {
      setState(() { _cookiesSaving = false; });
      if (ok) {
        _cookiesController.clear();
        _showCookiesPaste = false;
        _loadStatus();
      } else {
        _showSnack('Erro ao salvar cookies');
      }
    }
  }

  Future<void> _clearCookies() async {
    setState(() => _cookiesClearing = true);
    await widget.apiService.deleteCookies();
    if (mounted) {
      setState(() => _cookiesClearing = false);
      _loadStatus();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: context.c.text)),
        backgroundColor: context.c.surfaceHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _cookiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Configurações',
          style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Aparência'),
          _buildCard([_buildThemeSection()]),
          const SizedBox(height: 24),
          _buildSectionHeader('Servidor'),
          _buildCard([_buildApiUrlSection()]),
          const SizedBox(height: 24),
          _buildSectionHeader('Downloads automáticos'),
          _buildCard([_buildAutoDownloadSection()]),
          const SizedBox(height: 24),
          _buildSectionHeader('Autenticação YouTube'),
          _buildCard([_buildCookiesSection()]),
          const SizedBox(height: 24),
          _buildDisclaimer(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  Widget _buildThemeSection() {
    final c = context.c;
    return ValueListenableBuilder(
      valueListenable: widget.themeController,
      builder: (context, mode, _) {
        final isDark = widget.themeController.isDark;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Modo escuro',
            style: TextStyle(
                color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            isDark ? 'Tema escuro ativado' : 'Tema claro ativado',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
          value: isDark,
          activeThumbColor: c.primary,
          secondary: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: c.secondary,
          ),
          onChanged: (v) => widget.themeController.setDark(v),
        );
      },
    );
  }

  // ── Auto-download limit ──────────────────────────────────────────────────

  Widget _buildAutoDownloadSection() {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Limite de músicas',
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Text(
                '$_autoDownloadLimit',
                style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: c.primary,
            inactiveTrackColor: c.surfaceHigh,
            thumbColor: c.primary,
            overlayColor: c.primary.withValues(alpha: 0.15),
            trackHeight: 3,
          ),
          child: Slider(
            value: _autoDownloadLimit.toDouble(),
            min: 50,
            max: 1000,
            divisions: 19, // 50-step increments: (1000-50)/50 = 19
            onChanged: (v) {
              setState(() => _autoDownloadLimit = v.round());
            },
            onChangeEnd: (v) async {
              final limit = v.round();
              await widget.settingsService.setAutoDownloadLimit(limit);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('50', style: TextStyle(color: c.textMuted, fontSize: 11)),
            Text('1000',
                style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Quando o limite é atingido, a música menos ouvida (e mais antiga) '
          'é removida automaticamente do disco para dar espaço à nova. '
          'Downloads manuais não são afetados.',
          style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                'AVISO LEGAL',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'O YouFree e sua API são projetos pessoais criados exclusivamente '
            'para fins de estudo e aprendizado de tecnologia. '
            'Não têm nenhuma finalidade comercial e jamais serão distribuídos '
            'ou vendidos. Não armazenam, distribuem nem hospedam qualquer '
            'conteúdo de mídia — todo o áudio e vídeo é transmitido '
            'diretamente dos servidores do YouTube.',
            style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            'O desenvolvedor não se responsabiliza por qualquer uso indevido, '
            'ilegal ou fora do propósito educacional deste aplicativo ou da API. '
            'O uso é de inteira responsabilidade do usuário. '
            'Respeite os Termos de Serviço do YouTube e as leis de '
            'direitos autorais da sua região.',
            style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: context.c.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildApiUrlSection() {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('URL da API', style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          style: TextStyle(color: c.text, fontSize: 14),
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'http://192.168.x.x:8000',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
            filled: true,
            fillColor: c.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() => _urlTestResult = null),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _urlTesting ? null : _testAndSaveUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _urlTesting
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                      : const Text('Testar e salvar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ),
            if (_urlTestResult != null) ...[
              const SizedBox(width: 12),
              Icon(
                _urlTestResult! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: _urlTestResult! ? const Color(0xFF4CAF50) : c.secondary,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                _urlTestResult! ? 'Conectado' : 'Sem resposta',
                style: TextStyle(
                  color: _urlTestResult! ? const Color(0xFF4CAF50) : c.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCookiesSection() {
    final c = context.c;
    if (_statusLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
      );
    }

    final hasCookiesFile = _status?['has_cookies_file'] == true;
    final hasFirefox = _status?['has_firefox'] == true;
    final source = _status?['source'] as String? ?? 'none';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusBadge(source: source),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _sourceDescription(source, hasFirefox),
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: c.textMuted, size: 18),
              onPressed: _loadStatus,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (hasCookiesFile) ...[
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _cookiesClearing ? null : _clearCookies,
              icon: _cookiesClearing
                  ? SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.secondary))
                  : const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Remover cookies', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.secondary,
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ] else ...[
          Text(
            'Cole o conteúdo do seu arquivo cookies.txt para autenticar com o YouTube. '
            'Isso desbloqueia playlists privadas, histórico e recomendações personalizadas.',
            style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (!_showCookiesPaste)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showCookiesPaste = true),
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Colar cookies.txt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.surfaceHigh,
                  foregroundColor: c.text,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            )
          else ...[
            TextField(
              controller: _cookiesController,
              style: TextStyle(color: c.text, fontSize: 12, fontFamily: 'monospace'),
              maxLines: 8,
              minLines: 5,
              decoration: InputDecoration(
                hintText: '# Netscape HTTP Cookie File\n.youtube.com\t...',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 11),
                filled: true,
                fillColor: c.surfaceHigh,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _cookiesSaving ? null : _saveCookies,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _cookiesSaving
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                          : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => setState(() { _showCookiesPaste = false; _cookiesController.clear(); }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textMuted,
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  String _sourceDescription(String source, bool hasFirefox) {
    switch (source) {
      case 'cookies_file':
        return 'Autenticado via cookies.txt';
      case 'firefox':
        return 'Usando cookies do Firefox automaticamente';
      default:
        return hasFirefox
            ? 'Firefox detectado, mas sem cookies válidos'
            : 'Sem autenticação — funcionalidades básicas';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String source;
  const _StatusBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'cookies_file' => ('Autenticado', const Color(0xFF4CAF50)),
      'firefox' => ('Firefox', const Color(0xFF2196F3)),
      _ => ('Anônimo', const Color(0xFF9E9E9E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
