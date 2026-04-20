// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:genui/genui.dart';
import 'package:genui_a2a/genui_a2a.dart';

/// A [Transport] that sends messages to an A2UI agent via the A2A protocol.
class A2aTransport implements Transport {
  A2aTransport({required String agentUrl})
    : _connector = A2uiAgentConnector(url: Uri.parse(agentUrl));

  final A2uiAgentConnector _connector;

  @override
  Stream<A2uiMessage> get incomingMessages => _connector.stream;

  @override
  Stream<String> get incomingText => _connector.textStream;

  @override
  Future<void> sendRequest(ChatMessage message) async {
    await _connector.connectAndSend(message);
  }

  @override
  void dispose() {
    _connector.dispose();
  }
}
