// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'client/core/logging.dart';
import 'client/core/theme/theme.dart';
import 'client/features/ai/ai_provider.dart';

const _appTitle = 'Restaurant Finder';
const _inputPlaceholder = 'Top 5 Chinese restaurants in New York.';
const _loadingTexts = [
  'Finding the best spots for you...',
  'Checking reviews...',
  'Looking for open tables...',
  'Almost there...',
];

void main() {
  initLogging();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: RestaurantFinderPage(
        onToggleTheme: () => setState(
          () => _themeMode = _themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      ),
    );
  }
}

class RestaurantFinderPage extends StatefulWidget {
  const RestaurantFinderPage({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<RestaurantFinderPage> createState() => _RestaurantFinderPageState();
}

class _RestaurantFinderPageState extends State<RestaurantFinderPage> {
  AiClientState? _aiState;
  Object? _initError;
  bool _hasSentMessage = false;
  int _loadingIdx = 0;
  Timer? _loadingTimer;
  final _inputCtrl = TextEditingController(text: _inputPlaceholder);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final AiClientState state = await Ai().build();
      if (!mounted) return;
      setState(() => _aiState = state);
      state.conversation.state.addListener(_onConversationState);
    } catch (e) {
      appLogger.severe('Failed to initialize AI client: $e');
      if (mounted) setState(() => _initError = e);
    }
  }

  void _onConversationState() {
    if (!mounted) return;
    final bool isWaiting = _aiState!.conversation.state.value.isWaiting;
    if (isWaiting) {
      _loadingIdx = 0;
      _loadingTimer?.cancel();
      _loadingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          setState(
            () => _loadingIdx = (_loadingIdx + 1) % _loadingTexts.length,
          );
        }
      });
    } else {
      _loadingTimer?.cancel();
      _loadingTimer = null;
    }
    setState(() {});
  }

  Future<void> _send(String text) async {
    print('!!!!! Sending message: $text');
    if (_aiState == null || text.trim().isEmpty) return;
    // Clear existing surfaces before sending a new request.
    final List<String> ids = List.of(
      _aiState!.surfaceController.activeSurfaceIds,
    );
    for (final String id in ids) {
      _aiState!.surfaceController.handleMessage(DeleteSurface(surfaceId: id));
    }
    setState(() => _hasSentMessage = true);
    await _aiState!.conversation.sendRequest(ChatMessage.user(text));
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _inputCtrl.dispose();
    _aiState?.conversation.state.removeListener(_onConversationState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildBody(context),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _buildThemeToggle(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_initError != null) {
      return _buildError(context);
    }

    if (_aiState == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<ConversationState>(
      valueListenable: _aiState!.conversation.state,
      builder: (context, state, _) {
        if (state.isWaiting) {
          return _buildLoading(context);
        }
        if (state.surfaces.isNotEmpty) {
          return _buildSurfaces(state.surfaces);
        }
        if (_hasSentMessage) {
          // Sent a message but no surfaces yet — show nothing.
          return const SizedBox.shrink();
        }
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1280 / 720,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.secondaryContainer],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _appTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: cs.primary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide(color: cs.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                ),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _send(_inputCtrl.text),
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _loadingTexts[_loadingIdx],
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaces(List<String> surfaceIds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: surfaceIds
          .map(
            (id) => Surface(
              key: ValueKey(id),
              surfaceContext: _aiState!.surfaceController.contextFor(id),
            ),
          )
          .toList(),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: IconButton(
        onPressed: widget.onToggleTheme,
        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
        style: IconButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.primary,
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        border: Border.all(color: cs.error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Error initializing: $_initError',
        style: TextStyle(color: cs.onErrorContainer),
      ),
    );
  }
}
