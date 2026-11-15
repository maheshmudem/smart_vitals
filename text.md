this is  a new Empty project , now initillay we need to maek the UI for the applucatuion with all requirement , for thet we have a Docunt about the application and that  readings amd Etc,,, 

now you act most expereance Flutter FullStack Developer, UI UX Designer , Project MAnager, and ML and AI Algoritham Enginner ,# ROLE & RESPONSIBILITY

Act as a Senior Flutter Full-Stack Architect, Lead UI/UX Designer, Project Manager, Backend Integration Engineer, and AI/ML Algorithm Engineer with extensive experience in building production-ready healthcare and wellness applications.

You are responsible for understanding the complete application requirements, designing its architecture, planning the user experience, documenting every feature, and implementing the application using professional Flutter development standards.

# PROJECT BACKGROUND

We have an entirely new, empty Flutter project.

We also have a reference document containing the application's requirements, functionality, medical/wellness information, readings, measurements, algorithms, workflows, and other important details.

This document is the primary source of truth for understanding the application.

Your first responsibility is to thoroughly read, analyze, and understand the entire document before making any implementation decisions.

Do not make assumptions about application functionality. If something is unclear, identify it and document it instead of inventing requirements.

# PHASE 1: COMPLETE DOCUMENT ANALYSIS

Read the entire reference document carefully.

Extract and organize:

1. Application purpose and objectives.
2. Target users and user roles.
3. Core application modules.
4. Every feature and its purpose.
5. Medical, health, and wellness-related readings.
6. Measurement units, ranges, calculations, and interpretations.
7. AI/ML algorithms and their expected responsibilities.
8. Input requirements and output information.
9. User workflows and feature dependencies.
10. API, backend, hardware, and third-party integration requirements.
11. Notifications, permissions, and device requirements.
12. Error scenarios, validation rules, and exceptional cases.

For every feature, explain:
- What is the feature?
- Why does the application need it?
- Who will use it?
- What information does it require?
- How does it work?
- What information does it produce?
- Which other features depend on it?

# PHASE 2: COMPLETE APPLICATION DOCUMENTATION

Create a centralized project documentation directory.

Suggested structure:

docs/
  01_Project_Overview.md
  02_Application_Requirements.md
  03_User_Roles_and_Permissions.md
  04_Feature_Analysis.md
  05_UI_UX_Screen_Documentation.md
  06_User_Flows_and_Navigation.md
  07_Feature_Lifecycle_and_States.md
  08_Health_Readings_and_Metrics.md
  09_AI_ML_Algorithm_Documentation.md
  10_API_and_Backend_Integration.md
  11_Data_Models_and_Entities.md
  12_Error_Handling_and_Validation.md
  13_Flutter_Architecture.md
  14_Development_Roadmap.md
  15_Testing_Strategy.md
  16_Open_Questions_and_Assumptions.md

Each document must contain meaningful, detailed, implementation-oriented information.

The documentation should serve as a permanent technical reference for future development, maintenance, debugging, and onboarding.

# PHASE 3: SCREEN-BY-SCREEN UI/UX PLANNING

Identify every screen required by the application based on the reference document.

For EACH screen, document:

1. Screen name and purpose.
2. User role and access permissions.
3. Entry point and navigation path.
4. Complete UI layout and hierarchy.
5. Header, navigation, cards, sections, buttons, and input fields.
6. Information displayed on the screen.
7. Data required from APIs, local storage, sensors, or algorithms.
8. User interactions and expected actions.
9. Loading, empty, success, and error states.
10. Validation and permission requirements.
11. Navigation destinations.
12. Dependencies on other features.
13. Screen lifecycle and state-management requirements.

Also document all possible navigation flows and relationships between screens.

IMPORTANT UI/UX REQUIREMENTS:

- Design a modern, premium, professional healthcare application.
- Avoid outdated or generic UI designs.
- Maintain consistent spacing, typography, colors, icons, and components.
- Follow responsive design principles.
- Ensure accessibility and readability.
- Use reusable widgets and design-system components.
- Provide meaningful loading indicators, empty states, error messages, and success feedback.
- Avoid overcrowded layouts.
- Maintain consistency across the entire application.

Do not design screens independently without considering the complete application experience.

# PHASE 4: FEATURE GATES AND LIFECYCLE DOCUMENTATION

For every feature, document its complete lifecycle.

Consider the following states wherever applicable:

- Not Started
- Initializing
- Permission Required
- Permission Granted
- Permission Denied
- Ready
- Loading
- Processing
- Success
- Failed
- Retry
- Completed
- Disabled
- Expired

Not every feature requires every state. Define only the relevant states for each feature.

Document:
- Feature prerequisites.
- Entry conditions.
- Exit conditions.
- Required permissions.
- Data dependencies.
- State transitions.
- Failure scenarios.
- Retry mechanisms.
- Navigation behavior.
- Feature availability conditions.

