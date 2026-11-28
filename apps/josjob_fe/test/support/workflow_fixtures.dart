Map<String, dynamic> applicationJson({
  String status = 'applied',
  bool manager = false,
}) => {
  'id': 'application-1',
  'job_id': 'job-1',
  'job_title': 'Junior developer',
  'company': 'Test employer',
  'candidate_name': 'Test candidate',
  'status': status,
  'applied_at': '2026-11-17T10:00:00Z',
  'interview_at': null,
  'can_manage': manager,
  'can_chat': true,
  'next_statuses': manager ? ['reviewing', 'rejected'] : ['withdrawn'],
  'cover_letter': 'I enjoy building useful software.',
  'profile': {
    'identity': {
      'full_name': 'Test candidate',
      'email': 'candidate@example.com',
    },
    'skills': ['Elixir'],
  },
  'history': [
    {
      'id': 'event-1',
      'status': 'applied',
      'note': '',
      'created_at': '2026-11-17T10:00:00Z',
      'scheduled_at': null,
    },
  ],
};
Map<String, dynamic> applicationList({
  bool empty = false,
  bool hiring = false,
}) => {
  'data': empty ? [] : [applicationJson(manager: hiring)],
  'counts': empty ? {} : {'applied': 1},
  'organizations': hiring
      ? [
          {'id': 'org-1'},
        ]
      : [],
  'meta': {'page': 1, 'total': empty ? 0 : 1, 'total_pages': empty ? 0 : 1},
};
Map<String, dynamic> messageJson({
  String id = '1',
  String body = 'Hello there',
  String clientId = 'first',
  String senderId = 'employer',
}) => {
  'id': id,
  'body': body,
  'client_id': clientId,
  'sender_id': senderId,
  'sender_name': senderId == 'candidate' ? 'Test candidate' : 'Hiring team',
  'created_at': '2026-11-17T10:01:00Z',
};
Map<String, dynamic> chatJson({
  List<Map<String, dynamic>>? messages,
  bool canSend = true,
  String? nextBefore,
}) => {
  'thread': {
    'title': 'Test conversation',
    'subtitle': 'Private conversation',
    'self_id': 'candidate',
    'can_send': canSend,
  },
  'data': messages ?? [messageJson()],
  'next_before': nextBefore,
};
