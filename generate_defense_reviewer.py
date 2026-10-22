import os
import subprocess
import sys

def build_html():
    html_content = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Grammatica - System Architecture & Mock Defense Reviewer</title>
<style>
  @page {
    size: A4;
    margin: 18mm 16mm 18mm 16mm;
    @bottom-right {
      content: counter(page);
      font-size: 9pt;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      color: #64748b;
    }
    @bottom-left {
      content: "Grammatica - Comprehensive System Architecture & Defense Reviewer";
      font-size: 8pt;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      color: #94a3b8;
    }
  }

  body {
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;
    color: #1e293b;
    line-height: 1.55;
    font-size: 10pt;
    background-color: #ffffff;
    margin: 0;
    padding: 0;
  }

  /* Cover Page */
  .cover {
    page-break-after: always;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    min-height: 90vh;
    text-align: center;
    padding: 40px 20px;
    background: linear-gradient(145deg, #f0fdf4 0%, #f8fafc 50%, #eff6ff 100%);
    border-radius: 12px;
    border: 1px solid #e2e8f0;
    box-sizing: border-box;
  }
  .cover-badge {
    background-color: #81B655;
    color: #ffffff;
    font-size: 10pt;
    font-weight: 700;
    padding: 6px 18px;
    border-radius: 9999px;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-bottom: 24px;
    box-shadow: 0 4px 10px rgba(129, 182, 85, 0.3);
  }
  .cover-title {
    font-size: 32pt;
    font-weight: 800;
    color: #0f172a;
    margin: 0 0 12px 0;
    line-height: 1.15;
    letter-spacing: -0.5px;
  }
  .cover-title span {
    color: #81B655;
  }
  .cover-subtitle {
    font-size: 14pt;
    font-weight: 500;
    color: #475569;
    max-width: 650px;
    margin: 0 0 36px 0;
    line-height: 1.4;
  }
  .cover-meta {
    background: #ffffff;
    border: 1px solid #cbd5e1;
    border-radius: 10px;
    padding: 20px 32px;
    display: inline-block;
    text-align: left;
    box-shadow: 0 4px 14px rgba(0, 0, 0, 0.05);
    margin-bottom: 30px;
  }
  .cover-meta table {
    border-collapse: collapse;
  }
  .cover-meta td {
    padding: 5px 12px;
    font-size: 9.5pt;
  }
  .cover-meta td.label {
    font-weight: 700;
    color: #334155;
  }
  .cover-meta td.val {
    color: #0f172a;
  }
  .cover-footer {
    font-size: 8.5pt;
    color: #64748b;
    margin-top: 20px;
  }

  /* Headings & Structure */
  h1 {
    font-size: 18pt;
    font-weight: 800;
    color: #0f172a;
    border-bottom: 2.5px solid #81B655;
    padding-bottom: 6px;
    margin-top: 28px;
    margin-bottom: 14px;
    page-break-before: always;
    page-break-after: avoid;
    letter-spacing: -0.3px;
  }
  h1:first-of-type {
    page-break-before: avoid;
  }
  h2 {
    font-size: 13pt;
    font-weight: 700;
    color: #1e293b;
    border-left: 4px solid #81B655;
    padding-left: 10px;
    margin-top: 22px;
    margin-bottom: 10px;
    page-break-after: avoid;
  }
  h3 {
    font-size: 11pt;
    font-weight: 700;
    color: #334155;
    margin-top: 16px;
    margin-bottom: 6px;
    page-break-after: avoid;
  }
  p {
    margin-top: 0;
    margin-bottom: 10px;
    text-align: justify;
  }
  ul, ol {
    margin-top: 0;
    margin-bottom: 12px;
    padding-left: 22px;
  }
  li {
    margin-bottom: 4px;
  }

  /* Callout Boxes */
  .callout {
    padding: 12px 16px;
    border-radius: 8px;
    margin: 14px 0;
    font-size: 9.5pt;
    border-left: 4px solid #81B655;
    background-color: #f8fafc;
    box-sizing: border-box;
    page-break-inside: avoid;
  }
  .callout-info {
    border-left-color: #0284c7;
    background-color: #f0f9ff;
  }
  .callout-success {
    border-left-color: #81B655;
    background-color: #f0fdf4;
  }
  .callout-warning {
    border-left-color: #f59e0b;
    background-color: #fffbeb;
  }
  .callout-defense {
    border-left-color: #8b5cf6;
    background-color: #f5f3ff;
  }
  .callout-title {
    font-weight: 700;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  /* Tables */
  table.data-table {
    width: 100%;
    border-collapse: collapse;
    margin: 14px 0 18px 0;
    font-size: 8.8pt;
    page-break-inside: auto;
  }
  table.data-table th {
    background-color: #f1f5f9;
    color: #0f172a;
    font-weight: 700;
    border: 1px solid #cbd5e1;
    padding: 8px 10px;
    text-align: left;
  }
  table.data-table td {
    border: 1px solid #e2e8f0;
    padding: 7px 10px;
    vertical-align: top;
  }
  table.data-table tr:nth-child(even) {
    background-color: #f8fafc;
  }
  table.data-table tr {
    page-break-inside: avoid;
  }

  /* Code & Diagrams */
  code {
    font-family: 'Consolas', 'Fira Code', Courier, monospace;
    font-size: 8.5pt;
    background-color: #f1f5f9;
    padding: 2px 5px;
    border-radius: 4px;
    color: #0f172a;
  }
  pre {
    background-color: #0f172a;
    color: #f8fafc;
    padding: 12px 14px;
    border-radius: 8px;
    font-family: 'Consolas', 'Fira Code', Courier, monospace;
    font-size: 8pt;
    overflow-x: auto;
    margin: 12px 0;
    page-break-inside: avoid;
    line-height: 1.45;
  }

  /* Math Blocks */
  .math-card {
    background: #ffffff;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    padding: 12px 16px;
    margin: 12px 0;
    font-family: 'Georgia', serif;
    font-size: 9.5pt;
    color: #1e293b;
    page-break-inside: avoid;
    box-shadow: 0 2px 6px rgba(0,0,0,0.03);
  }
  .math-title {
    font-family: 'Segoe UI', sans-serif;
    font-weight: 700;
    color: #81B655;
    font-size: 9pt;
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 6px;
  }

  /* Badges */
  .badge {
    display: inline-block;
    padding: 2px 7px;
    font-size: 7.5pt;
    font-weight: 700;
    border-radius: 4px;
    text-transform: uppercase;
    margin-right: 4px;
  }
  .badge-learner { background-color: #e0f2fe; color: #0369a1; }
  .badge-educator { background-color: #dcfce7; color: #15803d; }
  .badge-validator { background-color: #fef3c7; color: #b45309; }
  .badge-admin { background-color: #fae8ff; color: #86198f; }

  /* Table of Contents */
  .toc-item {
    display: flex;
    justify-content: space-between;
    padding: 4px 0;
    border-bottom: 1px dotted #cbd5e1;
    font-size: 9.5pt;
  }
  .toc-title { font-weight: 600; color: #1e293b; }
  .toc-sec { color: #81B655; font-weight: 700; margin-right: 8px; }

  /* Defense QA */
  .qa-card {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 12px 14px;
    margin-bottom: 12px;
    page-break-inside: avoid;
    box-shadow: 0 2px 5px rgba(0,0,0,0.02);
  }
  .qa-q {
    font-weight: 700;
    color: #1e293b;
    font-size: 9.8pt;
    margin-bottom: 6px;
  }
  .qa-q span {
    color: #81B655;
    margin-right: 4px;
  }
  .qa-a {
    color: #334155;
    font-size: 9pt;
    line-height: 1.5;
  }
  .qa-tag {
    font-size: 7.5pt;
    background-color: #f1f5f9;
    color: #475569;
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
    float: right;
  }
</style>
</head>
<body>

<!-- COVER PAGE -->
<div class="cover">
  <div class="cover-badge">Academic Capstone Defense Reviewer</div>
  <h1 class="cover-title" style="page-break-before: avoid; border: none; padding: 0;">GRAMMATICA<span>.SITE</span></h1>
  <div class="cover-subtitle">Comprehensive System Architecture, Technical Implementation Manual, and Complete Source Code Reviewer for Capstone Mock Defense</div>
  
  <div class="cover-meta">
    <table>
      <tr>
        <td class="label">Project Title:</td>
        <td class="val">Grammatica: An Intelligent Multi-Modal Language Learning and Mentorship Platform</td>
      </tr>
      <tr>
        <td class="label">Primary Technology Stack:</td>
        <td class="val">Flutter 3.x (Web & Android APK), Firebase Firestore, Firebase Auth, FastAPI Backend (Distributed Idempotency Engine), Google Gemini 2.5 Flash, Agora RTC, PayMongo API (QR Ph & Idempotent Checkout), Brevo Transactional Email, Vosk Acoustic Engine</td>
      </tr>
      <tr>
        <td class="label">Target Review:</td>
        <td class="val">Mock Defense & Final Oral Defense Preparation</td>
      </tr>
      <tr>
        <td class="label">Document Scope:</td>
        <td class="val">Architectural Principles, Subsystem Implementations, Theoretical Algorithms, Distributed Idempotency Engine, File-by-File Catalog (85+ Dart files), Panelist Q&A</td>
      </tr>
      <tr>
        <td class="label">Version & Date:</td>
        <td class="val">Version 2.5.0 • Academic Year 2026</td>
      </tr>
    </table>
  </div>

  <div class="cover-footer">
    Developed for rigorous evaluation by the Capstone Defense Panel. Contains comprehensive explanations of algorithms, database structures, security protocols, and integration pipelines.
  </div>
</div>

<!-- TABLE OF CONTENTS -->
<h1 style="page-break-before: avoid;">Table of Contents</h1>
<div style="margin-top: 15px; margin-bottom: 30px;">
  <div class="toc-item"><span class="toc-title"><span class="toc-sec">1.0</span>Executive Summary & Theoretical Foundations</span></div>
  <div class="toc-item"><span class="toc-title"><span class="toc-sec">2.0</span>End-to-End System Architecture & High-Level Data Flow</span></div>
  <div class="toc-item"><span class="toc-title"><span class="toc-sec">3.0</span>Core Subsystems & Technical Implementation Deep-Dive</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.1</span>Authentication, Brute-Force Defense & Session Security</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.2</span>Role-Based Access Control (RBAC) & Governance Pipeline</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.3</span>AI Educational Notebook & Multi-Modal Source Ingestion</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.4</span>Cognitive Retention & Spaced Repetition (SuperMemo SM-2)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.5</span>Interactive Gamified Learning & Acoustic Speech Evaluation</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.6</span>Real-Time Video Conferencing & Mentorship (Agora RTC)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.7</span>Monetization, PayMongo Dynamic Checkout & Email Receipts</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.8</span>Distributed Idempotency Architecture & Financial Double-Charge Prevention</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">3.9</span>Content Moderation, Verification & Mandatory Denial Auditing</span></div>
  <div class="toc-item"><span class="toc-title"><span class="toc-sec">4.0</span>Exhaustive File-by-File Catalog (Every Single .dart File)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.1</span>Configuration & Theme Layer (<code>lib/config/</code>, <code>lib/theme/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.2</span>Domain Models & Data Structures (<code>lib/models/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.3</span>Central Services & Repositories (<code>lib/services/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.4</span>UI Presentation Pages & Workspaces (<code>lib/pages/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.5</span>Educational Notebook Workspaces (<code>lib/pages/notebook/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.6</span>Administration & Verification Tabs (<code>lib/pages/admin/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.7</span>Reusable UI Components & Widgets (<code>lib/widgets/</code>)</span></div>
  <div class="toc-item" style="padding-left: 20px;"><span class="toc-title"><span class="toc-sec">4.8</span>Utilities & Platform Helpers (<code>lib/utils/</code>)</span></div>
  <div class="toc-item"><span class="toc-title"><span class="toc-sec">5.0</span>Microservices AI Backend & LLM Fine-Tuning (FastAPI & LoRA)</span></div>
  <div class="toc-item"><span class="toc-title"><span class="toc-sec">6.0</span>Anticipated Defense Questions & Panel Defense Guide (Top 27 Q&A)</span></div>
</div>

<!-- SECTION 1: EXECUTIVE SUMMARY -->
<h1>1.0 Executive Summary & Theoretical Foundations</h1>

<p>
<strong>Grammatica</strong> is a state-of-the-art, cross-platform language learning ecosystem designed to overcome the critical limitations of contemporary language acquisition platforms. Conventional platforms predominantly deliver static, repetitive drills that lack pedagogical contextualization, fail to support multimodal learning materials, and disconnect asynchronous practice from real-time certified educator mentorship.
</p>

<p>
To address this challenge, Grammatica harmonizes three pillars of cognitive science and software engineering:
</p>

<ol>
  <li><strong>Multimodal Knowledge Ingestion & Contextual AI Synthesis:</strong> Instead of relying on generic pre-canned sentences, educators and learners can ingest real-world curricular materials (PDF documents, syllabus chapters, scholarly web pages, and raw text notes). Powered by the Google Gemini 2.5 Flash large language model, Grammatica parses and transforms these unstructured documents into high-retention pedagogical artifacts: structured interactive lessons, formative assessments, flashcard decks, hierarchical mind maps, chronological timelines, and concise briefing documents.</li>
  <li><strong>Empirical Spaced Repetition (The SuperMemo SM-2 Algorithm):</strong> Based on Hermann Ebbinghaus’s Forgetting Curve theory, Grammatica incorporates an algorithmic spaced repetition engine. Card review intervals and ease factors dynamically adjust based on individual recall quality scores, ensuring durable memory consolidation with minimal study fatigue.</li>
  <li><strong>Synchronous Human Mentorship & Secure Monetization:</strong> Grammatica integrates low-latency, WebRTC-powered video conferencing through the Agora RTC Engine, alongside secure payment processing via the PayMongo API (supporting GCash, Maya, GrabPay, and credit/debit cards). Educators can monetize their expertise through customizable subscription tiers and scheduled 1-on-1 mentorship sessions, complete with automated transactional email receipts.</li>
</ol>

<div class="callout callout-info">
  <div class="callout-title">Key Defense Talking Point: The Architectural Problem Statement</div>
  Traditional apps suffer from "context detachment." Grammatica provides "curriculum-grounded learning"—the AI acts as an instructional designer, translating authentic educational material into active retrieval practice while certified educators provide live accountability and guidance.
</div>

<!-- SECTION 2: SYSTEM ARCHITECTURE -->
<h1>2.0 End-to-End System Architecture</h1>

<p>
Grammatica is engineered using a robust, decoupled, and highly responsive <strong>Service-Oriented Architecture (SOA)</strong> paired with the <strong>Repository Pattern</strong> on the Flutter client and asynchronous microservices on the Python backend.
</p>

<div class="callout callout-success">
  <div class="callout-title">Architectural Topology</div>
  <pre>
+-----------------------------------------------------------------------------------------+
|                                    PRESENTATION LAYER                                   |
|   Flutter 3.x Multi-Platform Engine (Web Responsive SPA & Android APK Native Binary)     |
|   - Provider / Reactive Stateful Controllers   - Custom Material 3 Theming (Light/Dark) |
+-----------------------------------------------------------------------------------------+
                                           |
                                           v
+-----------------------------------------------------------------------------------------+
|                                 CLIENT APPLICATION SERVICES                             |
|  - AuthService         - DatabaseService      - RoleService       - AIRateLimitService  |
|  - NotebookService    - AgoraService         - PaymongoService   - SpacedRepetitionSvc |
|  - EmailSenderService - SourceIngestionSvc   - DeviceSessionSvc  - IdempotencyService  |
|  - WebServiceWeb      - VoskServiceNative    - AppRepository     - NavigationService   |
+-----------------------------------------------------------------------------------------+
           |                               |                               |
           v                               v                               v
+-----------------------+     +-----------------------+     +-----------------------------+
|    CLOUD BACKEND      |     |  FASTAPI AI GATEWAY   |     |    EXTERNAL INTEGRATIONS    |
| Firebase Firestore    |     | Python 3.13 Microsvc  |     | - Google Gemini 2.5 Flash   |
| - /payments/ Ledger   |     | - Idempotency Store   |     | - Agora RTC Cloud Engine    |
| - /idempotency_keys/  |     | - Webhook Mutex Lock  |     | - PayMongo Payment Gateway  |
| Firebase Auth (OAuth) |     | - Gemini SDK Pipeline |     |   (Idempotent QR Ph & Card) |
| Firebase Storage      |     | - PDF / Web Scraper   |     | - Brevo Transactional Email |
| Firestore Rules & RBAC|     | - Fine-Tuned LoRA     |     |   (Deduplicated Receipts)   |
+-----------------------+     +-----------------------+     +-----------------------------+
  </pre>
</div>

<h2>2.1 Client-Side Architectural Principles</h2>
<ul>
  <li><strong>Single Source of Truth:</strong> <code>DatabaseService</code> acts as the canonical data gatekeeper, exposing continuous, real-time reactive streams (<code>StreamBuilder</code>) from Cloud Firestore. Data mutations are optimistically reflected in the UI while ensuring atomic cloud persistence.</li>
  <li><strong>Cross-Platform Conditional Compilation:</strong> The codebase leverages conditional imports (e.g., <code>web_service_web.dart</code> vs <code>web_service_stub.dart</code>, and <code>vosk_service_native.dart</code> vs <code>vosk_service_stub.dart</code>). This enables native Android builds to execute high-performance C++ speech binaries (Vosk offline acoustic model) while web builds gracefully adapt to browser standards and CORS proxy relays without crashing.</li>
  <li><strong>Distributed Idempotency & Financial Safety:</strong> End-to-end multi-tier deduplication protects against double billing, duplicate bookings, and race conditions across client (single-flight coalescing), gateway (SHA-256 fingerprinting & 409 Conflict locks), and database (check-and-set Firestore ledgers) layers.</li>
  <li><strong>Strict Defensive Input Validation:</strong> Every single required user entry point is enforced both on the UI layer (displaying visual asterisk <code>*</code> indicators and inline regex validators) and within service invocation guards.</li>
</ul>

<!-- SECTION 3: CORE SUBSYSTEMS -->
<h1>3.0 Core Subsystems & Technical Implementation</h1>

<h2>3.1 Authentication, Brute-Force Defense & Session Security</h2>
<p>
Authentication is managed via <code>AuthService</code> and backed by Firebase Authentication, supporting traditional credential login, federated Google OAuth, and Phone OTP verification.
</p>

<h3>Brute-Force Attack Mitigation (The 3-Attempt Lockout System)</h3>
<p>
To prevent credential stuffing and brute-force password guessing, Grammatica implements a sophisticated local-and-cloud session gatekeeper encapsulated in <code>DeviceSessionService</code>:
</p>
<ul>
  <li><strong>Failure Tracking:</strong> Every failed login attempt increments a device-session counter stored in encrypted local preferences (<code>SharedPreferences</code>).</li>
  <li><strong>Lockout Threshold:</strong> Upon reaching <strong>3 consecutive failed attempts</strong>, the device is immediately placed in a strict <strong>5-minute lockout state</strong>. All authentication buttons are disabled, and a persistent visual countdown timer is presented to the user.</li>
  <li><strong>Sliding Reset Window:</strong> If a user fails once or twice but does not attempt another login for <strong>15 minutes</strong>, the failed attempts counter automatically resets to zero, preventing false-positive lockouts for legitimate users over long intervals.</li>
  <li><strong>Successful Authentication:</strong> Any verified login instantly wipes all failure counters and lockout timestamps.</li>
</ul>

<h3>Sensitive Operation Re-Authentication Protocol</h3>
<p>
In compliance with cybersecurity best practices, high-risk actions—such as modifying primary display names, resetting passwords, changing registered phone numbers, or executing account deletions—cannot be triggered silently. Grammatica prompts an obligatory modal (<code>_ReauthDialog</code>) requiring the user to re-input their existing credentials to obtain a fresh Firebase Auth Token before mutating the database.
</p>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.2 Role-Based Access Control (RBAC) & Governance Pipeline</h2>
<p>
Grammatica enforces a rigorous 4-tier RBAC architecture defined in <code>RoleService</code>:
</p>

<table class="data-table">
  <thead>
    <tr>
      <th>Role</th>
      <th>Permissions & System Capabilities</th>
      <th>AI Daily Quota</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><span class="badge badge-learner">Learner</span></td>
      <td>Access public & subscribed lessons, take practice quizzes, participate in Spelling Bee & Pronunciation quizzes, book live mentorship, maintain personal study notebooks, manage subscriptions.</td>
      <td><strong>20 requests / day</strong></td>
    </tr>
    <tr>
      <td><span class="badge badge-educator">Educator</span></td>
      <td>All Learner privileges + Author custom lessons & quizzes, schedule mentorship sessions via Agora, configure Standard/Premium subscription tiers, upload multi-modal syllabus sources, review subscriber rosters.</td>
      <td><strong>50 requests / day</strong></td>
    </tr>
    <tr>
      <td><span class="badge badge-validator">Validator</span></td>
      <td>Audit public content queue, review published lessons & quizzes for grammatical correctness and community standards, approve or deny content with mandatory audit logging.</td>
      <td><strong>100 requests / day</strong></td>
    </tr>
    <tr>
      <td><span class="badge badge-admin">Admin</span></td>
      <td>Global superuser: Manage user roles, revoke permissions, configure landing page settings, inspect comprehensive system telemetry, broadcast notifications, bypass quota limits.</td>
      <td><strong>Unlimited (&infin;)</strong></td>
    </tr>
  </tbody>
</table>

<p>
<strong>Role Elevation Workflow:</strong> Users register by default as Learners. To become an Educator or Validator, users must submit an official application through <code>RoleApplicationPage</code>, uploading credentials, institutional affiliations, and government-issued IDs. These submissions are vetted by Validators and finalized by Administrators.
</p>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.3 AI Educational Notebook & Multi-Modal Source Ingestion</h2>
<p>
The <strong>Educator's AI Notebook</strong> represents Grammatica’s core technical innovation. Rather than relying on ungrounded generative prompts that frequently hallucinate, Grammatica implements a <strong>Grounding-First Pipeline</strong>:
</p>

<ol>
  <li><strong>Source Ingestion (<code>SourceIngestionService</code>):</strong>
    <ul>
      <li><strong>PDF Ingestion:</strong> Extracts textual streams directly from uploaded academic documents and lecture slide decks.</li>
      <li><strong>Web Page Ingestion:</strong> Fetches external articles, grammar guides, or encyclopedia links, stripping extraneous HTML boilerplates and script tags. Web clients utilize an intelligent CORS relay to ensure seamless browser parsing.</li>
      <li><strong>Direct Text Notes:</strong> Allows educators to paste custom curriculum outlines, lecture transcripts, or vocabulary lists.</li>
    </ul>
  </li>
  <li><strong>Structured Prompt Engineering (<code>notebook_prompts.dart</code> & <code>ai_logic_service.dart</code>):</strong>
    Raw text chunks are wrapped in specialized system instructions instructing Gemini 2.5 Flash to generate deterministic, syntactically valid JSON structures.
  </li>
  <li><strong>Pedagogical Artifact Synthesis:</strong>
    From a single source, the engine can synthesize:
    <ul>
      <li><strong>Interactive Lessons:</strong> Markdown-formatted explanatory articles featuring headings, bold grammar concepts, illustrative image blocks, and companion quiz linkages.</li>
      <li><strong>Formative Quizzes:</strong> Multi-format questions (Multiple Choice with distractor explanations, Fill-in-the-Blank, Direct Identification, Reading Passages, and Image Questions).</li>
      <li><strong>Flashcard Decks:</strong> Front/back vocabulary cards paired with phonetics and example sentences.</li>
      <li><strong>Study Guides, Mind Maps, Timelines, & FAQs:</strong> Structured visual and textual artifacts catering to diverse learning modalities.</li>
    </ul>
  </li>
  <li><strong>Double-Click Prevention & Quota Guards:</strong>
    To prevent network congestion and redundant token consumption, all AI generation triggers are wrapped in <code>GenerationLoadingOverlay</code>. The UI disables triggering buttons and displays rotating pedagogical progress indicators until the transaction fully resolves.
  </li>
</ol>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.4 Cognitive Retention & Spaced Repetition (SuperMemo SM-2)</h2>
<p>
Flashcards in Grammatica are not simply shuffled randomly. They are scheduled according to the celebrated <strong>SuperMemo SM-2 Spaced Repetition Algorithm</strong>, mathematically modeled inside <code>SpacedRepetitionService</code>.
</p>

<div class="math-card">
  <div class="math-title">Mathematical Formulation of the SM-2 Engine</div>
  <p>For each review session, the user evaluates their recall quality $q \in \{0, 1, 2, 3, 4, 5\}$:</p>
  <ul>
    <li>$q = 5$: Perfect response, zero hesitation.</li>
    <li>$q = 4$: Correct response after slight hesitation.</li>
    <li>$q = 3$: Correct response recalled with serious difficulty.</li>
    <li>$q = 2$: Incorrect response; where the correct answer seemed easy to recall.</li>
    <li>$q = 1$: Incorrect response; familiar with the word but failed to recall.</li>
    <li>$q = 0$: Complete blackout.</li>
  </ul>
  
  <p><strong>1. Ease Factor ($EF$) Calculation:</strong></p>
  <pre>EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))</pre>
  <p><em>Constraint: $EF' \ge 1.30$. If $EF'$ drops below 1.30, it is clamped to 1.30 to prevent perpetual scheduling stagnation. Default initial $EF = 2.50$.</em></p>

  <p><strong>2. Inter-Repetition Interval ($I$) Calculation:</strong></p>
  <pre>
If q < 3 (Recall Failure):
    Repetitions (n) = 0
    Next Interval I(1) = 1 day

If q >= 3 (Recall Success):
    If n == 0: I(1) = 1 day
    If n == 1: I(2) = 6 days
    If n >= 2: I(n) = I(n-1) * EF'
    Repetitions (n) = n + 1
  </pre>
</div>

<p>
<strong>Firestore Persistence:</strong> Each user's card metadata (<code>easeFactor</code>, <code>interval</code>, <code>repetitions</code>, <code>nextReviewDate</code>, <code>reviewCount</code>) is persisted atomically in Firestore. When opening <code>LearnerDecksPage</code>, Grammatica queries cards where <code>nextReviewDate <= DateTime.now()</code>, presenting learners with precisely calibrated daily review queues.
</p>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.5 Interactive Gamified Learning & Acoustic Speech Evaluation</h2>
<h3>Spelling Bee Game Engine (<code>SpellingBeePage</code>)</h3>
<p>
The Spelling Bee module presents learners with auditory vocabulary challenges. The word is played using speech synthesis while contextual definitions and part-of-speech hints are rendered. Learners enter their answer letter-by-letter with instant reactive feedback, streak multipliers, sound effects, and confetti celebrations upon completion. Words are organized by difficulty (<code>easy</code>, <code>medium</code>, <code>hard</code>) managed through the Admin Spelling Words tab.
</p>

<h3>Acoustic Pronunciation Quiz Engine (<code>PronunciationQuizPage</code> & <code>VoskService</code>)</h3>
<p>
Pronunciation practice requires evaluating spoken audio against phonetic standards. Grammatica employs a hybrid architecture:
</p>
<ul>
  <li><strong>Mobile Native Android APK:</strong> Integrates an offline, privacy-first <strong>Vosk Acoustic Model</strong> via dynamic C++ platform channels (<code>vosk_service_native.dart</code>). Audio waveforms recorded from the device microphone are processed locally into phoneme sequences, calculating a percentage match score without sending voice recordings to external servers.</li>
  <li><strong>Web Application SPA:</strong> Seamlessly falls back to the Web Speech Recognition API (<code>vosk_service_stub.dart</code>) to guarantee zero setup barriers on modern web browsers.</li>
</ul>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.6 Real-Time Video Conferencing & Mentorship (Agora RTC)</h2>
<p>
Mentorship sessions take place within Grammatica's native video conferencing portal (<code>ConferencePage</code>), built upon the <strong>Agora RTC SDK</strong>:
</p>
<ul>
  <li><strong>Token Generation Pipeline:</strong> When a learner or educator joins a conference room, <code>AgoraService</code> requests or dynamically calculates an authorized HMAC-SHA256 RTC token using the app's secure credentials, ensuring unauthorized third parties cannot eavesdrop on private sessions.</li>
  <li><strong>Cross-Platform Media Engine:</strong> The client establishes an ultra-low latency WebRTC stream. Native mobile builds render hardware-accelerated video frames via Android SurfaceViews, while web clients mount dynamic HTML5 video elements.</li>
  <li><strong>Concurrent Real-Time Chat:</strong> Participants can toggle microphones, flip cameras, and communicate via a synchronized side chat stream backed by Firestore real-time snapshots.</li>
</ul>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.7 Monetization, PayMongo Dynamic Checkout & Email Receipts</h2>
<p>
Grammatica enables educators to commercialize their pedagogical work through subscription tiers:
</p>
<ul>
  <li><strong>Tier Structure:</strong> <em>Standard Tier</em> (Up to $10/mo - grants access to exclusive educator lessons and quiz folders) and <em>Premium Tier</em> (Up to $30/mo - includes 1-on-1 scheduled live Agora mentorship sessions).</li>
  <li><strong>PayMongo API Integration (<code>PayMongoService</code>):</strong>
    <ul>
      <li><strong>Dynamic Hosted Checkout:</strong> Generates secure PayMongo checkout sessions supporting credit/debit cards, GCash, Maya, and GrabPay. All link generation calls attach cryptographic <code>Idempotency-Key</code> headers and cache active URLs in-memory to prevent duplicate checkout creations.</li>
      <li><strong>Direct QR Ph Code Fallback:</strong> Generates real-time, high-contrast QR Ph payment strings displayed in a dedicated modal (<code>PaymongoQrDialog</code>). Users scan the QR directly in banking apps. A single-shot mutex (<code>_hasDispatchedSuccess</code>) prevents race conditions between polling timers and manual triggers.</li>
    </ul>
  </li>
  <li><strong>Automated Transactional Email Receipts (<code>EmailSenderService</code>):</strong>
    Upon successful payment confirmation, the system generates an itemized, responsive HTML receipt and dispatches it directly to the customer's email via the <strong>Brevo API</strong> (Sendinblue), complete with transaction ID, tier details, and renewal dates. A local Dart email relay (<code>scripts/local_email_relay.dart</code>) serves as a zero-downtime offline fallback during local testing. Duplicate receipt dispatch is strictly blocked by the idempotency ledger.
  </li>
</ul>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.8 Distributed Idempotency Architecture & Financial Double-Charge Prevention</h2>
<p>
In financial and distributed systems, network unreliability and rapid user interactions can lead to severe side-effects such as double billing, duplicate session bookings, and redundant AI credit deductions. To guarantee absolute consistency, Grammatica implements a cohesive <strong>3-Tier Distributed Idempotency Architecture</strong> spanning client, gateway, and database layers:
</p>

<div class="callout callout-defense">
  <div class="callout-title">The Three Pillars of Grammatica Idempotency</div>
  <ol style="margin-bottom: 0;">
    <li><strong>Client-Tier Single-Flight Coalescing (<code>IdempotencyService</code>):</strong> Rapid button taps within short windows join the exact same active <code>Future</code>, completely preventing multiple concurrent HTTP requests from ever leaving the client device. Deterministic RFC 4122 v4 keys (<code>pay_link_{studentId}_{educatorId}_{timestampMinutes}</code>) guarantee replay safety.</li>
    <li><strong>Gateway Middleware Fingerprinting (<code>IdempotencyMiddleware</code> & <code>IdempotencyStore</code>):</strong> Mutating HTTP routes (<code>POST</code>, <code>PUT</code>, <code>PATCH</code>, <code>DELETE</code>) are locked via SHA-256 payload fingerprints. Concurrent requests return <code>HTTP 409 Conflict</code> (with <code>Retry-After: 2</code>); modified payloads under the same key reject with <code>HTTP 422 Unprocessable Entity</code>; and repeated identical calls replay the cached response with <code>Idempotent-Replay: true</code>.</li>
    <li><strong>Database Transactional Check-and-Set Ledger (<code>DatabaseService</code>):</strong> Transactions in <code>/payments/{paymentId}</code> use deterministic doc IDs (<code>pay_{linkId}</code>). Existing <code>paid</code> records return <code>PaymentRecordResult(isDuplicate: true)</code>, safely skipping duplicate subscription increments and redundant email receipts.</li>
  </ol>
</div>

<p>
<strong>PayMongo Webhook Deduplication:</strong> Inbound webhooks from payment gateways operate on an <em>at-least-once delivery</em> model. The FastAPI webhook route locks each event ID (<code>evt_...</code>) via <code>IdempotencyStore</code>. Whichever path resolves first—the background webhook or the client’s foreground polling loop—commits the payment atomically. The secondary process recognizes the existing record, flags it as duplicate, and quietly exits without side-effects.
</p>

<hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;">

<h2>3.9 Content Moderation, Verification & Mandatory Denial Auditing</h2>
<p>
To ensure curricular excellence, educator-published lessons and quizzes enter a pending verification queue reviewed by certified Validators (<code>ValidatorDashboardTab</code>).
</p>
<div class="callout callout-warning">
  <div class="callout-title">The Mandatory Denial Explanation Protocol (<code>ContentDenialDialog</code>)</div>
  To prevent arbitrary or biased censorship, a Validator <strong>cannot</strong> reject content with a single click. If a Validator clicks "Deny", the system forces open <code>ContentDenialDialog</code>, which requires a <strong>minimum 30-character comprehensive explanation</strong> citing pedagogical shortcomings or guideline infractions. This audit log is permanently stored in Firestore and dispatched to the educator to facilitate constructive revision.
</div>

<!-- SECTION 4: EXHAUSTIVE FILE-BY-FILE CATALOG -->
<h1>4.0 Exhaustive File-by-File Codebase Catalog</h1>
<p>
Below is an exhaustive architectural catalog detailing every relevant <code>.dart</code> source file across the Grammatica project, explaining its exact responsibility, key classes, and design decisions.
</p>

<h2>4.1 Configuration & Theme Layer (<code>lib/config/</code>, <code>lib/theme/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/config/ai_config.dart</code></td>
      <td><code>AIConfig</code></td>
      <td>Defines constants for AI generation: default model identifier (<code>gemini-2.5-flash</code>), temperature settings, topP, topK, maximum token limits, and safety category thresholds to prevent toxic output.</td>
    </tr>
    <tr>
      <td><code>lib/config/notebook_prompts.dart</code></td>
      <td><code>NotebookPrompts</code></td>
      <td>Contains strictly structured system prompts for generating lessons, quizzes, flashcards, mind maps, study guides, timelines, briefings, and FAQs from raw educational sources.</td>
    </tr>
    <tr>
      <td><code>lib/theme/app_colors.dart</code></td>
      <td><code>AppColors</code></td>
      <td>Central palette design system: Primary Green (<code>#81B655</code>), Deep Slate, Accent Purples, Dark Mode Backgrounds (<code>#1A1D1A</code>), semantic feedback greens/reds, and card elevation borders.</td>
    </tr>
    <tr>
      <td><code>lib/theme/app_theme.dart</code></td>
      <td><code>AppTheme</code></td>
      <td>Implements Material 3 <code>ThemeData</code> for both Light and Dark modes. Configures Google Fonts (Outfit for headings, Inter for body copy), input decoration themes, elevated button styles, and card themes.</td>
    </tr>
    <tr>
      <td><code>lib/firebase_options.dart</code></td>
      <td><code>DefaultFirebaseOptions</code></td>
      <td>Auto-generated Firebase CLI configuration providing platform-specific API keys, Project IDs, Storage Buckets, and App IDs for Android, Web, and iOS deployments.</td>
    </tr>
    <tr>
      <td><code>lib/main.dart</code></td>
      <td><code>GrammaticaApp</code>, <code>main()</code></td>
      <td>Application entry point. Initializes Flutter bindings, loads environment variables (<code>.env</code>), initializes Firebase, configures navigation observers, and boots the initial authentication state router.</td>
    </tr>
  </tbody>
</table>

<h2>4.2 Domain Models & Data Structures (<code>lib/models/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/models/ai_models.dart</code></td>
      <td><code>AIQuizResponse</code>, <code>AIQuestion</code>, <code>AILessonResponse</code>, <code>ContentBlock</code></td>
      <td>JSON-serializable data models mapping structured responses from Google Gemini into typed Flutter objects. Includes helper methods for Markdown conversion and image block binding.</td>
    </tr>
    <tr>
      <td><code>lib/models/content_visibility.dart</code></td>
      <td><code>ContentVisibility</code> (Enum)</td>
      <td>Defines content visibility tiers: <code>public</code> (free for all), <code>subscribersOnly</code> (requires active educator subscription), and <code>private</code> (draft / personal).</td>
    </tr>
    <tr>
      <td><code>lib/models/flashcard_models.dart</code></td>
      <td><code>FlashcardDeck</code>, <code>FlashcardItem</code></td>
      <td>Represents flashcard collections. Contains SuperMemo SM-2 state fields: <code>easeFactor</code>, <code>intervalDays</code>, <code>repetitionNumber</code>, <code>nextReviewDate</code>, and mastery percentages.</td>
    </tr>
    <tr>
      <td><code>lib/models/notebook_models.dart</code></td>
      <td><code>Notebook</code>, <code>NotebookSource</code>, <code>NotebookOutput</code></td>
      <td>Core models for the AI Notebook workspace. Tracks ingested source documents (PDF, URL, Text) and synthesized outputs (Lesson, Quiz, MindMap, Timeline, FAQ, Briefing, StudyGuide).</td>
    </tr>
    <tr>
      <td><code>lib/models/notification.dart</code></td>
      <td><code>AppNotification</code></td>
      <td>Data model for in-app user notifications (e.g., mentorship confirmations, payment receipts, validation status changes, content approval/denial alerts).</td>
    </tr>
    <tr>
      <td><code>lib/models/published_content_item.dart</code></td>
      <td><code>PublishedContentItem</code></td>
      <td>Represents items submitted by educators to the public repository. Tracks verification status (<code>pending</code>, <code>approved</code>, <code>denied</code>), denial rationale, and validator UID.</td>
    </tr>
    <tr>
      <td><code>lib/models/payment_models.dart</code> (and <code>DatabaseService</code>)</td>
      <td><code>PaymentRecordResult</code></td>
      <td>Result object returned from payment ledger mutations. Encapsulates <code>isSuccess</code>, <code>isDuplicate</code>, <code>paymentId</code>, and human-readable audit messages to safely gate downstream receipt dispatch.</td>
    </tr>
    <tr>
      <td><code>lib/models/spelling_word.dart</code></td>
      <td><code>SpellingWord</code>, <code>SpellingDifficulty</code></td>
      <td>Defines vocabulary items for the Spelling Bee game: word text, phonetics, audio URL, definition, example sentence, and difficulty tier.</td>
    </tr>
    <tr>
      <td><code>lib/models/study_guide_models.dart</code></td>
      <td><code>StudyGuide</code>, <code>MindMapNode</code>, <code>TimelineEvent</code></td>
      <td>Hierarchical tree data structures for mind maps, chronologically ordered timeline nodes, and sectioned study guides.</td>
    </tr>
  </tbody>
</table>

<h2>4.3 Central Services & Repositories (<code>lib/services/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/services/auth_service.dart</code></td>
      <td><code>AuthService</code></td>
      <td>Handles user authentication lifecycle: email/password registration, login, logout, password reset emails, Google OAuth, sensitive operation re-authentication, and account deletion.</td>
    </tr>
    <tr>
      <td><code>lib/services/database_service.dart</code></td>
      <td><code>DatabaseService</code></td>
      <td>Massive (100KB) data access singleton. Manages all Cloud Firestore collections: user profiles, lesson CRUD, quiz CRUD, assessments, spelling words, mentorship sessions, reviews, denial audits, and the idempotent <code>PaymentLedger</code> (/payments/ & /idempotency_keys/) with check-and-set duplicate protection.</td>
    </tr>
    <tr>
      <td><code>lib/services/idempotency_service.dart</code></td>
      <td><code>IdempotencyService</code></td>
      <td>Client-side idempotency coordinator. Generates cryptographic RFC 4122 v4 UUIDs, deterministic payment/mentorship/AI keys, coalesces in-flight requests (single-flight deduplication), and persists cached results in local storage with TTL.</td>
    </tr>
    <tr>
      <td><code>lib/services/role_service.dart</code></td>
      <td><code>RoleService</code>, <code>UserRole</code></td>
      <td>Enforces Role-Based Access Control (RBAC). Evaluates role permissions, processes educator/validator applications, updates roles, and exposes real-time role streams.</td>
    </tr>
    <tr>
      <td><code>lib/services/ai_logic_service.dart</code></td>
      <td><code>AILogicService</code></td>
      <td>Direct low-level client for Google Gemini 2.5 Flash. Assembles prompt templates, enforces structured JSON response schemas, injects <code>Idempotency-Key</code> headers, handles API error parsing, and manages token usage.</td>
    </tr>
    <tr>
      <td><code>lib/services/ai_generation_service.dart</code></td>
      <td><code>AIGenerationService</code></td>
      <td>High-level orchestration service that coordinates source text extraction, quota validation, prompt dispatch, and model mapping for lessons, quizzes, and study guides with deterministic request keys.</td>
    </tr>
    <tr>
      <td><code>lib/services/ai_rate_limit_service.dart</code></td>
      <td><code>AIRateLimitService</code></td>
      <td>Enforces daily AI request quotas based on user roles. Increments usage counters in Firestore, calculates remaining quotas, and triggers reset checks at midnight UTC.</td>
    </tr>
    <tr>
      <td><code>lib/services/notebook_service.dart</code></td>
      <td><code>NotebookService</code></td>
      <td>Manages educator notebooks, source attachment, artifact synthesis persistence, citation linking, and direct export to the public publishing pipeline.</td>
    </tr>
    <tr>
      <td><code>lib/services/source_ingestion_service.dart</code></td>
      <td><code>SourceIngestionService</code></td>
      <td>Handles multi-modal file ingestion. Extracts clean text from uploaded PDFs, scrapes web articles via CORS-friendly relays, and normalizes plain text lecture notes.</td>
    </tr>
    <tr>
      <td><code>lib/services/spaced_repetition_service.dart</code></td>
      <td><code>SpacedRepetitionService</code></td>
      <td>Implements the SuperMemo SM-2 algorithm. Calculates next review intervals, ease factor modifications, updates flashcard review queues, and records recall session histories.</td>
    </tr>
    <tr>
      <td><code>lib/services/paymongo_service.dart</code></td>
      <td><code>PayMongoService</code></td>
      <td>Interacts with the PayMongo API. Creates dynamic checkout sessions (Cards, GCash, Maya) with injected <code>Idempotency-Key</code> headers, caches active payment links in-memory, generates high-contrast QR Ph codes, and coordinates single-shot UI locks.</td>
    </tr>
    <tr>
      <td><code>lib/services/email_sender_service.dart</code></td>
      <td><code>EmailSenderService</code></td>
      <td>Transactional email dispatcher. Transmits responsive HTML payment receipts and subscription renewal notifications via Brevo API, with local Dart relay fallback.</td>
    </tr>
    <tr>
      <td><code>lib/services/agora_service.dart</code></td>
      <td><code>AgoraService</code></td>
      <td>Manages Agora RTC Engine initialization, channel joining, dynamic token generation, audio/video device toggling, and multi-user stream event handling.</td>
    </tr>
    <tr>
      <td><code>lib/services/device_session_service.dart</code></td>
      <td><code>DeviceSessionService</code></td>
      <td>Security gatekeeper managing the 3-attempt brute-force protection. Enforces 5-minute lockout windows, 15-minute sliding resets, and persists device session fingerprints.</td>
    </tr>
    <tr>
      <td><code>lib/services/notification_service.dart</code></td>
      <td><code>NotificationService</code></td>
      <td>Creates in-app notifications, marks alerts as read/unread, and exposes live Firestore notification streams to the UI.</td>
    </tr>
    <tr>
      <td><code>lib/services/navigation_service.dart</code></td>
      <td><code>NavigationService</code></td>
      <td>Provides global navigator keys and helper methods for contextless navigation, route pushes, and deep link resolution.</td>
    </tr>
    <tr>
      <td><code>lib/services/vosk_service.dart</code> (and <code>_native</code>, <code>_stub</code>)</td>
      <td><code>VoskService</code></td>
      <td>Cross-platform abstraction for speech recognition. Executes offline Vosk acoustic models on native Android APK while stubbing for web standards.</td>
    </tr>
    <tr>
      <td><code>lib/services/web_service.dart</code> (and <code>_web</code>, <code>_stub</code>)</td>
      <td><code>WebService</code></td>
      <td>Platform-aware HTTP client with intelligent CORS proxy handling for web single-page app builds.</td>
    </tr>
    <tr>
      <td><code>lib/services/app_repository.dart</code></td>
      <td><code>AppRepository</code></td>
      <td>In-memory caching coordinator reducing repetitive network trips for static assets, category lists, and user preferences.</td>
    </tr>
  </tbody>
</table>

<h2>4.4 UI Presentation Pages & Workspaces (<code>lib/pages/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/pages/landing_page.dart</code></td>
      <td><code>LandingPage</code></td>
      <td>Public showcase landing page. Features hero banners, live preview cards, dynamic pricing matrices, testimonials, and direct onboarding call-to-actions.</td>
    </tr>
    <tr>
      <td><code>lib/pages/home_page.dart</code></td>
      <td><code>HomePage</code></td>
      <td>Learner dashboard. Displays daily learning streaks, recent progress cards, quick action shortcuts, recommended lessons, and active mentorship sessions.</td>
    </tr>
    <tr>
      <td><code>lib/pages/login_page.dart</code></td>
      <td><code>LoginPage</code></td>
      <td>User sign-in portal. Implements required field asterisks (<code>Email Address *</code>, <code>Password *</code>), 3-attempt lockout countdown, and Google OAuth trigger.</td>
    </tr>
    <tr>
      <td><code>lib/pages/signup_page.dart</code></td>
      <td><code>SignupPage</code></td>
      <td>3-Step registration wizard with real-time email availability validation, phone number formatting, password strength scoring, and terms of service modal.</td>
    </tr>
    <tr>
      <td><code>lib/pages/forgot_password_page.dart</code></td>
      <td><code>ForgotPasswordPage</code></td>
      <td>Password reset interface. Dispatches official Firebase recovery links to verified emails with real-time regex validation (<code>Recovery Email *</code>).</td>
    </tr>
    <tr>
      <td><code>lib/pages/otp_verification_page.dart</code></td>
      <td><code>OtpVerificationPage</code></td>
      <td>6-Digit SMS / Phone verification screen confirming user mobile identity during registration.</td>
    </tr>
    <tr>
      <td><code>lib/pages/onboarding_page.dart</code></td>
      <td><code>OnboardingPage</code></td>
      <td>Introductory carousel welcoming newly registered learners and demonstrating core features (Notebook, Mentorship, Games).</td>
    </tr>
    <tr>
      <td><code>lib/pages/profile_page.dart</code></td>
      <td><code>ProfilePage</code></td>
      <td>User profile manager. Allows updating usernames, phone numbers, bios, avatars, re-authenticating sensitive changes, and initiating account deletion.</td>
    </tr>
    <tr>
      <td><code>lib/pages/settings_page.dart</code></td>
      <td><code>SettingsPage</code></td>
      <td>User preferences portal. Controls Light/Dark mode toggling, audio playback settings, notification preferences, and legal disclaimers.</td>
    </tr>
    <tr>
      <td><code>lib/pages/practice_tab.dart</code></td>
      <td><code>PracticeTab</code></td>
      <td>Interactive practice hub offering entry points into Spelling Bee, Pronunciation Quizzes, and Formative Assessments.</td>
    </tr>
    <tr>
      <td><code>lib/pages/spelling_bee_page.dart</code></td>
      <td><code>SpellingBeePage</code></td>
      <td>Gamified spelling competition. Plays audio pronunciations, provides phonetic and definition hints, tracks streaks, and validates letter entries.</td>
    </tr>
    <tr>
      <td><code>lib/pages/pronunciation_quiz_page.dart</code></td>
      <td><code>PronunciationQuizPage</code></td>
      <td>Speech assessment interface. Records learner vocalization and compares phoneme sequences against targets using the Vosk acoustic model.</td>
    </tr>
    <tr>
      <td><code>lib/pages/quizzes_page.dart</code></td>
      <td><code>QuizzesPage</code></td>
      <td>Searchable quiz catalog categorized by grammar topic, difficulty level, and completion status.</td>
    </tr>
    <tr>
      <td><code>lib/pages/quiz_detail_page.dart</code></td>
      <td><code>QuizDetailPage</code></td>
      <td>Active quiz-taking environment. Handles multi-choice selection, identification textfields, passage display, timers, score computation, and answer explanations.</td>
    </tr>
    <tr>
      <td><code>lib/pages/quiz_folder_page.dart</code></td>
      <td><code>QuizFolderPage</code></td>
      <td>Hierarchical folder view grouping related quizzes under comprehensive curriculum modules.</td>
    </tr>
    <tr>
      <td><code>lib/pages/lesson_page.dart</code></td>
      <td><code>LessonPage</code></td>
      <td>Standard lesson reader presenting markdown content, audio pronunciation buttons, and companion quiz quick-navigation.</td>
    </tr>
    <tr>
      <td><code>lib/pages/lesson_folder_page.dart</code></td>
      <td><code>LessonFolderPage</code></td>
      <td>Folder-based curriculum navigator allowing learners to browse lesson sequences by topic and mastery level.</td>
    </tr>
    <tr>
      <td><code>lib/pages/content_viewer_page.dart</code></td>
      <td><code>ContentViewerPage</code></td>
      <td>Universal document viewer rendering educational articles, attached PDFs, and rich text resources.</td>
    </tr>
    <tr>
      <td><code>lib/pages/browse_educators_tab.dart</code></td>
      <td><code>BrowseEducatorsTab</code></td>
      <td>Educator discovery directory. Displays certified educator cards, student reviews, ratings, subscription tiers, and direct mentorship booking buttons.</td>
    </tr>
    <tr>
      <td><code>lib/pages/educator_profile_page.dart</code></td>
      <td><code>EducatorProfilePage</code></td>
      <td>Public educator portfolio showcasing biography, credentials, subscriber counts, published content library, and student ratings.</td>
    </tr>
    <tr>
      <td><code>lib/pages/manage_subscriptions_page.dart</code></td>
      <td><code>ManageSubscriptionsPage</code></td>
      <td>Dual-purpose subscription manager: learners manage active educator tiers; educators configure Standard ($10) and Premium ($30) pricing.</td>
    </tr>
    <tr>
      <td><code>lib/pages/conference_page.dart</code></td>
      <td><code>ConferencePage</code></td>
      <td>Live Agora RTC video conference portal. Provides bi-directional audio/video streaming, camera flip, mute controls, and synchronized Firestore text chat.</td>
    </tr>
    <tr>
      <td><code>lib/pages/role_application_page.dart</code></td>
      <td><code>RoleApplicationPage</code></td>
      <td>Application submission portal for users applying to become certified Educators or Validators, including credential document attachments.</td>
    </tr>
    <tr>
      <td><code>lib/pages/ai_assessment_generator_page.dart</code></td>
      <td><code>AIAssessmentGeneratorPage</code></td>
      <td>Specialized standalone interface for educators to rapidly generate comprehensive assessments from raw prompt specifications.</td>
    </tr>
  </tbody>
</table>

<h2>4.5 Educational Notebook Workspaces (<code>lib/pages/notebook/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/pages/notebook/notebook_list_page.dart</code></td>
      <td><code>NotebookListPage</code></td>
      <td>Workspace hub displaying all educator-authored notebooks. Supports creating notebooks (<code>Notebook Title *</code>) and quick search filtering.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/notebook_detail_page.dart</code></td>
      <td><code>NotebookDetailPage</code></td>
      <td>Main notebook workspace. Houses source management drawers, synthesis triggers, output tab bars, and title rename modals.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/lesson_view.dart</code></td>
      <td><code>LessonView</code></td>
      <td>Interactive lesson output viewer. Supports inline markdown editing (<code>Lesson Title *</code>), dynamic image block insertion, and companion quiz toolbar linking.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/flashcard_study_page.dart</code></td>
      <td><code>FlashcardStudyPage</code></td>
      <td>Interactive 3D card review session. Users reveal answers and rate recall quality via 4 SM-2 buttons (Again, Hard, Good, Easy).</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/flashcard_deck_viewer.dart</code></td>
      <td><code>FlashcardDeckViewer</code></td>
      <td>Comprehensive deck browser displaying all flashcards, individual ease factors, repetition counts, and overall deck mastery percentages.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/learner_decks_page.dart</code></td>
      <td><code>LearnerDecksPage</code></td>
      <td>Learner repository of saved flashcard decks showing due review counts and daily spaced repetition progress indicators.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/study_guide_view.dart</code></td>
      <td><code>StudyGuideView</code></td>
      <td>Renders synthesized study guides featuring bulleted key takeaways, core vocabulary definitions, and practical usage rules.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/mind_map_view.dart</code></td>
      <td><code>MindMapView</code></td>
      <td>Visual concept map viewer rendering hierarchical node-link trees to illustrate grammatical taxonomy and sentence structures.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/timeline_view.dart</code></td>
      <td><code>TimelineView</code></td>
      <td>Chronological timeline viewer displaying historical language development milestones or progressive grammatical mastering sequences.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/faq_view.dart</code></td>
      <td><code>FaqView</code></td>
      <td>Accordion-style FAQ viewer answering common linguistic questions derived automatically from the ingested source materials.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/briefing_view.dart</code></td>
      <td><code>BriefingView</code></td>
      <td>Executive briefing viewer providing quick high-level pedagogical summaries of complex multi-chapter curriculum sources.</td>
    </tr>
    <tr>
      <td><code>lib/pages/notebook/publish_content_dialogs.dart</code></td>
      <td><code>PublishLessonDialog</code>, <code>PublishQuizDialog</code>, <code>PublishFlashcardsDialog</code></td>
      <td>Multi-format publishing modal wizards allowing educators to release synthesized content to the public or subscriber repository with visibility controls.</td>
    </tr>
  </tbody>
</table>

<h2>4.6 Administration & Verification Tabs (<code>lib/pages/admin/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/pages/admin_dashboard.dart</code></td>
      <td><code>AdminDashboard</code></td>
      <td>Master administration scaffold with responsive sidebar navigation, telemetry overview, and tab routing across all administrative consoles.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_users_tab.dart</code></td>
      <td><code>AdminUsersTab</code></td>
      <td>User management console. Allows searching user accounts, changing roles, suspending abusive accounts, and reviewing registration timestamps.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_lessons_tab.dart</code></td>
      <td><code>AdminLessonsTab</code></td>
      <td>Direct lesson creation and editing interface featuring markdown editor, image dropzone, prompt engineer triggers, and visibility settings.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_quizzes_tab.dart</code></td>
      <td><code>AdminQuizzesTab</code></td>
      <td>Comprehensive quiz authoring workspace. Configures title (<code>Title *</code>), duration (<code>Duration *</code>), max attempts (<code>Max Attempts *</code>), and multi-type question items.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_assessments_tab.dart</code></td>
      <td><code>AdminAssessmentsTab</code></td>
      <td>Summative assessment builder with strict attempt caps, time limits, passage questions, and automatic grading schema configurations.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_spelling_words_tab.dart</code></td>
      <td><code>AdminSpellingWordsTab</code></td>
      <td>Spelling Bee database manager. Allows adding, editing, and deleting vocabulary items with difficulty tiers (<code>Word *</code>, <code>Difficulty *</code>) and audio links.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_validation_tab.dart</code></td>
      <td><code>AdminValidationTab</code></td>
      <td>Administrative oversight tab monitoring validator actions, reviewing pending queues, and inspecting content rejection logs.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/validator_dashboard_tab.dart</code></td>
      <td><code>ValidatorDashboardTab</code></td>
      <td>Dedicated quality assurance console for Validators. Inspects educator-submitted content, reviews grammar accuracy, and issues approvals or audited denials.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/educator_dashboard_tab.dart</code></td>
      <td><code>EducatorDashboardTab</code></td>
      <td>Educator telemetry console displaying subscriber counts, total lesson views, average ratings, and mentorship schedule overviews.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/educator_groups_tab.dart</code></td>
      <td><code>EducatorGroupsTab</code></td>
      <td>Live mentorship scheduler. Allows educators to book upcoming Agora video meetings with subscribers (<code>Meeting Title *</code>, <code>Select Student *</code>).</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_notifications_tab.dart</code></td>
      <td><code>AdminNotificationsTab</code></td>
      <td>Broadcast center allowing administrators to compose and dispatch system-wide push notifications and platform updates.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_landing_settings_tab.dart</code></td>
      <td><code>AdminLandingSettingsTab</code></td>
      <td>Dynamic CMS tab allowing administrators to modify landing page hero copy, feature highlights, and student testimonials without recompiling.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/admin_lesson_database_tab.dart</code></td>
      <td><code>AdminLessonDatabaseTab</code></td>
      <td>Comprehensive database view of all lessons across all educators, enabling global search, category tagging, and batch archival.</td>
    </tr>
    <tr>
      <td><code>lib/pages/admin/lessons_list_tab.dart</code></td>
      <td><code>LessonsListTab</code></td>
      <td>Compact searchable list view of existing lessons for quick selection and embedding into curriculum modules.</td>
    </tr>
  </tbody>
</table>

<h2>4.7 Reusable UI Components & Widgets (<code>lib/widgets/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/widgets/ai_quota_badge.dart</code></td>
      <td><code>AIQuotaBadge</code></td>
      <td>Real-time badge widget displaying remaining daily AI generations with role indicators (e.g. <code>AI: 45 left</code>).</td>
    </tr>
    <tr>
      <td><code>lib/widgets/ai_quota_exceeded_dialog.dart</code></td>
      <td><code>AIQuotaExceededDialog</code></td>
      <td>Modal displayed when a user exhausts their daily quota, explaining tier boundaries and reset schedules.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/ai_quota_notification.dart</code></td>
      <td><code>AIQuotaNotification</code></td>
      <td>Banner notification alerting users when their daily generation limit is approaching exhaustion.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/content_denial_dialog.dart</code></td>
      <td><code>ContentDenialDialog</code></td>
      <td>Audited moderation modal requiring a minimum 30-character comprehensive explanation (<code>DETAILED EXPLANATION *</code>) before rejecting content.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/generation_loading_overlay.dart</code></td>
      <td><code>GenerationLoadingOverlay</code></td>
      <td>Full-screen blocking overlay with animated progress spinner and rotating pedagogical text, preventing double-clicks during AI operations.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/paymongo_qr_dialog.dart</code></td>
      <td><code>PaymongoQrDialog</code></td>
      <td>High-contrast QR Ph payment dialog rendering dynamic QR strings with banking instructions, real-time payment status polling, and a single-shot mutex (<code>_hasDispatchedSuccess</code>) preventing race conditions between timers and manual confirms.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/interactive_markdown.dart</code></td>
      <td><code>InteractiveMarkdown</code></td>
      <td>Styled markdown renderer supporting code syntax highlighting, custom blockquotes, inline audio triggers, and image tap zoom.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/lesson_image_dropzone.dart</code></td>
      <td><code>LessonImageDropzone</code></td>
      <td>Interactive image dropzone for lessons supporting drag-and-drop file upload and AI image prompt generation.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/linked_companion_toolbar.dart</code></td>
      <td><code>LinkedCompanionToolbar</code></td>
      <td>Sticky toolbar displayed inside lessons that allows learners to directly jump to companion practice quizzes and flashcard decks.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/custom_app_bar.dart</code></td>
      <td><code>CustomAppBar</code></td>
      <td>Top bar containing app logo, navigation breadcrumbs, notification badge bell, profile avatar, and theme toggle button.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/admin_sidebar.dart</code></td>
      <td><code>AdminSidebar</code></td>
      <td>Collapsible side navigation rail used across admin and educator consoles with active route highlights.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/app_search_bar.dart</code></td>
      <td><code>AppSearchBar</code></td>
      <td>Standardized debounced search input field used across catalog, user, and lesson management views.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/audio_player_widget.dart</code></td>
      <td><code>AudioPlayerWidget</code></td>
      <td>Compact inline audio player for vocabulary listening drills and pronunciation reference sounds.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/subscription_tier_dialog.dart</code></td>
      <td><code>SubscriptionTierDialog</code></td>
      <td>Comparison modal detailing Standard vs Premium subscription benefits and initiating PayMongo checkout.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/terms_and_conditions_dialog.dart</code></td>
      <td><code>TermsAndConditionsDialog</code></td>
      <td>Scrollable legal modal rendering privacy policy and terms of service with acceptance verification.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/user_visibility_selector.dart</code></td>
      <td><code>UserVisibilitySelector</code></td>
      <td>Segmented button allowing educators to toggle content visibility between Public, Subscribers Only, and Private.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/video_player_modal.dart</code></td>
      <td><code>VideoPlayerModal</code></td>
      <td>Modal media player for video lectures and demonstration clips.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/modern_bottom_nav.dart</code></td>
      <td><code>ModernBottomNav</code></td>
      <td>Floating pill bottom navigation bar for mobile devices providing fluid route transitions.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/universal_drawer.dart</code></td>
      <td><code>UniversalDrawer</code></td>
      <td>Slide-out mobile navigation drawer exposing user profile info, route links, and role switching shortcuts.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/author_name_widget.dart</code></td>
      <td><code>AuthorNameWidget</code></td>
      <td>Chip displaying author avatar, display name, and verified Educator/Validator badge.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/design_ornaments.dart</code></td>
      <td><code>DesignOrnaments</code></td>
      <td>Decorative background gradient blobs and floating shapes establishing Grammatica's visual aesthetic.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/markdown_guide_dialog.dart</code></td>
      <td><code>MarkdownGuideDialog</code></td>
      <td>Reference modal explaining markdown syntax (headings, bold, lists, tables) to educators authoring lessons.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/application_preview_widgets.dart</code></td>
      <td><code>ApplicationPreviewWidgets</code></td>
      <td>Renders submitted educator resume documents and teaching certificates inside validator review modals.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notification_widgets.dart</code></td>
      <td><code>NotificationTile</code></td>
      <td>List tile rendering individual notification items with timestamp formatting and mark-as-read toggles.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/google_sign_in_button.dart</code> (and <code>_web</code>, <code>_stub</code>)</td>
      <td><code>GoogleSignInButton</code></td>
      <td>Platform-safe branded Google authentication button triggering OAuth workflows across mobile and web.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/preview_helper.dart</code> (and <code>_web</code>, <code>_stub</code>)</td>
      <td><code>PreviewHelper</code></td>
      <td>Cross-platform helper resolving local file bytes vs web URLs for previewing images and documents.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notebook/flashcard_widget.dart</code></td>
      <td><code>FlashcardWidget</code></td>
      <td>Animated 3D flipping card widget delivering tactile physics during spaced repetition review sessions.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notebook/notebook_card.dart</code></td>
      <td><code>NotebookCard</code></td>
      <td>Dashboard tile presenting notebook summary metrics, source counts, and last modified timestamps.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notebook/source_upload_panel.dart</code></td>
      <td><code>SourceUploadPanel</code></td>
      <td>Tabbed modal panel for adding sources: PDF file upload, web URL (<code>Webpage URL *</code>), or raw note (<code>Content *</code>).</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notebook/output_toolbar.dart</code></td>
      <td><code>OutputToolbar</code></td>
      <td>Action bar attached to notebook outputs providing export, regenerate, edit, and publish buttons.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notebook/generation_confirm_dialog.dart</code></td>
      <td><code>GenerationConfirmDialog</code></td>
      <td>Confirmation modal informing educators of expected AI generation quota consumption before dispatching jobs.</td>
    </tr>
    <tr>
      <td><code>lib/widgets/notebook/notebook_selector_dialog.dart</code></td>
      <td><code>NotebookSelectorDialog</code></td>
      <td>Selection dialog allowing educators to assign generated content to existing notebooks or initialize new ones.</td>
    </tr>
  </tbody>
</table>

<h2>4.8 Utilities & Platform Helpers (<code>lib/utils/</code>)</h2>
<table class="data-table">
  <thead>
    <tr>
      <th style="width: 25%;">File Path</th>
      <th style="width: 25%;">Key Classes / Symbols</th>
      <th>Architectural Responsibility & Implementation Details</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/utils/responsive_layout.dart</code></td>
      <td><code>ResponsiveLayout</code></td>
      <td>Provides responsive breakpoint utilities (Mobile &lt; 768px, Tablet 768-1100px, Desktop &gt; 1100px) and conditional builders.</td>
    </tr>
    <tr>
      <td><code>lib/utils/image_utils.dart</code></td>
      <td><code>ImageUtils</code></td>
      <td>Image utility functions for resizing, compressing, base64 encoding/decoding, and format validation prior to cloud upload.</td>
    </tr>
    <tr>
      <td><code>lib/utils/file_helper.dart</code> (and <code>_io</code>, <code>_stub</code>)</td>
      <td><code>FileHelper</code></td>
      <td>Cross-platform abstraction for downloading, reading, and writing files to local disk storage across desktop, mobile, and web.</td>
    </tr>
  </tbody>
</table>

<!-- SECTION 5: BACKEND & AI MICROSERVICES -->
<h1>5.0 Microservices AI Backend & LLM Fine-Tuning</h1>
<p>
While the Flutter client directly connects to Firebase for primary application data, computationally intensive and secured operations are delegated to Grammatica's Python microservices layer:
</p>

<h2>5.1 FastAPI Microservice Architecture (<code>ai_backend/</code>)</h2>
<ul>
  <li><strong>REST API Gateway (<code>main.py</code>):</strong> High-performance asynchronous API built on FastAPI and Uvicorn, secured by JWT and Firebase ID Token verification middleware (<code>middleware/auth.py</code>).</li>
  <li><strong>Distributed Idempotency Engine (<code>middleware/idempotency.py</code> & <code>services/idempotency_store.py</code>):</strong> Intercepts mutating API calls, validates <code>Idempotency-Key</code> headers, enforces async locks, calculates SHA-256 payload fingerprints, returns <code>HTTP 409 Conflict</code> on in-flight collisions, rejects mutations via <code>HTTP 422</code>, and serves replay-cached responses with <code>Idempotent-Replay: true</code>.</li>
  <li><strong>Generation Routes (<code>routes/lesson.py</code>, <code>routes/quiz.py</code>, <code>routes/notebook.py</code>):</strong> Endpoints accepting ingested curricular sources and calling Google Gemini 2.5 Flash with strict JSON schema constraints.</li>
  <li><strong>Payment & Webhook Listener (<code>routes/payment.py</code>):</strong> Receives PayMongo webhook callbacks, verifies cryptographic signature headers, locks on webhook event IDs (<code>evt_...</code>) for deduplication, and updates user subscription records in Firestore.</li>
  <li><strong>Email Dispatcher (<code>routes/email.py</code>):</strong> Dispatches transactional receipts and notifications using the Brevo API.</li>
  <li><strong>Document Processing (<code>services/pdf_service.py</code>):</strong> Uses <code>pdfplumber</code> and <code>pypdf</code> to parse complex multi-page academic documents, stripping non-textual artifacts and chunking text to prevent token overflow.</li>
</ul>

<h2>5.2 LLaMA 1B LoRA Fine-Tuning Pipeline (<code>backend/</code>)</h2>
<p>
In addition to Google Gemini, Grammatica features an internal, domain-specific fine-tuning pipeline for lightweight on-premise execution:
</p>
<ul>
  <li><strong>Dataset Curation (<code>lessons_data.csv</code> & <code>csv_to_jsonl.py</code>):</strong> Curated grammar instruction dataset comprising thousands of question-answer pairs, rule explanations, and common grammatical misconception corrections formatted in JSON Lines (<code>dataset.jsonl</code>).</li>
  <li><strong>Parameter-Efficient Fine-Tuning (PEFT / LoRA):</strong> Uses Low-Rank Adaptation (LoRA) on the LLaMA 1B base model (<code>train_llama_1b.ipynb</code>), adapting attention projection matrices ($W_q, W_v$) while keeping base parameters frozen. Adapter weights and tokenizer configurations are preserved in <code>backend/model/lora/</code>.</li>
</ul>

<!-- SECTION 6: DEFENSE QUESTIONS & ANSWERS -->
<h1>6.0 Top 27 Mock Defense Questions & Comprehensive Panel Answers</h1>
<p>
This section contains anticipated questions frequently raised by academic panels, complete with authoritative technical answers.
</p>

<div class="qa-card">
  <div class="qa-tag">Architecture</div>
  <div class="qa-q"><span>Q1:</span> Why did your team select Flutter instead of separate native Android and React Web codebases?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Flutter was selected to achieve <strong>single-codebase parity</strong> across Web and Android APK without compromising on performance. Flutter compiles directly to native ARM machine code on mobile and optimized JavaScript/WebAssembly with Skia canvas rendering on Web. This unified architecture saved approximately 40% of development overhead and guaranteed that complex features—such as the SuperMemo SM-2 spaced repetition engine, interactive markdown parsing, and PayMongo payment flows—behave identically on desktop browsers and mobile handsets.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">AI & Reliability</div>
  <div class="qa-q"><span>Q2:</span> How does Grammatica mitigate AI hallucinations in generated lessons and quizzes?</div>
  <div class="qa-a">
    <strong>Answer:</strong> We implement a <strong>Grounding-First Architecture</strong>. Rather than issuing zero-shot prompts to the LLM, the educator must first ingest verified pedagogical sources (PDFs, syllabus chapters, scholarly web pages). In <code>notebook_prompts.dart</code>, the system prompt strictly instructs the model: <em>"Synthesize strictly and exclusively from the provided source context. Do not invent ungrounded facts or rules."</em> Furthermore, every generated output preserves source citation links, and public content must undergo human-in-the-loop audit by certified Validators before publication.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Cognitive Science</div>
  <div class="qa-q"><span>Q3:</span> Can you mathematically explain the SuperMemo SM-2 algorithm implemented in your flashcard system?</div>
  <div class="qa-a">
    <strong>Answer:</strong> The SM-2 algorithm models the human forgetting curve. After reviewing a card, the learner assigns a quality score $q$ from 0 to 5. The Ease Factor ($EF$) is updated as: $EF' = EF + (0.1 - (5 - q) \times (0.08 + (5 - q) \times 0.02))$, with a strict floor of $1.30$. If $q < 3$, the card is treated as failed: the repetition counter $n$ resets to 0 and the interval resets to 1 day. If $q \ge 3$, the interval progresses: $I(1) = 1\text{ day}$, $I(2) = 6\text{ days}$, and for $n \ge 2$, $I(n) = I(n-1) \times EF'$. This minimizes over-testing mastered concepts while ensuring vulnerable memories are reinforced right before decay.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Security</div>
  <div class="qa-q"><span>Q4:</span> How does your 3-Attempt Lockout system protect against brute-force attacks?</div>
  <div class="qa-a">
    <strong>Answer:</strong> <code>DeviceSessionService</code> tracks failed authentication attempts. Upon the 3rd consecutive failed login, the device session is locked for 5 minutes. The timestamp is stored with cryptographic session IDs in local storage and mirrored against Firestore login telemetry. Furthermore, we implement a 15-minute sliding window: if an attacker makes 2 failed attempts and pauses, the failure counter resets after 15 minutes of inactivity to avoid permanently penalizing legitimate users who mistyped their credentials.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Security & Privacy</div>
  <div class="qa-q"><span>Q5:</span> What happens when a user deletes their account? How do you handle data privacy and orphaned records?</div>
  <div class="qa-a">
    <strong>Answer:</strong> In compliance with GDPR and data privacy standards, account deletion executes a cascading purge in <code>DatabaseService.deleteAccount()</code>. All personal identity records, active subscriptions, private flashcard decks, and session logs are wiped. However, published lessons authored by Educators remain in the repository marked as <em>"Anonymous Educator"</em> so that enrolled learners do not suffer sudden curriculum deletion. Sensitive re-authentication is mandatory before deletion can proceed.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Governance & Moderation</div>
  <div class="qa-q"><span>Q6:</span> What is the role of a Validator, and how do you prevent arbitrary content rejection?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Validators are certified pedagogical moderators who review community submissions. To eliminate arbitrary or retaliatory rejections, <code>ContentDenialDialog</code> enforces a <strong>mandatory 30-character detailed explanation</strong> requirement. A Validator cannot reject content without documenting specific grammatical errors or policy violations. This explanation is permanently logged in Firestore and delivered to the educator, creating full transparency and an audit trail for administrators.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Video & WebRTC</div>
  <div class="qa-q"><span>Q7:</span> How does Agora RTC video conferencing work across Web and Android APK without crashes?</div>
  <div class="qa-a">
    <strong>Answer:</strong> <code>AgoraService</code> initializes the Agora RTC client with platform-specific video rendering strategies. On native Android APK, video streams bind to native hardware SurfaceViews. On Web, the client attaches to HTML5 canvas/video DOM elements. Dynamic token authentication is calculated via HMAC-SHA256 credentials to ensure rooms cannot be accessed by unauthorized callers. Concurrently, a Firestore subcollection powers an synchronized real-time text chat alongside the call.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Monetization</div>
  <div class="qa-q"><span>Q8:</span> How do you process payments and handle localized payment methods in the Philippines?</div>
  <div class="qa-a">
    <strong>Answer:</strong> We integrated the <strong>PayMongo API</strong>, the leading FinTech payment gateway in the Philippines. It natively supports GCash, Maya, GrabPay, and credit/debit cards. We implement two complementary flows: (1) PayMongo Hosted Checkout Sessions for comprehensive browser payments, and (2) Direct QR Ph code generation (<code>PaymongoQrDialog</code>), allowing users to scan national QR codes directly from any Philippine e-wallet or banking app.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Backend & Email</div>
  <div class="qa-q"><span>Q9:</span> What happens if an external email delivery API goes down during payment confirmation?</div>
  <div class="qa-a">
    <strong>Answer:</strong> <code>EmailSenderService</code> implements a <strong>Dual-Relay Resilience Architecture</strong>. The primary dispatcher uses the Brevo (Sendinblue) transactional REST API. If Brevo fails or encounters network timeout, the request gracefully falls back to our local Dart email relay script (<code>scripts/local_email_relay.dart</code>) or queues the receipt event in Firestore for asynchronous background retries, ensuring the user's payment record is never lost.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Speech Recognition</div>
  <div class="qa-q"><span>Q10:</span> Why did you incorporate the Vosk Speech Model for pronunciation quizzes instead of relying exclusively on cloud speech APIs?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Cloud speech-to-text APIs introduce high latency, require constant internet connectivity, and impose recurring per-minute API costs. By compiling the <strong>Vosk Acoustic Model</strong> into the native Android APK via C++ platform channels (<code>vosk_service_native.dart</code>), speech decoding occurs entirely on the user's mobile device with zero latency and complete privacy. On the web platform, we conditionally switch to the Web Speech Recognition API.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Rate Limiting & Cost</div>
  <div class="qa-q"><span>Q11:</span> How does the platform protect against API cost explosions from excessive AI generations?</div>
  <div class="qa-a">
    <strong>Answer:</strong> <code>AIRateLimitService</code> enforces strict daily quotas calibrated by role: Learners receive 20 requests/day, Educators receive 50 requests/day, Validators receive 100 requests/day, while Admins enjoy unlimited access. Counters are tracked in Firestore user quota documents and verified server-side. Additionally, <code>GenerationLoadingOverlay</code> blocks redundant double-clicks while AI jobs are in flight.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Database Design</div>
  <div class="qa-q"><span>Q12:</span> Why Cloud Firestore? What are its strengths and how do you handle indexing?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Cloud Firestore provides high-performance, document-oriented NoSQL persistence with native real-time synchronization (<code>StreamSubscription</code>). This real-time capability is essential for live in-call chat, instant notification badges, and real-time validation queue updates. Complex compound queries (e.g. querying lessons filtered by educator ID, visibility tier, and sorted by creation timestamp) are optimized via pre-compiled composite indexes defined in <code>firestore.indexes.json</code>.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Architecture & State</div>
  <div class="qa-q"><span>Q13:</span> What state management approach is used across the Flutter frontend?</div>
  <div class="qa-a">
    <strong>Answer:</strong> We combine the <strong>Repository/Service Pattern</strong> with Flutter's native reactive primitives (<code>StatefulWidget</code>, <code>StreamBuilder</code>, and <code>ValueNotifier</code>). State is encapsulated inside dedicated singletons (e.g., <code>AuthService</code>, <code>RoleService</code>, <code>SpacedRepetitionService</code>) that expose broadcast streams. This eliminates boilerplate while avoiding unnecessary rebuilds across distant widget trees.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Educational Pedagogy</div>
  <div class="qa-q"><span>Q14:</span> How does Grammatica support different learning modalities (Visual, Auditory, Reading, Kinesthetic)?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Grammatica embraces the VARK pedagogical framework:
    <ul>
      <li><strong>Visual:</strong> Hierarchical Mind Maps (<code>MindMapView</code>) and Chronological Timelines (<code>TimelineView</code>).</li>
      <li><strong>Auditory:</strong> Audio player drills, native Vosk pronunciation scoring, and live Agora video calls.</li>
      <li><strong>Reading/Writing:</strong> In-depth interactive markdown lessons, executive briefings, and comprehensive study guides.</li>
      <li><strong>Kinesthetic:</strong> Gamified Spelling Bee letter-typing, tactile 3D flashcard flipping, and interactive multi-choice quizzes.</li>
    </ul>
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Cross-Platform Engineering</div>
  <div class="qa-q"><span>Q15:</span> How do you handle CORS issues when running the Flutter Web application?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Web browsers strictly enforce the Same-Origin Policy (SOP). Direct client-side HTTP calls to third-party domains (such as scraping educational websites or querying raw APIs) are blocked by CORS. We solved this in <code>WebServiceWeb</code> by routing web HTTP requests through our dedicated FastAPI backend proxy (<code>ai_backend</code>), which executes the HTTP handshake server-to-server and attaches the requisite <code>Access-Control-Allow-Origin: *</code> headers before returning data to the web SPA.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">AI Engineering</div>
  <div class="qa-q"><span>Q16:</span> What prompt engineering strategies ensure that Gemini outputs valid JSON?</div>
  <div class="qa-a">
    <strong>Answer:</strong> In <code>ai_logic_service.dart</code>, we pass <code>response_mime_type: "application/json"</code> in the Gemini generation configuration. Furthermore, we define explicit Pydantic-style JSON schema specifications in the system prompt, forbidding markdown code fences (```json) inside raw API returns. The response is validated through try-catch JSON decoders with fallback sanitize regexes to eliminate trailing commas or incomplete brackets.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Testing & Quality Assurance</div>
  <div class="qa-q"><span>Q17:</span> How do you test the system? What test suites exist in the codebase?</div>
  <div class="qa-a">
    <strong>Answer:</strong> The project maintains an automated test suite comprising <strong>63+ comprehensive test cases</strong>. This includes unit tests for SM-2 interval calculations (<code>spaced_repetition_test.dart</code>), brute-force lockout window tests (<code>lockout_system_test.dart</code>), Agora token generation tests (<code>agora_service_env_test.dart</code>), model serialization tests (<code>study_guide_models_test.dart</code>), widget tests for dropzones and quota badges (<code>ai_rate_limit_visual_test.dart</code>), end-to-end distributed idempotency tests (<code>idempotency_system_test.dart</code>), and backend FastAPI replay/conflict test suites (<code>test_idempotency.py</code>). All automated tests pass cleanly in CI.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Role Separation</div>
  <div class="qa-q"><span>Q18:</span> Why is there a separate Validator role? Why not let Admins perform validation?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Separation of Concerns. Administrators handle infrastructure, server configurations, landing page settings, and financial reconciliations. Validators are domain specialists (linguists, certified English teachers) whose sole responsibility is verifying grammatical accuracy and curricular standards. Combining these roles would introduce operational bottlenecks and violate the Principle of Least Privilege.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">UI/UX & Accessibility</div>
  <div class="qa-q"><span>Q19:</span> How does Grammatica ensure accessibility and clear user feedback across complex forms?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Every required field across the application is explicitly designated with an asterisk (<code>*</code>) in its label or hint text. Inline regex validators provide instantaneous feedback (e.g., password matching, email structure, min 6 characters). High-contrast dark and light themes adhere to WCAG 2.1 color contrast standards, and responsive wrappers ensure legible layouts on screens ranging from small smartphones to 4K displays.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Scalability</div>
  <div class="qa-q"><span>Q20:</span> How does the system scale if user enrollment jumps from 100 to 100,000?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Grammatica scales horizontally at every tier:
    <ul>
      <li><strong>Client:</strong> Static assets are distributed via Firebase Hosting's global CDN edge network.</li>
      <li><strong>Database:</strong> Cloud Firestore scales automatically to handle millions of concurrent connections with automatic sharding.</li>
      <li><strong>AI Microservices:</strong> The stateless FastAPI gateway can be deployed in containerized auto-scaling clusters (e.g. Google Cloud Run or AWS ECS).</li>
      <li><strong>Video:</strong> Agora RTC offloads all media encoding and packet routing to its global Software-Defined Real-Time Network (SD-RTN).</li>
    </ul>
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Fine-Tuning vs RAG</div>
  <div class="qa-q"><span>Q21:</span> What is the difference between your Gemini pipeline and the LLaMA LoRA model in <code>backend/</code>?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Gemini 2.5 Flash operates via <strong>Retrieval-Augmented Generation (RAG)</strong>—it ingests dynamic, user-provided source documents at inference time to generate multi-format pedagogical artifacts. The fine-tuned LLaMA 1B LoRA model represents a specialized research prototype trained on specific grammatical error correction datasets, demonstrating how Grammatica can execute on-premise, privacy-sensitive grammar classification without third-party API dependencies.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Offline Capabilities</div>
  <div class="qa-q"><span>Q22:</span> What features of Grammatica function when the user loses internet access?</div>
  <div class="qa-a">
    <strong>Answer:</strong> (1) The native Android APK executes speech pronunciation scoring offline using the embedded Vosk acoustic model. (2) Firestore enables offline persistence, caching downloaded lessons and flashcard decks so learners can continue review sessions in offline environments. Mutations (such as SM-2 card quality updates) queue locally and synchronize upon network reconnection.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Future Work</div>
  <div class="qa-q"><span>Q23:</span> What are the current limitations of Grammatica, and how will future iterations address them?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Current limitations include reliance on third-party cloud LLM availability and manual appointment booking for mentorship. Future roadmaps incorporate: (1) Automated schedule conflict detection via Google Calendar integration, (2) Real-time conversational AI voice agents for 24/7 conversational immersion practice, and (3) Collaborative multi-student study rooms within the Agora video portal.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Data Structure</div>
  <div class="qa-q"><span>Q24:</span> How are complex mind maps and timelines represented in Firestore?</div>
  <div class="qa-a">
    <strong>Answer:</strong> In <code>study_guide_models.dart</code>, mind maps are structured as recursive adjacency lists: each <code>MindMapNode</code> contains an identifier, label, optional explanation, and a list of nested child nodes. Timelines are represented as serialized arrays of <code>TimelineEvent</code> objects containing dates, titles, and descriptions, sorted chronologically prior to UI rendering.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Academic Significance</div>
  <div class="qa-q"><span>Q25:</span> What is the primary academic contribution of this capstone project?</div>
  <div class="qa-a">
    <strong>Answer:</strong> The primary academic contribution is the <strong>synthesis of generative AI document grounding with cognitive spaced retrieval and live synchronous mentorship</strong>. While existing platforms either provide static drills or unguided AI chatbots, Grammatica proves that grounding LLMs in verified curricular sources and coupling them with empirical memory algorithms (SM-2) and human educator verification delivers a significantly more reliable, accountable, and effective digital language learning ecosystem.
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Financial Architecture & Idempotency</div>
  <div class="qa-q"><span>Q26:</span> How does Grammatica prevent double billing and duplicate payment records if a learner taps the checkout button multiple times or suffers network drops during payment?</div>
  <div class="qa-a">
    <strong>Answer:</strong> We enforce an end-to-end <strong>3-Tier Distributed Idempotency Pipeline</strong>:
    <ul>
      <li><strong>Client Tier:</strong> <code>IdempotencyService</code> employs <em>single-flight coalescing</em> (<code>executeDeduplicated</code>). If a user taps "Pay" multiple times rapidly, subsequent taps await the existing in-flight Future rather than firing duplicate HTTP requests. It also computes deterministic keys scoped to 1-minute windows (e.g. <code>pay_link_{studentId}_{educatorId}_{timestampMinutes}</code>).</li>
      <li><strong>API Gateway Tier:</strong> <code>IdempotencyMiddleware</code> forwards the key to PayMongo and checks our FastAPI <code>IdempotencyStore</code>. If a concurrent duplicate arrives, the server locks on the key and immediately returns <code>HTTP 409 Conflict</code> (with <code>Retry-After: 2</code>). When completed, repeated calls replay the cached JSON with an <code>Idempotent-Replay: true</code> header.</li>
      <li><strong>Database Ledger Tier:</strong> In Firestore, payments use deterministic document IDs: <code>/payments/pay_{linkId}</code> and register in <code>/idempotency_keys/{key}</code>. In <code>DatabaseService.recordPayment()</code>, a check-and-set transaction inspects if the record is already <code>paid</code>. If so, it returns <code>PaymentRecordResult(isDuplicate: true)</code>, bypassing duplicate subscription extensions, notification broadcasts, and duplicate Brevo email receipts.</li>
    </ul>
  </div>
</div>

<div class="qa-card">
  <div class="qa-tag">Distributed Systems</div>
  <div class="qa-q"><span>Q27:</span> How do you handle PayMongo webhook at-least-once delivery and race conditions with client-side polling?</div>
  <div class="qa-a">
    <strong>Answer:</strong> Payment gateways guarantee <em>at-least-once</em> webhook delivery, meaning webhooks may arrive multiple times, often concurrently with the client's foreground QR polling loop (<code>PaymongoQrDialog</code>). We resolve this race condition through two synchronized guards:
    <ol>
      <li><strong>Webhook Mutex:</strong> In <code>routes/payment.py</code>, the FastAPI webhook listener locks on the PayMongo event identifier (<code>evt_...</code>) via <code>IdempotencyStore</code>, rejecting duplicate webhook retries.</li>
      <li><strong>UI Single-Shot Lock & Transactional Check-and-Set:</strong> <code>PaymongoQrDialog</code> maintains a private boolean lock <code>_hasDispatchedSuccess</code>. Whichever path finishes first—the webhook or client poll—commits the record to Firestore. The secondary caller checks the deterministic record ID, recognizes the <code>status == 'paid'</code> state, flags <code>isDuplicate: true</code>, and gracefully exits without side effects.</li>
    </ol>
  </div>
</div>

<div style="margin-top: 40px; text-align: center; border-top: 1px solid #cbd5e1; padding-top: 20px; font-size: 8.5pt; color: #64748b;">
  <strong>Grammatica Capstone Defense Reviewer</strong> • Compiled for Academic Evaluation • All Rights Reserved © 2026
</div>

</body>
</html>
"""
    return html_content

def main():
    print("Writing HTML review document...")
    html_content = build_html()
    html_path = os.path.abspath("Grammatica_System_Reviewer_Mock_Defense.html")
    pdf_path = os.path.abspath("Grammatica_System_Reviewer_Mock_Defense.pdf")
    
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    
    print(f"HTML written to {html_path} ({len(html_content)} chars)")
    print("Invoking Microsoft Edge headless to render PDF...")
    
    edge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if not os.path.exists(edge_path):
        edge_path = r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    
    if not os.path.exists(edge_path):
        print("Error: Microsoft Edge binary not found.")
        sys.exit(1)
        
    cmd = [
        edge_path,
        "--headless",
        "--disable-gpu",
        "--run-all-compositor-stages-before-draw",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path
    ]
    
    res = subprocess.run(cmd, capture_output=True, text=True)
    if os.path.exists(pdf_path):
        size_kb = os.path.getsize(pdf_path) / 1024
        print(f"SUCCESS: PDF created successfully at {pdf_path} ({size_kb:.1f} KB)")
    else:
        print(f"Error generating PDF. Edge output: {res.stdout}\n{res.stderr}")
        sys.exit(1)

if __name__ == "__main__":
    main()
