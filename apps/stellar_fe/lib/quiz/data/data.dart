part of '../quiz_page.dart';

// =========================================================================
// Sample content. Everything is themed around a plausible catalog course,
// "Introduction to Python for Data", so the tiers read as one journey. The
// live quiz reuses the worked examples from the platform's assessment spec.
// =========================================================================

// ---- Self-paced assessments (one per non-live tier) ---------------------

const _placementAssessment = _Assessment(
  title: 'Skills placement check',
  tier: QuizTier.placement,
  subtitle: 'Programming foundations',
  estMinutes: 8,
  questions: [
    _McqQuestion(
      id: 'p1',
      prompt: 'What is the main job of a variable in a program?',
      options: [
        _Option('A', 'To store a value so it can be used later'),
        _Option('B', 'To permanently delete data from disk'),
        _Option('C', 'To connect the app to the internet'),
        _Option('D', 'To style the user interface'),
      ],
      correctKey: 'A',
      explanation:
          'A variable is a named container that holds a value your program can read and update later.',
    ),
    _McqQuestion(
      id: 'p2',
      prompt: "Which data type best stores a person's age in whole years?",
      options: [
        _Option('A', 'Integer'),
        _Option('B', 'Boolean'),
        _Option('C', 'Image'),
        _Option('D', 'Colour'),
      ],
      correctKey: 'A',
      explanation:
          'An age in whole years is a counting number, so an integer is the natural fit.',
    ),
    _OpenQuestion(
      id: 'p3',
      prompt: 'In one sentence, what is the purpose of a loop?',
      modelAnswer: 'A loop repeats a block of code multiple times.',
      keywords: ['repeat', 'repeatedly', 'iterate', 'again', 'over and over'],
      explanation:
          'Loops let you run the same instructions many times without rewriting them.',
    ),
    _MatchQuestion(
      id: 'p4',
      prompt: 'Match each term to its plain-English meaning.',
      pairs: [
        _MatchPair('Variable', 'Named storage for a value'),
        _MatchPair('Function', 'A reusable block of code'),
        _MatchPair('Loop', 'Repeats code'),
        _MatchPair('Bug', 'An error in a program'),
      ],
      explanation:
          'These four building blocks show up in almost every program you will write.',
    ),
  ],
);

const _lectureAssessment = _Assessment(
  title: 'Variables & data types',
  tier: QuizTier.lecture,
  subtitle: 'Lecture 3 comprehension check',
  estMinutes: 4,
  questions: [
    _McqQuestion(
      id: 'l1',
      prompt: 'What is the correct syntax to define a list in Python?',
      options: [
        _Option('A', 'x = []'),
        _Option('B', 'x = {}'),
        _Option('C', 'x = ()'),
        _Option('D', 'x = ||'),
      ],
      correctKey: 'A',
      explanation:
          'Square brackets [] create a list. {} makes a dict/set, () a tuple.',
    ),
    _McqQuestion(
      id: 'l2',
      prompt: 'Which of these is a valid Python variable name?',
      options: [
        _Option('A', '2nd_place'),
        _Option('B', 'my_value'),
        _Option('C', 'my value'),
        _Option('D', 'class'),
      ],
      correctKey: 'B',
      explanation:
          'Names must start with a letter or underscore, contain no spaces, and avoid reserved words like "class".',
    ),
    _OpenQuestion(
      id: 'l3',
      prompt: "What number does len('data') return?",
      modelAnswer: '4',
      keywords: ['4', 'four'],
      explanation: "'data' has four characters, so len() returns 4.",
    ),
    _MatchQuestion(
      id: 'l4',
      prompt: 'Match each Python type to an example value.',
      pairs: [
        _MatchPair('int', '42'),
        _MatchPair('str', "'hello'"),
        _MatchPair('bool', 'True'),
        _MatchPair('float', '3.14'),
      ],
      explanation:
          'Recognising literal values by their type is the first step to reading code fluently.',
    ),
  ],
);

