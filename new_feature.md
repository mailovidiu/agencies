# Top Feature Recommendation

## Add an "I Need Help With..." task-based service finder

This is the single highest-value user improvement for the app.

Today the app is strong at browsing departments after the user already knows what agency to look for. It is much weaker at the harder real-world problem: "I have a life task or issue, which government office should I use, and what should I do next?"

## Why this is the best next feature

- The home experience is still department-first: search, favorites, map, compare, categories, and updates all assume the user starts from agencies, not from a personal need. See `lib/screens/home_screen.dart`.
- Search is only substring filtering over name, short name, description, keywords, and tags. It does not interpret intent like "replace my passport", "student aid", or "report workplace discrimination". See `lib/providers/department_provider.dart:168-239`.
- The `services` field — the most task-relevant data on each department — is not included in the current search filter at all. Adding it is a quick win even without this feature.
- The AI features are useful, but they only appear after the user has already opened a department or selected multiple departments to compare. See `lib/screens/department_detail_screen.dart:240-246`, `lib/screens/department_detail_screen.dart:728-989`, and `lib/screens/department_compare_screen.dart:34-160`.
- The data model already contains most of what this feature needs: `services`, `keywords`, `tags`, `contactInfo`, `location`, and `officeHours`. See `lib/models/department.dart:6-43`.
- The admin/editing flow already supports rich metadata entry, so the feature can improve over time without a backend rewrite. See `lib/screens/department_form_screen.dart`.
- There is already reusable AI plumbing for general and contextual answers through the proxy endpoint. See `lib/openai/openai_config.dart:15-183`.
- Reusable widgets already exist: `AiSummaryCard` can serve as a "why this department matches" explanation card, and the Q&A chat pattern in `DepartmentDetailScreen` can be adapted for multi-turn task refinement.

## User problem it solves

Most users do not think in agency names. They think in tasks:

- "I need food assistance"
- "I want to apply for student aid"
- "My veterans benefits claim is delayed"
- "I need directions to the nearest office that can help"

Right now the app helps only after the user maps that need to the right department. That is the main product gap.

## Proposed experience

Add a prominent home card or first-tab entry called `I Need Help With...`.

The user types a plain-English need. Example: `I need help paying for college`.

The app returns:

- Best matching department or agency
- Up to 2 alternate matches when there is ambiguity
- Why each result matches the request
- Best next actions
- Direct actions: call, website, directions, save, notify me
- A short AI-generated explanation in plain language

If the request is ambiguous, the app asks one short follow-up question instead of dumping broad results.

## Why users would feel this immediately

- Faster first success: users can start with their problem, not with government structure knowledge.
- Lower frustration: fewer dead-end searches and less category guessing.
- Better use of existing features: results can feed directly into detail pages, map, favorites, and notifications.
- Better app differentiation: many directory apps list agencies; fewer help users identify the right one from intent.

## MVP scope

1. Add a new `TaskFinderScreen` reachable from the home screen hero or quick actions.
2. Add a single input with prompt chips. Chips should be data-driven (from `DepartmentProvider.availableTags` or a curated Firestore collection) so they can be updated without an app release. Seed values: `Benefits`, `Passport`, `Student aid`, `Jobs`, `Housing`, `Health`, `Veterans`.
3. Build a local ranking pass using weighted scoring (see "Local ranking algorithm" below).
4. Use the OpenAI proxy to refine/rerank top matches and generate a short "why this is the right office" explanation (see "AI prompt strategy" below).
5. Return a structured result with:
   - `primaryDepartmentId`
   - `secondaryDepartmentIds`
   - `reason`
   - `nextSteps`
   - `clarifyingQuestion` when confidence is low
6. Add direct CTAs from the result card: `Open details`, `Call`, `Visit website`, `Directions`, `Save`.
7. Track searches and result taps via Firebase Analytics (see "Analytics events" below).

## Local ranking algorithm

The local pass should use weighted keyword scoring, not just boolean `contains()`:

| Field | Weight | Rationale |
|---|---|---|
| `services` | 3.0 | Strongest task signal — these are what the department actually does |
| `keywords` | 2.0 | Purpose-built for search matching |
| `tags` | 1.5 | Organizational groupings, often task-adjacent |
| `name` / `shortName` | 1.0 | Sometimes the agency name itself matches the task |
| `description` | 0.5 | Broad text, prone to false positives |

- Tokenize the user query and match each token independently.
- Normalize scores by field token count to avoid bias toward longer descriptions.
- Return results sorted by score with a minimum threshold to suppress noise.
- Show local results immediately (< 200ms), then refine with AI response asynchronously. Do not block the UI on the AI call.

