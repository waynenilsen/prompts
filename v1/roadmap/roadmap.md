# Roadmap

Strategic, milestone-based product planning that guides PRD creation.

---

## Philosophy

> "A roadmap is a strategic plan that defines a goal or desired outcome and includes the major steps or milestones needed to reach it."
> — Product Management Best Practices

A roadmap sits at a higher level of abstraction than PRDs. It defines **what features** are needed in each phase, but leaves the detailed problem/solution/user stories to PRDs.

### Why Roadmaps

- **Strategic steering** — Provides high-level direction for autonomous development
- **Feature sequencing** — Defines what to build and in what order
- **Milestone tracking** — Clear phases with success criteria
- **Context prevention** — Only loaded when needed (before PRD creation), not during implementation

### The Relationship

**1 roadmap phase → N PRDs → N ERDs → M tickets (where M > N)**

- Roadmap defines: "We need user authentication"
- PRD defines: Problem, user stories, solution approach for authentication
- ERD defines: Technical implementation details for authentication
- Tickets define: Multiple specific tasks to implement authentication (schema, API routes, UI components, tests, etc.)

**Note:** Each PRD has exactly one ERD (1:1 relationship). Each ERD breaks down into multiple tickets (1:many relationship), so there are more tickets than PRDs/ERDs.

---

## Context Management

**CRITICAL:** Roadmaps are only read when:
- The backlog is empty
- PRDs need to be created
- Strategic steering is required

**Roadmaps MUST NOT be read:**
- During ticket implementation
- When working on existing PRDs/ERDs
- During code review or cleanup

This prevents context rot by keeping strategic documents separate from tactical implementation.

---

## File Organization

Roadmaps are stored in the `./roadmap/` directory with sequential 4-digit identifiers followed by a kebab-case description:

```
roadmap/
├── 0001-foundation-phase.md
├── 0002-core-features-phase.md
├── 0003-advanced-features-phase.md
├── 0004-scale-phase.md
└── ...
```

**Naming rules:**
- 4-digit zero-padded prefix (`0001`, not `1`)
- Followed by hyphen and kebab-case description
- Sequential numbers, never reused
- Reference in commits, PRs, and PRDs as `ROADMAP-0001`

**Note:** Unlike PRDs/ERDs, roadmaps are typically created once per project or major milestone, not per feature. A single roadmap document may contain multiple phases.

---

## Core Principles

### 1. Strategic, Not Tactical

Roadmaps define **what features** are needed, not **how to build them**.

**Roadmap says:** "User authentication"
**PRD says:** Problem statement, user stories, solution approach
**ERD says:** Technical architecture, database schema, API design

### 2. Milestone-Based Phases

Organize by strategic milestones, not time-based sprints:

- **Phase 1: Foundation** — Core features needed for MVP
- **Phase 2: Core Features** — Essential functionality for product viability
- **Phase 3: Advanced Features** — Enhancements and power user features
- **Phase 4: Scale** — Performance, reliability, growth features

### 3. Feature-Level Granularity

List features at a high level. Each feature becomes a PRD:

**Roadmap Phase 1:**
- User authentication
- User profiles
- Basic content management

**Not:**
- Login form with email/password
- Password reset flow
- Session management
- (These details belong in PRDs)

### 4. Success Criteria Per Phase

Each phase should have clear success criteria:

- **Phase 1 Complete:** Users can sign up, log in, and manage their own content
- **Phase 2 Complete:** Users can collaborate and share content

### 5. Living Document

Roadmaps evolve as the product matures. Update phases as priorities change or new requirements emerge.

---

## The Template

### Metadata

```
Roadmap: [4-digit ID]
Title: [Roadmap Name]
Author: [PM/Product Owner Name]
Status: [Draft | Active | Complete]
Current Phase: [Phase Name or Number]
Last Updated: [Date]
```

### Overview

**One paragraph** describing the strategic goal of this roadmap and the product vision it supports.

### Phases

Each phase should include:

#### Phase [Number]: [Phase Name]

**Goal:** [Strategic goal of this phase]

**Features:**
- [Feature 1] - [Brief description]
- [Feature 2] - [Brief description]
- [Feature 3] - [Brief description]

