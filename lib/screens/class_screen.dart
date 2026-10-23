import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class ClassScreen extends StatelessWidget {
  final String userName;
  final String? currentClass;

  const ClassScreen({super.key, required this.userName, this.currentClass});

  Future<void> _selectClass(BuildContext context, String selectedClass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_class', selectedClass);

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          selectedClass: selectedClass,
          userName: userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkVoid = Color(0xFF070B14);
    const goldAccent = Color(0xFFD4AF37);

    final classes = [
      {'title': 'Class 8', 'desc': 'Foundation, Concepts & Practice'},
      {'title': 'Class 9', 'desc': 'Pre-Board Core Concepts & Notes'},
      {'title': 'Class 10th', 'desc': 'Board Exam Mastery, High-Yield Qs'},
      {'title': 'Board Special', 'desc': 'Target Crash Course, Formulas & Mock Tests'},
    ];

    return Scaffold(
      backgroundColor: darkVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SELECT YOUR CLASS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: goldAccent,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $userName 👋',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select your standard to personalize your learning dashboard.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: classes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = classes[index];
                  final isSpecial = item['title'] == 'Board Special';

                  return Container(
                    decoration: BoxDecoration(
                      color: isSpecial 
                          ? goldAccent.withOpacity(0.12) 
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSpecial 
                            ? goldAccent 
                            : goldAccent.withOpacity(0.25),
                        width: isSpecial ? 1.8 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: goldAccent.withOpacity(isSpecial ? 0.15 : 0.05),
                          blurRadius: isSpecial ? 15 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      title: Row(
                        children: [
                          Text(
                            item['title']!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSpecial ? goldAccent : Colors.white,
                            ),
                          ),
                          if (isSpecial) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: goldAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'HOT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          item['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: goldAccent,
                        size: 18,
                      ),
                      onTap: () => _selectClass(context, item['title']!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}