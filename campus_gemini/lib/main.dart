import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      home: CampusDoubtPage(),
    );
  }
}

class CampusDoubtPage extends StatefulWidget {
  const CampusDoubtPage({super.key});

  @override
  State<CampusDoubtPage> createState() => _CampusDoubtPageState();
}

class _CampusDoubtPageState extends State<CampusDoubtPage> {
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
      // 1. Fetch verified questions from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('college_questions')
          .get();

      final dbQuestions =
          snapshot.docs.map((doc) => doc.data()).toList();

      bool matchFound = false;

      // 2. AI-inspired semantic matching (simple & stable)
      for (var q in dbQuestions) {
        final dbQuestion = q['question'].toString().toLowerCase();
        final userQ = userQuestion.toLowerCase();

        if (dbQuestion.contains(userQ) || userQ.contains(dbQuestion)) {
          setState(() {
            resultText = q['answer'];
          });
          matchFound = true;
          break;
        }
      }

      // 3. Route unanswered questions to seniors
      if (!matchFound) {
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
        resultText = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Doubt Resolver'),
      ),
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
            ),
          ],
        ),
      ),
    );
  }
}
