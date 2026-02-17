import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DatabaseSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Set to true to force re-seeding even if users exist (useful for testing)
  static const bool FORCE_RESEED = true;

  static Future<void> seedDemoData() async {
    // Check if data already exists to avoid duplicates
    final usersRef = _db.collection('users');
    final usersSnapshot = await usersRef.limit(1).get();

    if (!FORCE_RESEED && usersSnapshot.docs.isNotEmpty) {
      debugPrint("Demo data already exists. Skipping seed.");
      return;
    }

    if (FORCE_RESEED && usersSnapshot.docs.isNotEmpty) {
      debugPrint(
        "⚠️ FORCE_RESEED enabled - Clearing existing data and re-seeding",
      );
    }

    debugPrint("Seeding demo data to The Quadrant...");

    // Create test users first
    final testUsers = [
      {
        'uid': 'user_1',
        'fullName': 'Dr. Aris Thorne',
        'username': 'athorne_ai',
        'email': 'aris@example.com',
        'headline': 'AI Research & Innovation',
        'bio': 'Exploring the future of AI and agentic workflows.',
        'location': 'San Francisco, CA',
        'followers': ['user_2', 'user_3'],
        'following': ['user_2', 'user_4'],
        'connections': ['user_2'],
        'skills': ['AI/ML', 'Python', 'Research', 'Leadership', 'Innovation'],
        'experiences': [
          {
            'id': 'exp_1_1',
            'title': 'AI Research Lead',
            'company': 'OpenAI',
            'location': 'San Francisco, CA',
            'startDate': '2022-01-15',
            'endDate': null,
            'description':
                'Leading advanced research in large language models and agent architectures.',
            'isCurrentRole': true,
          },
          {
            'id': 'exp_1_2',
            'title': 'Machine Learning Engineer',
            'company': 'DeepMind',
            'location': 'London, UK',
            'startDate': '2020-06-01',
            'endDate': '2021-12-31',
            'description':
                'Developed algorithms for reinforcement learning systems.',
            'isCurrentRole': false,
          },
        ],
        'projects': [
          {
            'id': 'proj_1_1',
            'title': 'AgentFlow Framework',
            'description': 'Open-source framework for building AI agents',
            'link': 'https://github.com/agentic/agentflow',
            'imageUrls': [],
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_2',
        'fullName': 'Sarah Jenkins',
        'username': 'sjenk_fintech',
        'email': 'sarah@example.com',
        'headline': 'Founder @ FinTech Startup',
        'bio': 'Building the future of decentralized finance.',
        'location': 'New York, NY',
        'followers': ['user_1', 'user_3', 'user_4'],
        'following': ['user_1'],
        'connections': ['user_1'],
        'skills': [
          'Fintech',
          'Blockchain',
          'Product Management',
          'Fundraising',
          'Entrepreneurship',
        ],
        'experiences': [
          {
            'id': 'exp_2_1',
            'title': 'Founder & CEO',
            'company': 'DeFi Protocols Inc',
            'location': 'New York, NY',
            'startDate': '2023-03-01',
            'endDate': null,
            'description':
                'Leading a Series B fintech startup focused on decentralized finance.',
            'isCurrentRole': true,
          },
          {
            'id': 'exp_2_2',
            'title': 'Product Manager',
            'company': 'Goldman Sachs',
            'location': 'New York, NY',
            'startDate': '2019-07-01',
            'endDate': '2023-02-28',
            'description':
                'Managed digital transformation initiatives for trading platforms.',
            'isCurrentRole': false,
          },
        ],
        'projects': [
          {
            'id': 'proj_2_1',
            'title': 'DeFi Protocol v2',
            'description': 'Next-generation smart contract protocols',
            'link': 'https://defiprotocol.io',
            'imageUrls': [],
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_3',
        'fullName': 'Marcus Vane',
        'username': 'mvane_design',
        'email': 'marcus@example.com',
        'headline': 'Product Designer & Design System Lead',
        'bio': 'Crafting beautiful and functional user experiences.',
        'location': 'Austin, TX',
        'followers': ['user_1', 'user_2'],
        'following': ['user_2', 'user_4'],
        'connections': [],
        'skills': [
          'UI/UX Design',
          'Design Systems',
          'Figma',
          'Prototyping',
          'User Research',
        ],
        'experiences': [
          {
            'id': 'exp_3_1',
            'title': 'Lead Design System Designer',
            'company': 'Figma',
            'location': 'San Francisco, CA',
            'startDate': '2021-09-15',
            'endDate': null,
            'description':
                'Building scalable design systems and improving design tools.',
            'isCurrentRole': true,
          },
          {
            'id': 'exp_3_2',
            'title': 'Senior Product Designer',
            'company': 'Airbnb',
            'location': 'San Francisco, CA',
            'startDate': '2018-04-01',
            'endDate': '2021-08-31',
            'description':
                'Designed user interfaces for marketplace and discovery features.',
            'isCurrentRole': false,
          },
        ],
        'projects': [
          {
            'id': 'proj_3_1',
            'title': 'Component Library',
            'description':
                'Comprehensive design component library for startups',
            'link': 'https://components.design',
            'imageUrls': [],
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_4',
        'fullName': 'Elena Garcia',
        'username': 'elena_leads',
        'email': 'elena@example.com',
        'headline': 'Executive Coach & Leadership Mentor',
        'bio': 'Helping leaders unlock their potential.',
        'location': 'Los Angeles, CA',
        'followers': ['user_1', 'user_2', 'user_3'],
        'following': ['user_3'],
        'connections': [],
        'skills': [
          'Executive Coaching',
          'Leadership',
          'Mentoring',
          'Team Building',
          'Strategic Planning',
        ],
        'experiences': [
          {
            'id': 'exp_4_1',
            'title': 'Executive Coach',
            'company': 'Garcia Leadership Institute',
            'location': 'Los Angeles, CA',
            'startDate': '2019-01-01',
            'endDate': null,
            'description':
                'Providing executive coaching to C-level executives and entrepreneurs.',
            'isCurrentRole': true,
          },
          {
            'id': 'exp_4_2',
            'title': 'VP of People & Culture',
            'company': 'Acme Corp',
            'location': 'San Diego, CA',
            'startDate': '2015-06-01',
            'endDate': '2018-12-31',
            'description':
                'Led organizational development and culture transformation initiatives.',
            'isCurrentRole': false,
          },
        ],
        'projects': [
          {
            'id': 'proj_4_1',
            'title': 'Leadership Development Program',
            'description': 'Comprehensive online program for emerging leaders',
            'link': 'https://leadershipprogram.io',
            'imageUrls': [],
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_5',
        'fullName': 'TechCrunch News',
        'username': 'techcrunch',
        'email': 'news@techcrunch.com',
        'headline': 'Technology News & Industry Insights',
        'bio': 'Breaking news from the tech world.',
        'location': 'Global',
        'followers': ['user_1', 'user_2', 'user_3', 'user_4'],
        'following': [],
        'connections': [],
        'skills': ['Journalism', 'Tech Reporting', 'Analysis', 'Editorial'],
        'experiences': [
          {
            'id': 'exp_5_1',
            'title': 'Editor-in-Chief',
            'company': 'TechCrunch',
            'location': 'San Francisco, CA',
            'startDate': '2015-01-01',
            'endDate': null,
            'description':
                'Leading editorial coverage of technology industry trends and innovations.',
            'isCurrentRole': true,
          },
        ],
        'projects': [],
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    // Create users
    for (var user in testUsers) {
      final uid = user['uid'] as String;
      await usersRef.doc(uid).set(user);
    }

    // Create test posts
    final postsRef = _db.collection('posts');
    final testPosts = [
      {
        'id': 'post_1',
        'uid': 'user_1',
        'name': 'Dr. Aris Thorne',
        'username': 'athorne_ai',
        'profileInitial': 'A',
        'content':
            'The shift from LLMs to Agentic Workflows is the biggest trend of 2026. Are you ready for AI that actually executes tasks?',
        'likes': 42,
        'commentCount': 5,
        'reposts': ['user_2'],
        'bookmarks': [],
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'id': 'post_2',
        'uid': 'user_2',
        'name': 'Sarah Jenkins',
        'username': 'sjenk_fintech',
        'profileInitial': 'S',
        'content':
            'Just closed our Series B! Grateful for the team and the vision. The future of decentralized finance is looking bright.',
        'likes': 128,
        'commentCount': 12,
        'reposts': [],
        'bookmarks': ['user_1'],
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'id': 'post_3',
        'uid': 'user_3',
        'name': 'Marcus Vane',
        'username': 'mvane_design',
        'profileInitial': 'M',
        'content':
            'Design Tip: In high-density dashboards, use whitespace as a functional element, not just an aesthetic one.',
        'likes': 15,
        'commentCount': 2,
        'reposts': [],
        'bookmarks': [],
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'id': 'post_4',
        'uid': 'user_5',
        'name': 'TechCrunch News',
        'username': 'techcrunch',
        'profileInitial': 'T',
        'content':
            'Breaking: New regulation regarding AI data privacy just passed in the EU. Here is what it means for startups.',
        'likes': 89,
        'commentCount': 45,
        'reposts': ['user_1', 'user_2'],
        'bookmarks': [],
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'id': 'post_5',
        'uid': 'user_4',
        'name': 'Elena Garcia',
        'username': 'elena_leads',
        'profileInitial': 'E',
        'content':
            'Leadership isn\'t about having the answers; it\'s about asking the right questions so your team can find them.',
        'likes': 250,
        'commentCount': 30,
        'reposts': ['user_1'],
        'bookmarks': [],
        'timestamp': FieldValue.serverTimestamp(),
      },
    ];

    for (var post in testPosts) {
      final postId = post['id'] as String;
      debugPrint("📝 Seeding post: $postId with uid=${post['uid']}");
      await postsRef.doc(postId).set(post);
    }

    debugPrint("✅ Seed complete! 5 Users and 5 Posts added.");
  }
}
