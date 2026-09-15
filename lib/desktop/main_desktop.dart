import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../app/theme.dart';
import '../app/theme_controller.dart';
import '../data/services/api_service.dart';
import '../data/services/history_service.dart';
import '../data/services/settings_service.dart';
import '../data/services/progress_service.dart';
import '../data/repositories/video_repository.dart';
import 'desktop_controller.dart';
import 'desktop_tray_page.dart';

const _kWidth = 380.0;
const _kHeight = 600.0;
const _trayPort = 21987;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    print('FLUTTER ERROR: ${details.exception}');
    print('STACK: ${details.stack}');
  };

  try {
    await windowManager.ensureInitialized();

  final themeController = ThemeController();
  await themeController.load();

  final settingsService = SettingsService();
  await settingsService.load();

  final apiService = ApiService(
    settingsService.apiUrl,
    mode: settingsService.contentMode,
  );
  final videoRepository = VideoRepository(apiService);
  final historyService = HistoryService();
  final progressService = ProgressService();

  final controller = DesktopController(
    repository: videoRepository,
    historyService: historyService,
    progressService: progressService,
  );

  WindowOptions windowOptions = WindowOptions(
    size: Size(_kWidth, _kHeight),
    minimumSize: Size(_kWidth, _kHeight),
    maximumSize: Size(_kWidth, _kHeight),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Start hidden — shown by tray click or socket
  });

  if (Platform.isLinux) {
    _startTcpServer(controller);
    _startTrayHelper();
  }

  runApp(DesktopApp(
    controller: controller,
    themeController: themeController,
  ));
  } catch (e, s) {
    print('MAIN ERROR: $e\n$s');
  }
}

void _startTrayHelper() {
  final scriptPath = '${Directory.current.path}/lib/desktop/tray_helper.py';
  if (File(scriptPath).existsSync()) {
    Process.start('python3', [scriptPath],
      mode: ProcessStartMode.detached,
    ).then((process) {
      process.stdout.transform(utf8.decoder).listen((data) {});
      process.stderr.transform(utf8.decoder).listen((data) {});
    }).catchError((_) {});
  }
}

void _startTcpServer(DesktopController controller) {
  ServerSocket.bind('127.0.0.1', _trayPort).then((server) {
    server.listen((client) {
      client.listen((data) {
        if (data.length < 4) return;
        final msgLen = data.buffer.asByteData().getUint32(0);
        if (data.length < 4 + msgLen) return;
        final msg = utf8.decode(data.sublist(4, 4 + msgLen));
        final json = jsonDecode(msg) as Map<String, dynamic>;
        final action = json['action'] as String?;
        if (action == 'toggle') {
          _toggleWindow();
        } else if (action == 'quit') {
          controller.dispose();
          windowManager.destroy();
          exit(0);
        }
      });
    });
  }).catchError((_) {
    Future.delayed(const Duration(seconds: 1), () => _startTcpServer(controller));
  });
}

void _toggleWindow() async {
  final visible = await windowManager.isVisible();
  if (visible) {
    await windowManager.hide();
  } else {
    await windowManager.show();
    await windowManager.focus();
    final display = await screenRetriever.getPrimaryDisplay();
    final screenWidth = display.visibleSize?.width ?? display.size.width;
    await windowManager.setPosition(
      Offset(screenWidth - _kWidth - 16, 40),
    );
  }
}

class DesktopApp extends StatelessWidget {
  final DesktopController controller;
  final ThemeController themeController;

  const DesktopApp({
    super.key,
    required this.controller,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'YouFree',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: _DesktopScaffold(
            controller: controller,
            themeController: themeController,
          ),
        );
      },
    );
  }
}

class _DesktopScaffold extends StatefulWidget {
  final DesktopController controller;
  final ThemeController themeController;

  const _DesktopScaffold({
    required this.controller,
    required this.themeController,
  });

  @override
  State<_DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<_DesktopScaffold> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _minimize() async {
    await windowManager.hide();
  }

  Future<void> _close() async {
    widget.controller.dispose();
    await windowManager.destroy();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildTitleBar(c),
          Expanded(
            child: DesktopTrayPage(controller: widget.controller),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(AppPalette c) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _minimize,
      child: Container(
        height: 32,
        color: c.surface,
        child: Row(
          children: [
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset('assets/youfree.png', width: 18, height: 18),
            ),
            const SizedBox(width: 6),
            Text(
              'YouFree',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
              ),
            ),
            const Spacer(),
            _TitleBtn(
              icon: Icons.remove_rounded,
              onTap: _minimize,
            ),
            _TitleBtn(
              icon: Icons.dark_mode_rounded,
              size: 14,
              onTap: () => widget.themeController.toggle(),
            ),
            _TitleBtn(
              icon: Icons.close_rounded,
              onTap: _close,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _TitleBtn({
    required this.icon,
    required this.onTap,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: size),
        color: Colors.white54,
        onPressed: onTap,
        splashRadius: 14,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
