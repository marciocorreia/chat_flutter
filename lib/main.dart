import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ApplicationState(),
      builder: (context, _) => ChatApp(),
    ),
  );
}

final ThemeData kIOSTheme = ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
);

final ThemeData kDefaultTheme = ThemeData(
    primarySwatch: Colors.purple,
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.purple)
        .copyWith(secondary: Colors.orange));

class ChatApp extends StatelessWidget {
  const ChatApp({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat',
      theme: defaultTargetPlatform == TargetPlatform.iOS
          ? kIOSTheme
          : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
      ),
      body: Container(
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ))
            : null,
        child: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    return Column(
      children: [
        Flexible(
          child: Consumer<ApplicationState>(
            builder: (context, appState, _) => ListView.builder(
              padding: EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder: (_, int index) => appState._chatMessages[index],
              itemCount: appState._chatMessages.length,
            ),
          ),
        ),
        Divider(height: 1.0),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor),
          child: _buildTextComposer(),
        ),
      ],
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Flexible(
            child: Consumer<ApplicationState>(
              builder: (context, appState, _) => TextField(
                controller: _textController,
                focusNode: _focusNode,
                onChanged: (String text) {
                  setState(() {
                    _isComposing = text.isNotEmpty;
                  });
                },
                onSubmitted: _isComposing
                    ? (String text) {
                        appState.addMessageToChat(text);
                        _handledSubmitted(text);
                      }
                    : null,
                decoration:
                    InputDecoration.collapsed(hintText: 'send a message'),
              ),
            ),
          ),
          IconTheme(
            data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
            child: Consumer<ApplicationState>(
              builder: (context, appState, _) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text('Send'),
                        onPressed: _isComposing
                            ? () {
                                appState.addMessageToChat(_textController.text);
                                _handledSubmitted(_textController.text);
                              }
                            : null,
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _isComposing
                            ? () {
                                appState.addMessageToChat(_textController.text);
                                _handledSubmitted(_textController.text);
                              }
                            : null,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handledSubmitted(String text) {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    _focusNode.requestFocus();
  }
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({
    required this.name,
    required this.text,
  });
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              child: Text(name[0]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.headline6),
                Container(
                  margin: EdgeInsets.only(top: 5.0),
                  child: Text(text),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  final String _username = 'Marcio Correia';
  List<ChatMessage> _chatMessages = [];
  List<ChatMessage> get chatMessages => _chatMessages;
  StreamSubscription<QuerySnapshot>? _chatSubscription;

  Future<void> init() async {
    await Firebase.initializeApp();

    _chatSubscription = FirebaseFirestore.instance
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _chatMessages = [];
      snapshot.docs.forEach((document) {
        _chatMessages.add(
          ChatMessage(
            name: document.data()['name'],
            text: document.data()['text'],
          ),
        );
      });
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _chatMessages = [];
    _chatSubscription?.cancel();
    super.dispose();
  }

  Future<DocumentReference> addMessageToChat(String text) {
    return FirebaseFirestore.instance.collection('chat').add(<String, dynamic>{
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'name': _username,
    });
  }
}