const _sectionAssessment = _Assessment(
  title: 'Python fundamentals',
  tier: QuizTier.section,
  subtitle: 'Section 1 cumulative assessment',
  estMinutes: 10,
  questions: [
    _McqQuestion(
      id: 's1',
      prompt: 'Is Python compiler-based or interpreter-based?',
      options: [
        _Option('A', 'Compiler'),
        _Option('B', 'Interpreter'),
        _Option('C', 'Both at once'),
        _Option('D', 'Neither'),
      ],
      correctKey: 'B',
      explanation: 'Python is executed line-by-line via an interpreter.',
    ),
    _McqQuestion(
      id: 's2',
      prompt: "What does print(3 * '2') output?",
      options: [
        _Option('A', '6'),
        _Option('B', '222'),
        _Option('C', 'An error'),
        _Option('D', '32'),
      ],
      correctKey: 'B',
      explanation: "Multiplying a string repeats it, so 3 * '2' becomes '222'.",
    ),
    _OpenQuestion(
      id: 's3',
      prompt: 'Name one benefit of writing functions.',
      modelAnswer: 'Functions let you reuse code and keep programs organised.',
      keywords: [
        'reuse',
        'reusable',
        'organis',
        'organiz',
        'readable',
        'repetition',
        'repeat',
        'tidy',
        'test',
      ],
      explanation:
          'Functions avoid repetition, name a piece of logic, and make code easier to read and test.',
    ),
    _MatchQuestion(
      id: 's4',
      prompt: 'Match each operator to what it checks.',
      pairs: [
        _MatchPair('==', 'Equal to'),
        _MatchPair('!=', 'Not equal to'),
        _MatchPair('>=', 'Greater than or equal'),
        _MatchPair('%', 'Remainder'),
      ],
      explanation:
          'Comparison and arithmetic operators are the backbone of conditions and loops.',
    ),
    _McqQuestion(
      id: 's5',
      prompt: 'Which keyword begins a conditional statement?',
      options: [
        _Option('A', 'if'),
        _Option('B', 'for'),
        _Option('C', 'def'),
        _Option('D', 'import'),
      ],
      correctKey: 'A',
      explanation:
          '"if" starts a conditional; "for"/"while" loop, "def" defines a function.',
    ),
  ],
);

/// The assessment behind each self-paced tier card on the hub.
_Assessment _assessmentFor(QuizTier tier) => switch (tier) {
  QuizTier.placement => _placementAssessment,
  QuizTier.lecture => _lectureAssessment,
  QuizTier.section => _sectionAssessment,
  QuizTier.live => _lectureAssessment, // unused: live has its own screen
};

// ---- Per-course quizzes (deep-linked from the dashboard's "Resume") -------
// Each maps to a Continue-learning course by a stable id. Topic-appropriate so
// the quiz reads as "this course's" quiz, unlike the generic Python samples.

const _customerServiceQuiz = _Assessment(
  title: 'Customer Service Excellence',
  tier: QuizTier.lecture,
  subtitle: 'Lecture 4 comprehension check',
  estMinutes: 4,
  questions: [
    _McqQuestion(
      id: 'cs1',
      prompt:
          'A guest is upset about a late check-in. What is the best first response?',
      options: [
        _Option('A', 'Apologise and acknowledge their frustration'),
        _Option('B', "Explain that it wasn't your fault"),
        _Option('C', 'Ask them to wait until you are free'),
        _Option('D', 'Offer a discount straight away'),
      ],
      correctKey: 'A',
      explanation:
          "Acknowledging the guest's feelings first de-escalates things before you solve the problem.",
    ),
    _McqQuestion(
      id: 'cs2',
      prompt: 'Which of these best describes active listening?',
      options: [
        _Option('A', 'Waiting for your turn to speak'),
        _Option('B', 'Repeating back what was said to confirm you understood'),
        _Option('C', 'Doing other tasks while they talk'),
        _Option('D', 'Giving advice as quickly as possible'),
      ],
      correctKey: 'B',
      explanation:
          'Active listening means confirming understanding, not just hearing the words.',
    ),
    _OpenQuestion(
      id: 'cs3',
      prompt:
          'In one sentence, why does following up after resolving a complaint matter?',
      modelAnswer:
          'It shows the customer they are valued and rebuilds trust and loyalty.',
      keywords: [
        'trust',
        'loyal',
        'valued',
        'satisf',
        'care',
        'relationship',
        'retention',
        'follow',
      ],
      explanation:
          'A follow-up turns a recovered complaint into lasting loyalty.',
    ),
    _MatchQuestion(
      id: 'cs4',
      prompt: 'Match each situation to the best action.',
      pairs: [
        _MatchPair('Angry customer', 'Stay calm and listen'),
        _MatchPair('Unsure of an answer', 'Check, then follow up'),
        _MatchPair('Happy customer', 'Invite feedback and thank them'),
        _MatchPair('Long queue', 'Acknowledge the wait'),
      ],
      explanation:
          'Matching the response to the moment is the core of great service.',
    ),
  ],
);

