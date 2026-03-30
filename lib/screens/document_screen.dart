// ignore_for_file: dead_code, unnecessary_null_comparison, dead_null_aware_expression, prefer_final_fields

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_docs_clone/colors.dart';
import 'package:google_docs_clone/models/document_model.dart';
import 'package:google_docs_clone/models/error_model.dart';
import 'package:routemaster/routemaster.dart';

import '../repository/auth_repository.dart';
import '../repository/document_repository.dart';
import '../repository/socket_repositary.dart';

class DocumentScreen extends ConsumerStatefulWidget {
  final String id;
  const DocumentScreen({super.key, required this.id});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  TextEditingController titleController = TextEditingController(
    text: 'Untitled Document',
  );
  quill.QuillController _controller = quill.QuillController.basic();
  ErrorModel? errorModel;
  SocketRepository socketRepository = SocketRepository();

  @override
  void initState() {
    super.initState();

    socketRepository.joinRoom(widget.id);
    fetchDocumentData();

    socketRepository.changeListener((data) {
      _controller.compose(
        quill.Document.fromJson(data['delta']).toDelta(),
        _controller.selection ?? const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.remote,
      );
    });

    Timer.periodic(const Duration(seconds: 2), (timer) {
      socketRepository.autoSave(<String, dynamic>{
        'delta': _controller.document.toDelta(),
        'room': widget.id,
      });
    });
  }

  void fetchDocumentData() async {
    ErrorModel errorModel = await ref
        .read(documentRepositoryProvider)
        .getDocumentById(ref.read(userProvider)!.token, widget.id);

    if (errorModel.data != null) {
      titleController.text = (errorModel.data as DocumentModel).title;
      _controller = quill.QuillController(
        document: errorModel.data.content.isEmpty
            ? quill.Document()
            : quill.Document.fromDelta(
                quill.Document.fromJson(errorModel.data.content).toDelta(),
              ),
        selection: const TextSelection.collapsed(offset: 0),
      );
      setState(() {});
    }
    _controller.document.changes.listen((event) {
      if (event.source == quill.ChangeSource.local) {
        Map<String, dynamic> map = {'delta': event.change, 'room': widget.id};
        socketRepository.typing(map);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void updateTitle(WidgetRef ref, String title) {
    ref
        .read(documentRepositoryProvider)
        .updateTitle(
          token: ref.read(userProvider)!.token,
          id: widget.id,
          title: title,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(body: CupertinoActivityIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kWhiteColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: 'http://localhost:3000/#/document/${widget.id}',
                  ),
                ).then((value) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied!')));
                });
              },
              icon: Icon(Icons.lock, size: 16, color: kWhiteColor),
              label: Text('Share', style: TextStyle(color: kWhiteColor)),
              style: ElevatedButton.styleFrom(backgroundColor: kBlueColor),
            ),
          ),
        ],
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Routemaster.of(context).replace('/');
                },
                child: Image.asset('assets/images/docs-logo.png', height: 40),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: kBlueColor),
                    ),
                    contentPadding: EdgeInsets.only(left: 10),
                  ),
                  onSubmitted: (value) => updateTitle(ref, value),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: kGreyColor, width: 0.1),
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            quill.QuillSimpleToolbar(controller: _controller),
            Expanded(
              child: SizedBox(
                width: 750,
                child: Card(
                  elevation: 5,
                  color: kWhiteColor,
                  child: quill.QuillEditor.basic(
                    controller: _controller,
                    config: quill.QuillEditorConfig(
                      padding: const EdgeInsets.all(30),
                      placeholder: 'Start writing your document...',
                    ),
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