## AI prompt strategy

- Use `responseFormat: {'type': 'json_object'}` (already supported in `chatCompletion` but unused) for structured responses.
- System prompt: "You are a US government service routing assistant. Given a citizen's task description and a list of departments with their services, return JSON: `{primaryId, secondaryIds[], reason, nextSteps[], clarifyingQuestion?}`"
- Send only `id`, `name`, `services`, `keywords`, and `category` per department to stay within token limits (~50 departments fit in ~2K tokens).
- Use `maxTokens: 400` and `temperature: 0.3` for deterministic, concise routing.
- The existing `answerGeneralQuestion` method can serve as a conversational fallback if the user asks follow-up questions about their task.

## Edge cases

- **AI unavailable or slow**: Show local-only ranked results immediately with a banner: "AI refinement unavailable, showing keyword matches." Never block the UI waiting for AI.
- **Off-topic query**: The AI system prompt should detect non-government queries and respond with: "I can help with government services. Try something like 'renew my passport' or 'apply for food assistance'."
- **Zero results**: Show a helpful empty state with suggested prompt chips and a fallback link to browse all categories. Never show a blank screen.
- **Gibberish input**: Fall through to zero-results state gracefully.
- **Latency budget**: Local results in < 200ms. AI refinement target < 3s. If AI exceeds 5s, show local results as final and cancel the AI request.

## Analytics events

Track via Firebase Analytics custom events:

| Event | Parameters | Purpose |
|---|---|---|
| `task_search` | `query`, `result_count`, `had_ai_refinement`, `latency_ms` | Measure search volume and AI usage |
| `task_result_tap` | `department_id`, `position` (1st/2nd/3rd), `action_type` (open/call/website/directions/save) | Measure which results and actions users engage with |
| `task_no_result` | `query` | Identify data gaps and missing keyword coverage |
| `task_clarify_shown` | `query`, `clarifying_question` | Track when confidence is low |
| `task_clarify_answered` | `query`, `answer` | Track follow-up engagement |

Feed `task_no_result` queries into a dashboard to prioritize keyword/service data improvements.

## Data and code fit

The current architecture already supports this well:

- `DepartmentProvider` can expose a new `findDepartmentsForTask(...)` flow.
- `DepartmentService` can orchestrate local ranking first, then optional AI refinement.
- `OpenAIService` already supports both contextual and general prompts and can be extended with a structured JSON response.
- `Department` already carries the fields needed to explain and action results.

### Pre-work: consolidate duplicated code

Before building `TaskFinderScreen`, address existing duplication to prevent a third copy:

- Extract `_getCategoryIcon` and `_getCategoryGradient` from `home_screen.dart` and `department_compare_screen.dart` into a shared `CategoryUtils` class.
- Consolidate the filter logic in `DepartmentCompareScreen._getFilteredDepartments()` to use `DepartmentProvider` instead of its own local copy.
- Add `services` to the existing `_applyFilters()` search scope in `DepartmentProvider`.

## Suggested implementation details

- Add optional metadata fields later, not on day 1:
  - `commonTasks`
  - `eligibilityHints`
  - `applicationLinks`
  - `appointmentRequired`
- Keep an offline fallback:
  - If AI is unavailable, still return ranked departments from local keyword/service matching.
- Keep the UX strict:
  - 1 primary answer
  - 2 backups max
  - 3 next steps max
- Put the result above the fold with action buttons. Do not make users open multiple screens before acting.
- Reuse existing widgets:
  - `AiSummaryCard` for the "why this matches" explanation.
  - The Q&A chat bubble pattern from `DepartmentDetailScreen` for follow-up task refinement.
  - `_buildQuickActionCard` pattern from `HomeScreen` for the entry point card.

## Why this beats other candidate improvements

I considered favorites sync/history and stronger notification personalization. Those would help retention, but they do not fix the biggest user-value gap: helping a user identify the right government office from a real-life need.

This feature improves discovery, activation, and action completion at the same time.

## Success metrics

- Higher rate of users opening a department from the first query
- Lower zero-result or abandoned-search rate
- Higher call/website/directions taps from task-finder results
- Higher save/favorite rate after guided matching
- Shorter time from app open to first useful action
- `task_no_result` rate decreasing over time as data gaps are filled

## Recommendation

If only one net-new user feature is added next, it should be the task-based service finder.

It matches the app's core purpose better than another browse enhancement, and it makes the existing AI, map, detail, favorites, and notification work much more useful.
