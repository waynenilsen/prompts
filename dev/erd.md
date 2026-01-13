# Engineering Requirements Document (ERD)

The technical counterpart to the PRD. How we'll build what product defined.

---

## Philosophy

> "As software engineers, the job is not to produce code per se, but rather to solve problems."
> — Design Docs at Google

The ERD translates product requirements into technical decisions. It documents the *how* — architecture, trade-offs, risks, and implementation strategy — before code is written.

### Why Write ERDs

- **Alignment** — Engineering, product, and stakeholders agree on approach before building
- **Trade-off documentation** — Record why decisions were made, not just what was decided
- **Risk identification** — Surface problems early when they're cheap to fix
- **Onboarding** — New engineers understand the system without archaeology
- **Review** — Senior engineers can catch issues before they're in production

> "Unstructured text, like in the form of a design doc, may be the better tool for solving problems early in a project lifecycle, as it may be more concise and easier to comprehend."
> — Google Engineering

---

## File Organization

ERDs are stored in the `./erd/` directory with sequential 4-digit identifiers:

```
erd/
├── 0001.md    # First ERD
├── 0002.md    # Second ERD
├── 0003.md    # Third ERD
└── ...
```

**Naming rules:**
- Always 4 digits, zero-padded (`0001`, not `1`)
- Sequential, never reused
- The filename is the canonical identifier
- Reference in commits and PRs as `ERD-0001`

Each ERD should link to its corresponding PRD when applicable.

---

## Core Principles

### 1. Requirements Must Be Testable

> "The most important characteristic of an engineering requirement is that it must be testable. If a requirement cannot objectively be determined to be satisfied or not, it is not properly written."

**Wrong:** "The system should be fast"
**Right:** "API responses must return within 200ms at p95"

### 2. Use Precise Language

Use "shall" for mandatory requirements, "should" for recommendations, "may" for optional.

| Word | Meaning |
|------|---------|
| shall | Mandatory, must be implemented |
| should | Recommended, implement unless good reason not to |
| may | Optional, implement if beneficial |

### 3. Write Iteratively

> "The lead engineer writes the first draft, with strong input from product and security. Developers add details for their parts."

Don't write in isolation. Share early, get feedback, refine.

### 4. Document Trade-offs

Every significant decision has alternatives. Document:
- What options were considered
- Why you chose this one
- What you're giving up

### 5. Living Document

> "The TDD is a living document. Update it as decisions are made and designs evolve to maintain accuracy."

The ERD evolves with the project. Update it when reality diverges from plan.

---

## The Template

### Metadata

```
ERD: [4-digit ID]
Title: [Feature Name]
Author: [Engineer Name]
Status: [Draft | In Review | Approved | In Progress | Complete]
PRD: [Link to corresponding PRD, if any]
Last Updated: [Date]
Reviewers: [List of reviewers]
```

### Overview

**One paragraph** summarizing what this document covers and why.

### Background

What context does the reader need? Link to:
- Related PRD
- Existing systems this touches
- Previous decisions that constrain this one

### Goals and Non-Goals

**Goals:** What technical outcomes are we trying to achieve?

**Non-Goals:** What are we explicitly not solving? What's out of scope?

### Architecture

**System Design**

High-level architecture. Diagrams are encouraged.

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ Client  │────▶│   API   │────▶│   DB    │
└─────────┘     └─────────┘     └─────────┘
```

**Components**

List each component and its responsibility.

**Data Flow**

How does data move through the system?

### Technical Requirements

Use requirement IDs for traceability.

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-001 | API shall respond within 200ms at p95 | Must |
| REQ-002 | System shall handle 1000 concurrent users | Must |
| REQ-003 | Data should be encrypted at rest | Should |

### API Design

If introducing or modifying APIs:

```typescript
// Endpoint: POST /api/users
interface CreateUserRequest {
  email: string;
  name: string;
}

interface CreateUserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: string;
}
```

### Data Model

Schema changes, new tables, migrations.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Alternatives Considered

What other approaches did you evaluate?

| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Option A | Fast | Complex | Too much operational burden |
| Option B | Simple | Slow | Doesn't meet latency requirements |

### Security Considerations

- Authentication/authorization changes
- Data sensitivity
- Input validation
- Threat model

### Testing Strategy

How will you verify this works?

- Unit tests
- Integration tests
- Load tests
- Manual QA

### Rollout Plan

How will you deploy this safely?

- Feature flags
- Staged rollout
- Rollback plan
- Monitoring

### Open Questions

What's unresolved? What needs input?

### Dependencies

- External services
- Other teams
- Timeline blockers

---

## RFC Style Alternative

For larger architectural decisions, consider the RFC (Request for Comments) format used at companies like Uber, Stripe, and Airbnb.

> "RFCs prevent scope creep, reduce last-minute pivots, and ensure dependencies are accounted for."

Key additions for RFC style:
- **Discussion period** — Time for async feedback before approval
- **Decision record** — Final decision and rationale
- **Stakeholder sign-off** — Explicit approval from affected parties

---

## Anti-Patterns

### Writing After Implementation

The ERD documents decisions *before* they're made. Writing it after is just documentation.

### No Trade-off Analysis

If you only present one option, you haven't done design work. Show alternatives.

### Vague Requirements

"Fast," "scalable," "secure" mean nothing without numbers.

### Hiding Complexity

Don't gloss over the hard parts. That's where bugs live.

### Stale Documents

An ERD that doesn't match the implementation is worse than no ERD.

---

## Checklist

Before requesting review:

- [ ] Links to corresponding PRD (if applicable)
- [ ] Goals and non-goals are explicit
- [ ] Architecture diagram exists
- [ ] Requirements are testable and numbered
- [ ] Alternatives were considered and documented
- [ ] Security implications addressed
- [ ] Testing strategy defined
- [ ] Rollout plan exists
- [ ] Open questions are surfaced

---

## Sources

This guide synthesizes best practices from:

- [Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/) — Google's design doc culture and structure
- [Stack Overflow](https://stackoverflow.blog/2020/04/06/a-practical-guide-to-writing-technical-specs/) — Practical guide to writing technical specs
- [Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/software-engineering-rfc-and-design) — RFC and design doc examples from top companies
- [Stripe Engineering](https://newsletter.pragmaticengineer.com/p/stripe-part-2) — Writing culture and artifact creation
- [Uber Engineering](https://eng.uber.com/learning-on-the-go-engineering-efficiency-with-concise-documentation/) — Concise documentation practices
- [Fictiv](https://www.fictiv.com/articles/how-to-write-an-engineering-requirements-document) — Engineering requirements document structure
- [Phil Calçado](https://philcalcado.com/2018/11/19/a_structured_rfc_process.html) — Structured RFC process