**PRDs:**
- [PRD-0001: Feature 1](../product/0001-feature-1.md) - [Status]
- [PRD-0002: Feature 2](../product/0002-feature-2.md) - [Status]
- [PRD-0003: Feature 3](../product/0003-feature-3.md) - [Status]

**Success Criteria:**
- [Measurable outcome 1]
- [Measurable outcome 2]

**Status:** [Not Started | In Progress | Complete]

**Example:**

```markdown
#### Phase 1: Foundation

**Goal:** Create an MVP that allows users to sign up and manage their own content.

**Features:**
- User authentication - Email/password signup and login
- User profiles - Basic profile management and settings
- Basic content management - Create, read, update, delete user's own content

**PRDs:**
- [PRD-0001: User Authentication](../product/0001-user-authentication.md) - Complete
- [PRD-0002: User Profiles](../product/0002-user-profiles.md) - In Progress
- [PRD-0003: Basic Content Management](../product/0003-basic-content-management.md) - Not Started

**Success Criteria:**
- Users can sign up with email/password
- Users can log in and maintain sessions
- Users can create and manage their own content
- All core features have 95% test coverage

**Status:** In Progress
```

### Current Phase Status

**Which phase is currently active?**

List the active phase and its progress:

- Total features in phase: [N]
- PRDs created: [N]
- PRDs complete: [N]
- Phase completion: [X%]

### Next Steps

**What should be built next?**

Based on the current phase status, list the next feature(s) that need PRDs:

1. [Feature Name] - [Why this is next]
2. [Feature Name] - [Why this is next]

---

## Usage in Autonomous Development

When the backlog is empty and PRDs need to be created:

1. **Read the roadmap** (only the roadmap, not PRDs/ERDs)
2. **Identify current phase** from metadata
3. **Check phase status** - which features have PRDs?
4. **Select next feature** that needs a PRD
5. **Create PRD** for that feature (following [PRD template](../product/prd.md))
6. **Update roadmap** - add PRD link to phase's PRD list
7. **Create ERD** from PRD (following [ERD template](../dev/erd.md))
8. **Create tickets** from ERD (following [create-tickets-from-erd](../dev/create-tickets-from-erd.md))

**Do NOT:**
- Read roadmap during ticket implementation
- Load roadmap into context when working on code
- Reference roadmap in commit messages (reference PRD/ERD instead)

---

## Anti-Patterns

### Too Much Detail

**Wrong:** Roadmap lists implementation details:
- "Use bcrypt for password hashing"
- "Store sessions in SQLite"
- "Use tRPC for API calls"

**Right:** Roadmap lists features:
- "User authentication"
- "Session management"

### Time-Based Phases

**Wrong:** "Q1 2024: Authentication, Q2 2024: Profiles"

**Right:** "Phase 1: Foundation (Authentication, Profiles)"

Time estimates belong in project management tools, not strategic roadmaps.

### Skipping Phases

**Wrong:** Creating PRDs without roadmap context

**Right:** Always check roadmap before creating PRDs to ensure alignment with strategic goals

### Loading During Implementation

**Wrong:** Reading roadmap when implementing tickets

**Right:** Only read roadmap when backlog is empty and PRDs need creation

---

## Checklist

Before marking a roadmap as complete:

- [ ] All phases have clear goals
- [ ] Features are listed at appropriate abstraction level (not implementation details)
- [ ] Each phase has success criteria
- [ ] PRD links are maintained and up to date
- [ ] Current phase status is accurate
- [ ] Next steps are clear

---

## Related

- [Product Requirements Document](../product/prd.md) - Feature-level requirements (produced by roadmap phases)
- [Engineering Requirements Document](../dev/erd.md) - Technical implementation (produced by PRDs)
- [Create Tickets from ERD](../dev/create-tickets-from-erd.md) - Break down ERDs into actionable tickets

---

## Sources

This guide synthesizes best practices from:

- [Marty Cagan, Silicon Valley Product Group](https://www.svpg.com/revisiting-the-product-spec/) — Strategic vs tactical planning
- [Lenny Rachitsky](https://www.lennysnewsletter.com/) — Product roadmap best practices
- [Roman Pichler](https://www.romanpichler.com/blog/) — Product roadmap frameworks
- [ProductPlan](https://www.productplan.com/glossary/product-roadmap/) — Roadmap definition and structure
