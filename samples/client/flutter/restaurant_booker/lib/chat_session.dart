// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:logging/logging.dart';

import 'message.dart';

final Catalog _catalog = BasicCatalogItems.asCatalog();

/// A class that manages the chat session state and logic.
class ChatSession extends ChangeNotifier {
  ChatSession({required Transport transport}) {
    _transport = transport;
    _surfaceController = SurfaceController(catalogs: [_catalog]);
    conversation = Conversation(
      controller: _surfaceController,
      transport: _transport,
    );
    _init();
  }

  late final Transport _transport;
  late final SurfaceController _surfaceController;
  late final Conversation conversation;

  SurfaceHost get surfaceController => _surfaceController;

  bool get isProcessing => conversation.state.value.isWaiting;

  final List<Message> _messages = [];
  List<Message> get messages => List.unmodifiable(_messages);

  final Logger _logger = Logger('ChatSession');

  void _init() {
    conversation.state.addListener(notifyListeners);

    conversation.events.listen((event) {
      switch (event) {
        case ConversationSurfaceAdded(:final surfaceId):
          _addSurfaceMessage(surfaceId);
        case ConversationContentReceived(:final text):
          _updateAiMessage(text);
        case ConversationError(:final error):
          _logger.severe('Error in conversation', error);
          _messages.add(Message(isUser: false, text: 'Error: $error'));
          notifyListeners();
        case ConversationWaiting():
        case ConversationComponentsUpdated():
        case ConversationSurfaceRemoved():
          break;
      }
    });
  }

  void _addSurfaceMessage(String surfaceId) {
    final bool exists = _messages.any((m) => m.surfaceId == surfaceId);
    if (!exists) {
      _messages.add(Message(isUser: false, text: null, surfaceId: surfaceId));
      notifyListeners();
    }
  }

  Message? _currentAiMessage;

  void _updateAiMessage(String chunk) {
    if (_currentAiMessage == null) {
      _currentAiMessage = Message(isUser: false, text: '');
      _messages.add(_currentAiMessage!);
    }
    _currentAiMessage!.text = (_currentAiMessage!.text ?? '') + chunk;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty) return;

    _currentAiMessage = null;

    _messages.add(Message(isUser: true, text: 'You: $text'));
    notifyListeners();

    final message = ChatMessage.user(text);
    await conversation.sendRequest(message);
  }

  @override
  void dispose() {
    conversation.dispose();
    _surfaceController.dispose();
    _transport.dispose();
    super.dispose();
  }
}
