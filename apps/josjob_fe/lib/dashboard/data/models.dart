part of '../dashboard_page.dart';

// =========================================================================
// Sample-data model classes for the dashboard demo. All fields are plain and
// immutable — these are hand-authored fixtures, not fetched entities.
// =========================================================================

/// A navigation destination in the sidebar / bottom bar.
class _NavDest {
  final String label;
  final IconData icon;
  const _NavDest(this.label, this.icon);
}

/// A stat tile on the overview screen.
class _StatData {
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });
}

/// A course — reused for in-progress, recommended and org offerings. Not every
/// field is meaningful in every context (e.g. [enrolled] only for offerings).
class _DashCourse {
  final String title;
  final String category;
  final int seed; // picks the thumbnail gradient
  final int moduleCurrent;
  final int moduleTotal;
  final double progress; // 0..1
  final String level;
  final String duration;
  final double rating;
  final int enrolled;

  /// Deep-link key to this course's quiz (null = no specific quiz mapped).
  /// A dummy id today; the backend course/quiz id once integrated.
  final String? quizId;
  const _DashCourse({
    required this.title,
    required this.category,
    required this.seed,
    this.moduleCurrent = 0,
    this.moduleTotal = 0,
    this.progress = 0,
    this.level = '',
    this.duration = '',
    this.rating = 0,
    this.enrolled = 0,
    this.quizId,
  });
}

/// A live-coaching mentor / session.
class _Mentor {
  final String name;
  final String topic;
  final String time;
  const _Mentor(this.name, this.topic, this.time);
}

/// A team member on the org learner table.
enum _LearnerStatus { onTrack, behind, completed }

class _Learner {
  final String name;
  final String subtitle;
  final double progress; // 0..1
  final _LearnerStatus status;
  const _Learner(this.name, this.subtitle, this.progress, this.status);
}

/// An earned certificate.
class _Certificate {
  final String title;
  final String issuer;
  final String date;
  const _Certificate(this.title, this.issuer, this.date);
}

/// A certificate suggested to the learner, matched to their profile.
class _TargetCert {
  final String title;
  final String provider;
  final String reason;
  const _TargetCert(this.title, this.provider, this.reason);
}

/// Focus areas a coach specialises in — the browse filter buckets in
/// Live Coaching → Explore coaches.
enum _CoachFocus {
  career('Career'),
  interview('Interview'),
  skills('Skills'),
  confidence('Confidence'),
  leadership('Leadership');

  const _CoachFocus(this.label);
  final String label;
}

/// Sort order for the coach browse results.
enum _CoachSort {
  topRated('Top rated'),
  mostSessions('Most sessions');

  const _CoachSort(this.label);
  final String label;
}

/// A bookable coach shown in Live Coaching → Explore coaches.
class _Coach {
  final String name;
  final String expertise;
  final String tagline;
  final double rating;
  final int sessions;
  final _CoachFocus focus;
  const _Coach(
    this.name,
    this.expertise,
    this.tagline,
    this.rating,
    this.sessions,
    this.focus,
  );
}

/// An entry in the org activity feed.
class _ActivityItem {
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String text;
  final String time;
  const _ActivityItem(
    this.icon,
    this.tint,
    this.iconColor,
    this.text,
    this.time,
  );
}