const _workplaceSafetyQuiz = _Assessment(
  title: 'Workplace Safety Essentials',
  tier: QuizTier.lecture,
  subtitle: 'Lecture 5 comprehension check',
  estMinutes: 4,
  questions: [
    _McqQuestion(
      id: 'ws1',
      prompt: 'You spot a liquid spill on a walkway. What should you do first?',
      options: [
        _Option('A', 'Ignore it if you are busy'),
        _Option('B', 'Warn others and mark or clean the area'),
        _Option('C', 'Wait for a manager to notice'),
        _Option('D', 'Take a photo for later'),
      ],
      correctKey: 'B',
      explanation:
          'Making the hazard safe and warning others prevents slips right away.',
    ),
    _McqQuestion(
      id: 'ws2',
      prompt: 'What does a green safety sign usually indicate?',
      options: [
        _Option('A', 'Danger'),
        _Option('B', 'Something prohibited'),
        _Option('C', 'A safe condition or emergency exit'),
        _Option('D', 'A mandatory action'),
      ],
      correctKey: 'C',
      explanation:
          'Green marks safe conditions and escape routes; red is prohibition, yellow is warning.',
    ),
    _OpenQuestion(
      id: 'ws3',
      prompt:
          'Give one reason to report a near-miss even when no one was hurt.',
      modelAnswer:
          'It helps identify and fix a hazard before it causes a real injury.',
      keywords: [
        'prevent',
        'future',
        'hazard',
        'risk',
        'injur',
        'again',
        'recur',
        'identif',
        'fix',
        'learn',
      ],
      explanation:
          'Near-misses are free lessons — reporting them stops the next incident.',
    ),
    _MatchQuestion(
      id: 'ws4',
      prompt: 'Match each hazard to a suitable control.',
      pairs: [
        _MatchPair('Wet floor', 'Warning sign'),
        _MatchPair('Heavy lifting', 'Correct technique or aids'),
        _MatchPair('Fire', 'Extinguisher or evacuate'),
        _MatchPair('Loud machinery', 'Ear protection'),
      ],
      explanation:
          'Every hazard has a matching control — knowing them keeps everyone safe.',
    ),
  ],
);

const _digitalLiteracyQuiz = _Assessment(
  title: 'Digital Literacy Foundations',
  tier: QuizTier.lecture,
  subtitle: 'Lecture 2 comprehension check',
  estMinutes: 4,
  questions: [
    _McqQuestion(
      id: 'dl1',
      prompt: 'Which of these is the strongest password?',
      options: [
        _Option('A', 'password123'),
        _Option('B', 'Your date of birth'),
        _Option('C', 'A long passphrase with mixed characters'),
        _Option('D', 'Your first name'),
      ],
      correctKey: 'C',
      explanation:
          'Length and variety make a password far harder to guess than personal details.',
    ),
    _McqQuestion(
      id: 'dl2',
      prompt:
          'An email asks you to "verify your account" via a link. What is safest?',
      options: [
        _Option('A', 'Click the link quickly'),
        _Option('B', "Don't click; open the official site or app yourself"),
        _Option('C', 'Reply with your password'),
        _Option('D', 'Forward it to colleagues'),
      ],
      correctKey: 'B',
      explanation:
          'Phishing links imitate real sites — always navigate to the service directly.',
    ),
    _OpenQuestion(
      id: 'dl3',
      prompt: 'What is one benefit of saving your work to the cloud?',
      modelAnswer:
          'You can reach it from any device and it is backed up if your computer fails.',
      keywords: [
        'access',
        'anywhere',
        'backup',
        'back up',
        'safe',
        'sync',
        'device',
        'recover',
        'lose',
        'share',
      ],
      explanation:
          'Cloud storage protects your work and lets you pick up on any device.',
    ),
    _MatchQuestion(
      id: 'dl4',
      prompt: 'Match each term to what it does.',
      pairs: [
        _MatchPair('Browser', 'Views web pages'),
        _MatchPair('Spreadsheet', 'Organises data in rows and columns'),
        _MatchPair('Cc', 'Copies others on an email'),
        _MatchPair('PDF', 'A fixed-layout document'),
      ],
      explanation:
          'Knowing the everyday tools is the foundation of working digitally.',
    ),
  ],
);

