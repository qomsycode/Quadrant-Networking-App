import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// JOB DATA MODEL
/// ==========================================
///
/// Represents a professional job listing (Job Board feature).
/// Location in Firestore: /jobs/{jobId}
///
/// DOCUMENT SCHEMA:
/// ------------------------------------------
/// title: String        - Job title (e.g. "Senior Flutter Developer")
/// company: String      - Hiring organization name
/// location: String     - City or "Remote"
/// salary: String       - Compensation range
/// type: String         - 'remote', 'hybrid', or 'onsite'
/// postedBy: String     - UID of the recruiter/user who created it
/// applicants: List<String>- Array of UIDs who have applied
/// createdAt: Timestamp - When the job was listed
///
/// RECRUITMENT LOGIC:
/// ------------------------------------------
/// The 'applicants' list allows for quick counting of interested users.
/// Security rules permit any authenticated user to add themselves to
/// this list (Apply), but only the 'postedBy' user can read the full list
/// if sensitivity is required (customizable in rules).
///

class JobModel {
  final String id;
  final String title;
  final String company;
  final String location;
  final String salary;
  final String description;
  final String type; // 'remote', 'hybrid', 'onsite'
  final String postedBy;
  final String postedByName;
  final List<String> applicants;
  final DateTime createdAt;

  JobModel({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.description,
    required this.type,
    required this.postedBy,
    required this.postedByName,
    this.applicants = const [],
    required this.createdAt,
  });

  factory JobModel.fromMap(Map<String, dynamic> map, String docId) {
    return JobModel(
      id: docId,
      title: map['title'] ?? '',
      company: map['company'] ?? '',
      location: map['location'] ?? '',
      salary: map['salary'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'onsite',
      postedBy: map['postedBy'] ?? '',
      postedByName: map['postedByName'] ?? '',
      applicants: List<String>.from(map['applicants'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'company': company,
      'location': location,
      'salary': salary,
      'description': description,
      'type': type,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'applicants': applicants,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