Also identify feature gates such as authentication, subscription, device connectivity, permissions, assessments, and prerequisite completion wherever required by the reference document.

# PHASE 5: FLUTTER APPLICATION ARCHITECTURE

Before implementation, define a scalable Flutter architecture.

Requirements:

- Feature-first project structure.
- Clean Architecture principles where appropriate.
- Clear separation of presentation, business logic, and data layers.
- Reusable UI components.
- Centralized theme and design system.
- Consistent navigation and routing.
- Proper state management.
- Centralized API client and error handling.
- Environment-based configuration.
- Secure storage for sensitive information.
- Proper logging and debugging.
- Testable and maintainable code.

The architecture must support future feature additions without requiring major structural changes.

Avoid unnecessary complexity and overengineering.

# PHASE 6: AI/ML AND ALGORITHM INTEGRATION

Carefully analyze every AI/ML-related requirement in the reference document.

For each algorithm, document:

1. Algorithm name and purpose.
2. Input data.
3. Output data.
4. Required preprocessing.
5. Calculation or inference workflow.
6. Dependencies and integrations.
7. Processing location (on-device or backend).
8. Accuracy and validation requirements.
9. Failure and fallback scenarios.
10. How results should be displayed in the UI.

Never invent medical calculations, diagnostic rules, thresholds, or algorithm outputs.

Clearly distinguish between:
- Documented algorithms.
- Standard technical implementations.
- Requirements that need clarification.

Medical and wellness results must not be presented as confirmed diagnoses unless explicitly supported by the approved clinical requirements.

# PHASE 7: IMPLEMENTATION

Only after completing the requirement analysis, screen planning, and architecture documentation should you begin implementation.

Implementation rules:

1. Inspect the existing Flutter project before modifying it.
2. Preserve existing project configuration unless changes are necessary.
3. Establish the application theme and reusable design system first.
4. Implement navigation and the foundational application structure.
5. Implement screens feature by feature.
6. Use reusable widgets instead of duplicating UI code.
7. Keep business logic separate from UI.
8. Use mock data only when backend/API details are unavailable.
9. Clearly identify mock implementations so they can be replaced later.
10. Implement all documented loading, success, empty, and error states.
11. Write meaningful comments only where necessary.
12. Ensure code is readable, maintainable, and production-oriented.

Do not put the entire application inside a single file.

Do not create placeholder functionality and present it as a completed feature.

Do not silently skip requirements.

# PHASE 8: TESTING AND QUALITY ASSURANCE

For every implemented feature, verify:

- UI consistency.
- Navigation behavior.
- Input validation.
- State transitions.
- Loading and error handling.
- API integration.
- Data handling.
- Responsive behavior.
- Permission handling.
- Edge cases.

Create unit tests, widget tests, and integration tests wherever appropriate.

Run Flutter analysis and resolve relevant errors and warnings.

# PHASE 9: PROJECT PROGRESS TRACKING

Maintain a DEVELOPMENT_PROGRESS.md file.

Track every feature using these statuses:

- [ ] Not Started
- [ ] Requirements Analyzed
- [ ] Documentation Completed
- [ ] UI/UX Designed
- [ ] Implementation In Progress
- [ ] Implemented
- [ ] Testing Completed
- [ ] Completed

Update this file whenever meaningful progress is made.

Also maintain a list of:
- Completed work.
- Pending work.
- Known issues.
- Blockers.
- Decisions made.
- Questions requiring clarification.

# EXECUTION RULES

1. First analyze the complete reference document.
2. Do not immediately start coding.
3. Do not skip documentation.
4. Do not assume missing requirements.
5. Keep all documentation synchronized with the implementation.
6. Follow the same architecture and design standards across all features.
7. Make implementation decisions based on scalability and maintainability.
8. Prioritize functionality, usability, performance, and reliability.
9. Work incrementally and verify each implementation phase.
10. Before making major architectural changes, explain the reason and impact.

# EXPECTED FINAL RESULT

The final outcome must include:

1. A complete understanding of the application.
2. Detailed project documentation.
3. A complete screen inventory.
4. Screen-by-screen UI/UX specifications.
5. Navigation and user-flow documentation.
6. Feature gates and lifecycle documentation.
7. Health metrics and algorithm documentation.
8. Flutter architecture and project structure.
9. A fully implemented Flutter UI.
10. Proper integration-ready business logic.
11. Testing documentation and implementation.
12. A continuously updated development progress tracker.

The goal is not simply to create a collection of Flutter screens.

The goal is to build a well-architected, professionally designed, scalable application in which every screen, feature, workflow, algorithm, and user interaction is clearly understood, documented, and implemented.

Start by inspecting the project and reading the complete reference document. Then prepare the analysis and documentation before proceeding with implementation.

and now read this document now amek a details  file what ahave purpose and for that Etch UI Screen with all GAtes and Life cycle for that Features and UI , its healp full to read any time and any whare if had any doubts OK 



and this is the Documnt file floder [Docs](directory;file:///d:/algoritam/Docs) 