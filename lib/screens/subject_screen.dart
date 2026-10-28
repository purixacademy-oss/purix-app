import 'package:flutter/material.dart';
import '../services/sheet_service.dart';
import 'sub_subject_screen.dart';

class SubjectScreen extends StatefulWidget {
  final String selectedClass;
  final String mode; // 'mcq', 'practice', ya 'notes'

  const SubjectScreen({
    super.key,
    required this.selectedClass,
    required this.mode,
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  bool _isLoading = true;
  List<String> _subjectsList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _getTargetSheetName() {
    String prefix = "8th";
    if (widget.selectedClass.contains("9")) {
      prefix = "9th";
    } else if (widget.selectedClass.contains("10")) {
      prefix = "10th";
    }

    if (widget.mode == 'mcq') {
      return '$prefix MCQ';
    } else if (widget.mode == 'notes') {
      return '$prefix Notes';
    } else {
      return '$prefix practice pdf';
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final targetSheet = _getTargetSheetName();
    final data = await SheetService.fetchSheetData(targetSheet);

    // केवल यूनिक (Unique) सब्जेक्ट्स की लिस्ट बनाएं ताकि एक सब्जेक्ट बार-बार न दोहराए
    final Set<String> uniqueSubjects = {};
    for (var row in data) {
      final subject = (row['Subject'] ?? row['subject'] ?? '').toString().trim();
      if (subject.isNotEmpty) {
        uniqueSubjects.add(subject);
      }
    }

    if (!mounted) return;
    setState(() {
      _subjectsList = uniqueSubjects.toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const cardBg = Color(0xFF0B111E);
    const neonCyan = Color(0xFF00F0FF);
    const neonGreen = Color(0xFF00FF66);

    String titleText = "${widget.selectedClass} - Subjects";
    Color themeGlow = neonGreen;

    if (widget.mode == 'mcq') {
      titleText = "${widget.selectedClass} - MCQ Tests";
      themeGlow = const Color(0xFF00FF66);
    } else if (widget.mode == 'practice') {
      titleText = "${widget.selectedClass} - Practice Sets";
      themeGlow = const Color(0xFFFF9900);
    } else {
      titleText = "${widget.selectedClass} - Purix Notes";
      themeGlow = const Color(0xFFBF00FF);
    }

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          titleText.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: neonCyan),
            onPressed: _loadInitialData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: neonCyan),
                  SizedBox(height: 16),
                  Text("Loading subjects...", style: TextStyle(color: neonCyan, fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            )
          : _subjectsList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.layers_clear_outlined, color: Colors.white38, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          "NO SUBJECTS FOUND",
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Ensure records exist in sheet: ${_getTargetSheetName()}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  itemCount: _subjectsList.length,
                  itemBuilder: (context, index) {
                    final subject = _subjectsList[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeGlow.withAlpha(76), width: 1.2),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: themeGlow.withAlpha(30),
                          child: Icon(
                            widget.mode == 'mcq'
                                ? Icons.quiz
                                : widget.mode == 'notes'
                                    ? Icons.menu_book
                                    : Icons.hub,
                            color: themeGlow,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          subject.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
                        ),
                        subtitle: Text(
                          "Tap to view chapters & topics",
                          style: TextStyle(color: themeGlow.withAlpha(180), fontSize: 10, fontFamily: 'monospace'),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                        onTap: () {
                          // SubSubjectScreen navigation with correct parameters
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubSubjectScreen(
                                className: widget.selectedClass,
                                subjectName: subject,
                                mode: widget.mode,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}