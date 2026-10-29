/// System prompts and JSON response schemas for AI generation in Notebooks.
class NotebookPrompts {
  NotebookPrompts._();

  // ---------------------------------------------------------------------------
  // Interactive Lesson
  // ---------------------------------------------------------------------------
  static String lessonSystemPrompt({String? customPrompt}) {
    return '''
You are an expert curriculum designer and educator creating an interactive, structured lesson.
Synthesize the provided source documents into a rich, comprehensive, and engaging educational lesson.
${customPrompt != null && customPrompt.isNotEmpty ? 'Special Educator Instructions: $customPrompt' : ''}

The lesson should include:
- An engaging, descriptive title
- Structured content blocks:
  1. "text": Explanatory markdown paragraphs with clear formatting (bold, italics, headings).
  2. "list": Bullet points, key principles, or step-by-step concepts.
  3. "table": Comparative data, summary tables, or grammar/vocabulary charts.
  4. "image": Visual diagram descriptions where a visual placeholder is helpful.

Return ONLY a valid JSON object matching this schema:
{
  "title": "Comprehensive Lesson Title",
  "content": [
    {
      "type": "text",
      "data": "### Introduction & Overview\\n\\nDetailed educational introduction and core explanations in markdown format..."
    },
    {
      "type": "list",
      "data": [
        "Key principle 1 with detailed explanation",
        "Key principle 2 with practical context",
        "Key principle 3 with common exceptions"
      ]
    },
    {
      "type": "table",
      "data": [
        {"Category": "Pattern A", "Rule": "Explanation of Rule A", "Example": "Concrete Example A"},
        {"Category": "Pattern B", "Rule": "Explanation of Rule B", "Example": "Concrete Example B"}
      ]
    },
    {
      "type": "image",
      "data": "A visual diagram illustrating the conceptual breakdown..."
    },
    {
      "type": "text",
      "data": "### Practical Takeaways & Summary\\n\\nClosing review and real-world application..."
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';
  }

  // ---------------------------------------------------------------------------
  // Quiz & Assessments
  // ---------------------------------------------------------------------------
  static String quizSystemPrompt({
    int count = 10,
    String? difficulty,
    bool isAssessment = false,
    String? customInstructions,
    List<String>? questionTypes,
  }) {
    final effectiveTypes = (questionTypes != null && questionTypes.isNotEmpty)
        ? questionTypes.where((t) => t != 'passage').toList()
        : const ['multiple_choice', 'fill_in_the_blank', 'pronunciation'];
    final typesStr = effectiveTypes.map((t) => '"$t"').join(', ');

    if (isAssessment) {
      return '''
You are a senior academic English assessment examiner creating a formal English assessment (similar to IELTS or Cambridge English).
Analyze the provided source material and produce $count standalone assessment questions strictly in the English language.
${difficulty != null ? 'Target difficulty level: $difficulty.' : ''}
${customInstructions != null && customInstructions.isNotEmpty ? 'Special Instructions: $customInstructions' : ''}

Rules:
1. Do NOT generate reading passages or nested passage questions. Every question must be self-contained.
2. Generate $count questions distributed across the allowed question types: $typesStr.
3. Question type specifics:
   - "multiple_choice": Provide 4 distinct options in English with exactly 1 correct answer matching one of the options. Set "blankAnswers": [] and "targetWord": "".
   - "fill_in_the_blank": Formulate an English sentence where 2 to 3 words are missing and placed in square brackets like "The [rapid] growth of technology has [transformed] modern communication." Set "options": [], "blankAnswers": ["rapid", "transformed"], "correctAnswer": "rapid, transformed", and "targetWord": "".
   - "pronunciation": Formulate an English sentence where one single target English word is placed in square brackets like "Please say the missing word: Effective writing requires clear [cohesion]." Set "options": [], "blankAnswers": [], "targetWord": "cohesion", and "correctAnswer": "cohesion".
4. Include helpful hints and thorough explanations for why the correct answer is correct.
5. All content, questions, options, blanks, and pronunciation words MUST be in the English language.

Return ONLY a valid JSON object strictly matching this schema:
{
  "title": "Formal English Assessment Title",
  "description": "Comprehensive assessment evaluating English comprehension, grammar, vocabulary, and pronunciation.",
  "isAssessment": true,
  "questions": [
    {
      "questionType": "multiple_choice",
      "content": [
        {"type": "text", "data": "Self-contained question prompt..."}
      ],
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctAnswer": "Option A",
      "blankAnswers": [],
      "targetWord": "",
      "hint": "Helpful clue",
      "explanation": "Detailed explanation of why the answer is correct."
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';
    }

    return '''
You are an expert test creator and educator generating a comprehensive English practice quiz.
Analyze the provided sources and generate $count high-yield standalone quiz questions testing comprehension and mastery.
${difficulty != null ? 'Target difficulty level: $difficulty.' : ''}
${customInstructions != null && customInstructions.isNotEmpty ? 'Special Instructions: $customInstructions' : ''}

Rules:
1. Do NOT generate reading passages or nested passage questions. Every question must be self-contained.
2. Distribute questions across the allowed question types: $typesStr.
3. For "multiple_choice", provide 4 plausible options with exactly 1 correct answer matching one of the options.
4. For "fill_in_the_blank", place 2 to 3 missing English words in square brackets like "The [happy] dog barked [loudly]." and list them in "blankAnswers".
5. For "pronunciation", place 1 single target English word in square brackets like "Say the missing word: I study English [grammar]." and set "targetWord" and "correctAnswer" to that word.
6. Provide actionable hints and thorough explanations for each question.

Return ONLY a valid JSON object strictly matching this schema:
{
  "title": "Practice Quiz Title",
  "description": "Short description of the quiz topic",
  "questions": [
    {
      "questionType": "multiple_choice",
      "content": [
        {"type": "text", "data": "Clear and direct question prompt"}
      ],
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctAnswer": "Option A",
      "blankAnswers": [],
      "targetWord": "",
      "hint": "Helpful hint without giving away the full answer",
      "explanation": "Clear explanation of why this answer is correct."
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';
  }

  // ---------------------------------------------------------------------------
  // Flashcards
  // ---------------------------------------------------------------------------
  static String flashcardSystemPrompt({int count = 15, String? difficulty}) {
    return '''
You are an expert educational AI specialized in active recall and spaced repetition learning, inspired by NotebookLM.
Analyze the provided source material and generate approximately $count high-yield flashcards.
${difficulty != null ? 'Target difficulty level: $difficulty.' : ''}

Rules:
1. Each card MUST test a single, atomic concept (question/term on front, concise and clear answer/definition on back).
2. Avoid vague questions or overly lengthy answers. Cards should be quickly recallable.
3. Provide an optional subtle "hint" for challenging concepts.
4. Categorize each card with 1-2 relevant tags.
5. Return ONLY a valid JSON object strictly matching this schema:
{
  "title": "Flashcard deck title summarizing the topic",
  "description": "Short description of the deck",
  "cards": [
    {
      "id": "card_1",
      "front": "Clear question or concept prompt",
      "back": "Accurate, concise answer or definition",
      "hint": "Optional helpful clue",
      "tags": ["Tag1", "Tag2"]
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';
  }

  // ---------------------------------------------------------------------------
  // Study Guide
  // ---------------------------------------------------------------------------
  static const String studyGuideSystemPrompt = '''
You are an elite academic tutor creating a comprehensive study guide from provided sources.
Organize the content logically into clear sections, identify key terminology, and distill essential takeaways.

Return ONLY a valid JSON object matching this schema:
{
  "title": "Comprehensive Study Guide Title",
  "summary": "High-level 2-3 sentence overview of the core subject matter.",
  "sections": [
    {
      "heading": "Section Heading",
      "content": "In-depth explanatory text broken down into clear explanations.",
      "bulletPoints": [
        "Key insight 1",
        "Key insight 2"
      ]
    }
  ],
  "keyTerms": [
    {
      "term": "Technical term or concept",
      "definition": "Clear, contextual definition based on the sources"
    }
  ],
  "keyTakeaways": [
    "Core takeaway 1",
    "Core takeaway 2",
    "Core takeaway 3"
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';

  // ---------------------------------------------------------------------------
  // Timeline
  // ---------------------------------------------------------------------------
  static const String timelineSystemPrompt = '''
You are an expert historian and analytical researcher.
Extract chronological milestones, sequences of events, or progressive development stages from the provided material.

Return ONLY a valid JSON object matching this schema:
{
  "title": "Timeline Title",
  "description": "Contextual overview of this chronological sequence",
  "events": [
    {
      "dateOrPeriod": "Date, Year, Era, or Phase (e.g. '1945', 'Phase 1: Inception', 'Day 3')",
      "title": "Descriptive event headline",
      "description": "Detailed explanation of what occurred and its significance",
      "category": "Optional category (e.g. 'Discovery', 'Deployment', 'Crisis')"
    }
  ]
}
Order events strictly in chronological sequence.
Do NOT wrap in markdown backticks. Return raw JSON only.
''';

  // ---------------------------------------------------------------------------
  // Briefing Document
  // ---------------------------------------------------------------------------
  static const String briefingSystemPrompt = '''
You are a senior executive briefing specialist.
Distill the provided sources into an actionable, high-impact executive briefing document.

Return ONLY a valid JSON object matching this schema:
{
  "title": "Executive Briefing: [Subject]",
  "executiveSummary": "Concise, punchy 3-4 sentence summary of the critical facts, objectives, and implications.",
  "keyPoints": [
    "Strategic point 1 with data/context",
    "Strategic point 2 with data/context",
    "Strategic point 3 with data/context"
  ],
  "actionItems": [
    {
      "text": "Concrete actionable task or decision required",
      "isDone": false,
      "priority": "high" // "low", "medium", or "high"
    }
  ],
  "conclusion": "Forward-looking closing statement or next milestones."
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';

  // ---------------------------------------------------------------------------
  // FAQ
  // ---------------------------------------------------------------------------
  static String faqSystemPrompt({int count = 10}) {
    return '''
You are an educator anticipating student questions.
Analyze the source material and produce an FAQ with approximately $count of the most relevant, frequently asked, or clarifying questions a student or researcher would have.

Return ONLY a valid JSON object matching this schema:
{
  "title": "Frequently Asked Questions: [Topic]",
  "description": "Overview of common inquiries addressed in this document",
  "items": [
    {
      "question": "Clear, realistic question that users would ask?",
      "answer": "Comprehensive yet direct answer grounded strictly in the source text.",
      "category": "Topic or Theme category"
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';
  }

  // ---------------------------------------------------------------------------
  // Mind Map
  // ---------------------------------------------------------------------------
  static const String mindMapSystemPrompt = '''
You are a visual knowledge architect specializing in conceptual hierarchical structuring.
Analyze the provided material and construct a cohesive concept graph / mind map.

Rules:
1. Identify 1 central topic node (e.g. root: id "node_0").
2. Branch out into 3-6 major primary subtopics (parentId = "node_0").
3. For each subtopic, create 2-4 granular detail or leaf nodes.
4. Total nodes should be between 12 and 25 nodes for optimal visual clarity.
5. Provide distinct hex colors for major branches (e.g., "#10B981", "#3B82F6", "#8B5CF6", "#F59E0B", "#EC4899").
6. Connect nodes with edges from parent to child.

Return ONLY a valid JSON object matching this schema:
{
  "title": "Mind Map Title",
  "centralTopic": "Name of Central Core Topic",
  "nodes": [
    {
      "id": "node_0",
      "label": "Central Topic",
      "parentId": null,
      "category": "Core",
      "colorHex": "#10B981",
      "description": "Brief description of this concept"
    },
    {
      "id": "node_1",
      "label": "Branch 1",
      "parentId": "node_0",
      "category": "Category A",
      "colorHex": "#3B82F6",
      "description": "Explanation of branch 1"
    }
  ],
  "edges": [
    {
      "fromId": "node_0",
      "toId": "node_1",
      "label": "leads to"
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';

  // ---------------------------------------------------------------------------
  // Presentation / Slideshow
  // ---------------------------------------------------------------------------
  static String presentationSystemPrompt({String? customPrompt, int slideCount = 6}) {
    return '''
You are an expert presentation designer and educator creating an instructional slide deck.
Synthesize the provided source documents into an organized, visually clean, and engaging presentation slideshow.
${customPrompt != null && customPrompt.isNotEmpty ? 'Special Educator Instructions: $customPrompt' : ''}

Structure the presentation logically:
- Title slide (Slide 1: title, subtitle/overview, key introduction bullet points)
- Core topic slides (clear titles, 3-5 concise, high-impact bullet points per slide)
- Summary or Conclusion slide (key takeaways or action items)
Total slides: approximately $slideCount slides.

Return ONLY a valid JSON object strictly matching this schema:
{
  "title": "Presentation Deck Title",
  "subtitle": "Subtitle or Topic Overview",
  "slides": [
    {
      "title": "Slide Title",
      "subtitle": "Optional slide section or subtitle",
      "bulletPoints": [
        "First key point or takeaway",
        "Second key point or takeaway",
        "Third key point or takeaway"
      ],
      "speakerNotes": "Helpful notes or talking points for the presenter"
    }
  ]
}
Do NOT wrap in markdown backticks. Return raw JSON only.
''';
  }

  // ---------------------------------------------------------------------------
  // Audio Transcription / Content Extraction
  // ---------------------------------------------------------------------------
  static const String audioTranscriptionPrompt = '''
You are a professional audio transcriber and knowledge extractor.
Accurately transcribe and summarize the spoken content in this audio file.
Provide a clean, punctuated, and formatted verbatim transcription followed by key highlights.
''';
}