/// Deep-link table: a dashboard course's `quizId` -> its assessment. A local
/// stand-in for a backend lookup by course/quiz id — swap this map for a fetch
/// when the backend lands; the ids stay the seam.
const _courseQuizzes = <String, _Assessment>{
  'customer-service': _customerServiceQuiz,
  'workplace-safety': _workplaceSafetyQuiz,
  'digital-literacy': _digitalLiteracyQuiz,
};

_Assessment? _assessmentById(String id) => _courseQuizzes[id];

/// The hub's quiz catalog, grouped by tier. Live isn't here — it opens its own
/// screen. A local stand-in for "list the quizzes available to this student".
const _quizCatalog = <QuizTier, List<_Assessment>>{
  QuizTier.placement: [_placementAssessment],
  QuizTier.lecture: [
    _lectureAssessment,
    _customerServiceQuiz,
    _workplaceSafetyQuiz,
    _digitalLiteracyQuiz,
  ],
  QuizTier.section: [_sectionAssessment],
};

// ---- Live classroom quiz -------------------------------------------------

const _liveTitle = 'Live: Python Variables Review';
const _liveJoined = 28; // students in the room

const _liveSession = <_Segment>[
  _QuestionSeg(
    _LiveQuestion(
      prompt: 'What is the correct syntax to define a list in Python?',
      options: [
        _Option('A', 'x = []'),
        _Option('B', 'x = {}'),
        _Option('C', 'x = ()'),
        _Option('D', 'x = ||'),
      ],
      correctKey: 'A',
      explanation: 'Square brackets [] denote a list literal.',
      seconds: 20,
    ),
  ),
  _QuestionSeg(
    _LiveQuestion(
      prompt: 'Is Python compiler-based or interpreter-based?',
      options: [
        _Option('A', 'Compiler'),
        _Option('B', 'Interpreter'),
        _Option('C', 'Both'),
      ],
      correctKey: 'B',
      explanation: 'Python is executed line-by-line via an interpreter.',
      seconds: 20,
    ),
  ),
  _PollSeg(
    _Poll(
      prompt: 'Which backend paradigm is your preference?',
      options: [
        'Functional (Elixir / Phoenix)',
        'OOP (Spring Boot)',
        'Serverless (Node / AWS)',
      ],
      tally: [85, 20, 15],
    ),
  ),
  _QuestionSeg(
    _LiveQuestion(
      prompt: 'What does len([1, 2, 3]) return?',
      options: [
        _Option('A', '2'),
        _Option('B', '3'),
        _Option('C', '6'),
        _Option('D', 'An error'),
      ],
      correctKey: 'B',
      explanation: 'len() counts the items — the list has three.',
      seconds: 20,
    ),
  ),
];

/// Number of scored questions in the session (polls are not scored).
const _liveQuestionCount = 3;

/// Scripted opponents. Per-question point gains are fixed so the leaderboard
/// climbs believably; "You" earn points live from answer speed.
const _liveNpcs = <_Npc>[
  _Npc('Jane Doe', [180, 150, 150]),
  _Npc('John Smith', [150, 130, 140]),
  _Npc('Bob Martin', [140, 120, 130]),
  _Npc('Mia Chen', [130, 110, 90]),
  _Npc('Sam Okoro', [90, 120, 100]),
];
