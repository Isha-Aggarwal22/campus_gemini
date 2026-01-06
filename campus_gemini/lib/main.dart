import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirestoreTestPage(),
    );
  }
}

class FirestoreTestPage extends StatefulWidget {
  const FirestoreTestPage({super.key});

  @override
  State<FirestoreTestPage> createState() => _FirestoreTestPageState();
}

class _FirestoreTestPageState extends State<FirestoreTestPage> {
  final TextEditingController _controller = TextEditingController();
  String resultText = '';

  Future<void> checkQuestion(String userQuestion) async {
    if (userQuestion.trim().isEmpty) {
      setState(() {
        resultText = "Please type a question first.";
      });
      return;
    }

    setState(() {
      resultText = "Checking your question...";
    });

    try {
      // 1. Fetch DB questions
      final snapshot = await FirebaseFirestore.instance
          .collection('college_questions')
          .get();

      final dbQuestions =
          snapshot.docs.map((doc) => doc.data()).toList();

      // 2. Call Gemini
      final geminiResponse =
          await askGemini(userQuestion, dbQuestions);

      // 3. Handle response
      if (geminiResponse.trim() != "NO_MATCH") {
        setState(() {
          resultText = geminiResponse;
        });
      } else {
        await FirebaseFirestore.instance
            .collection('unanswered_questions')
            .add({
          'question': userQuestion,
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });

        setState(() {
          resultText =
              "Your question has been forwarded to seniors for review.";
        });
      }
    } catch (e) {
      setState(() {
        resultText = "Error occurred: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Doubt Resolver')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type your doubt here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                checkQuestion(_controller.text);
              },
              child: const Text('Submit'),
            ),
            const SizedBox(height: 20),
            Text(
              resultText,
              style: const TextStyle(fontSize: 16),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------- GEMINI FUNCTION ----------------

Future<String> askGemini(
  String userQuestion,
  List<Map<String, dynamic>> dbQuestions,
) async {
  const apiKey = "AIzaSyA5HPWuI6JrwcswmqBSQbtdzg9lvuVwnFU";

  final dbText = dbQuestions
      .map((q) => "Q: ${q['question']} | A: ${q['answer']}")
      .join("\n");

  final prompt = '''
You are an AI assistant for a college help platform.

A student has asked the following question:
"$userQuestion"

Below is a list of existing college questions with answers:
$dbText

Task:
1. Check if the student question is semantically similar in meaning to any of the existing questions.
2. If a similar question exists, return ONLY the answer of the best matching question.
3. Rewrite the answer in very simple, student-friendly English.
4. If no relevant question exists, respond with exactly: NO_MATCH
''';

  final response = await http.post(
    Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey",
    ),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    }),
  );

  final data = jsonDecode(response.body);

if (data["candidates"] == null) {
  return "AI service unavailable right now.";
}

return data["candidates"][0]["content"]["parts"][0]["text"]
    .toString()
    .trim();
}
