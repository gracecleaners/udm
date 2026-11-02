import 'package:flutter/material.dart';

void main() => runApp(const UdmApp());

class UdmApp extends StatelessWidget {
  const UdmApp({super.key});

  static const blue = Color(0xFF1769AA);
  static const ink = Color(0xFF182B3A);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'UDM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
          colorScheme: ColorScheme.fromSeed(seedColor: blue),
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: ink),
            titleLarge: TextStyle(fontWeight: FontWeight.bold, color: ink),
            bodyLarge: TextStyle(color: ink, height: 1.5),
          ),
        ),
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: IndexedStack(index: tab, children: const [HomePage(), SimplePage(title: 'Bible'), SimplePage(title: 'Learn'), SimplePage(title: 'Community'), SimplePage(title: 'Profile')]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Bible'),
            NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Community'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: UdmApp.blue, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.auto_stories, color: Colors.white)),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('UDM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: UdmApp.ink)), Text('Know Christ. Grow. Make disciples.', style: TextStyle(fontSize: 12, color: Color(0xFF718096))) ]),
            const Spacer(), IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          ]),
          const SizedBox(height: 24),
          const Text('Good morning', style: TextStyle(color: Color(0xFF718096))),
          const Text('Grow in His Word.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 27, color: UdmApp.ink)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [UdmApp.blue, Color(0xFF123B63)]), borderRadius: BorderRadius.circular(24)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VERSE OF THE DAY', style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.bold)),
              SizedBox(height: 14), Text('“Be transformed by the renewing of your mind.”', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w600, height: 1.35)),
              SizedBox(height: 8), Text('Romans 12:2', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 18), Row(children: [Text('READ SCRIPTURE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: .7)), SizedBox(width: 8), Icon(Icons.arrow_forward, color: Colors.white, size: 18)]),
            ]),
          ),
          const SizedBox(height: 25),
          const _SectionTitle('Continue your journey', action: 'See all'),
          const SizedBox(height: 12),
          const _JourneyCard(icon: Icons.menu_book, title: 'Bible reading', subtitle: 'Continue where you left off', tag: 'John 3'),
          const SizedBox(height: 12),
          const _JourneyCard(icon: Icons.wb_sunny_outlined, title: 'Today’s devotion', subtitle: 'A heart that listens', tag: '5 min'),
          const SizedBox(height: 25),
          const _SectionTitle('Explore discipleship'),
          const SizedBox(height: 12),
          const Row(children: [Expanded(child: _ExploreTile(icon: Icons.favorite_outline, title: 'Prayer')), SizedBox(width: 12), Expanded(child: _ExploreTile(icon: Icons.school_outlined, title: 'Courses'))]),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)), if (action != null) Text(action!, style: const TextStyle(color: UdmApp.blue, fontWeight: FontWeight.w600))]);
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.icon, required this.title, required this.subtitle, required this.tag});
  final IconData icon;
  final String title, subtitle, tag;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: ListTile(contentPadding: const EdgeInsets.all(10), leading: CircleAvatar(backgroundColor: const Color(0xFFEAF4FC), child: Icon(icon, color: UdmApp.blue)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), trailing: Text(tag, style: const TextStyle(color: UdmApp.blue, fontWeight: FontWeight.w600))));
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: UdmApp.blue), const SizedBox(height: 18), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))])));
}

class SimplePage extends StatelessWidget {
  const SimplePage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(child: Text(title, style: Theme.of(context).textTheme.headlineMedium));
}
