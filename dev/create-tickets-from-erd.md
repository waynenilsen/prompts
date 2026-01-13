# Creating Tickets from an ERD

Breaking down an Engineering Requirements Document into actionable tickets, ordered for dependency-aware burndown.

---

## Philosophy

> "I never start with building the 'best' or 'most complete' implementation of a story. I start with the smallest possible thing that does essential work and then get feedback."
> — Allen Holub

The ERD describes the epic. Tickets are the atomic units of work that compose it. The goal is to create a backlog you can burn down in precise order, where each ticket builds on the last.

### Why Order Matters

> "The ROI of an individual item depends on its position in the backlog."
> — Scrum.org

Dependencies determine order, not arbitrary priority. A high-priority ticket blocked by an incomplete dependency is worthless. Order the backlog so you never start something you can't finish.

---

## Prerequisites

### GitHub CLI Setup

Ensure you have the `gh` CLI installed and authenticated with project scope:

```bash
# Check auth status
gh auth status

# Add project scope if needed
gh auth refresh -s project
```

### Identify or Create the Project

Check if a GitHub Project exists for this repo:

```bash
# List projects for the repo owner
gh project list --owner <owner>
```

If no project exists, create one:

```bash
# Create a new project in board (kanban) layout
gh project create --owner <owner> --title "<Project Name>"
```

After creation, configure the board view in the GitHub UI:
1. Open the project
2. Click the view dropdown → New view → Board
3. Set columns to use the Status field (Backlog, In Progress, Done)

---

## The Process

### Step 1: Read the ERD

Open the ERD (e.g., `./erd/0001.md`) and identify:

- **Components** — Each distinct system component
- **Requirements** — Each REQ-XXX item
- **API endpoints** — Each route or method
- **Data models** — Each table or schema change
- **Dependencies** — What depends on what

### Step 2: Build the Dependency Graph

Before creating tickets, map what depends on what.

```
Database Schema
    ↓
API Types/Interfaces
    ↓
API Endpoints
    ↓
Business Logic
    ↓
UI Components
    ↓
Integration Tests
```

**Rule:** A ticket can only be worked on when all its dependencies are complete.

### Step 3: Slice Vertically

> "A vertical slice is a work item that delivers a valuable change in system behavior such that you'll probably have to touch multiple architectural layers."
> — Humanizing Work

**Wrong (horizontal slices):**
- Ticket 1: Create database tables
- Ticket 2: Create API endpoints
- Ticket 3: Create UI

**Right (vertical slices):**
- Ticket 1: User can create account (DB + API + minimal UI)
- Ticket 2: User can view profile (DB + API + UI)
- Ticket 3: User can edit profile (API + UI)

Each ticket delivers working, testable functionality.

### Step 4: Apply INVEST Criteria

Each ticket should be:

| Criterion | Meaning |
|-----------|---------|
| **I**ndependent | Can be completed without waiting (after deps are done) |
| **N**egotiable | Details can be discussed during implementation |
| **V**aluable | Delivers user or system value |
| **E**stimable | Small enough to estimate confidently |
| **S**mall | Completable in 1-3 days |
| **T**estable | Has clear acceptance criteria |

> "Engineering Tasks have to be estimated as no more than 5, and preferably less than 3 ideal engineering days."
> — Kent Beck

### Step 5: Order by Dependencies

Use topological sort logic:

1. **Foundation first** — Schema, types, shared utilities
2. **Core functionality** — Primary user flows
3. **Secondary features** — Enhancements, edge cases
4. **Polish** — Error handling, performance, observability

Within each tier, order by:
- Technical dependencies (what must exist first)
- Risk (high-risk items early for faster feedback)
- Value (higher value when dependencies are equal)

### Step 6: Create Tickets with gh CLI

Create each ticket in dependency order:

```bash
# Create an issue and add to project
gh issue create \
  --title "feat(users): add user table schema" \
  --body "$(cat <<'EOF'
## Context
ERD: ERD-0001
Depends on: None (foundation)

## Requirements
- REQ-001: Users table with id, email, name, created_at
- REQ-002: Unique constraint on email

## Acceptance Criteria
- [ ] Migration creates users table
- [ ] Migration is reversible
- [ ] Schema matches ERD specification

## Technical Notes
See ERD-0001 Data Model section.
EOF
)" \
  --project "<Project Name>"
```

**Ticket title format:** `<type>(<scope>): <description>`

Types match conventional commits: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

### Step 7: Set Ticket Order in Project

After creating all tickets, ensure they're ordered correctly in the Backlog column:

```bash
# List project items to verify order
gh project item-list <PROJECT_NUMBER> --owner <owner>
```

Reorder in the GitHub UI by dragging tickets in the Backlog column. The top ticket is next to be worked.

---

## Ticket Template

```markdown
## Context
ERD: [Link to ERD]
PRD: [Link to PRD if applicable]
Depends on: [List of blocking ticket numbers, or "None"]
Blocks: [List of tickets this unblocks, or "None"]

## Requirements
- REQ-XXX: [Requirement from ERD]
- REQ-YYY: [Another requirement]

## Acceptance Criteria
- [ ] [Specific, testable criterion]
- [ ] [Another criterion]
- [ ] Tests pass
- [ ] Build passes

## Technical Notes
[Any implementation guidance, links to relevant ERD sections]

## Out of Scope
[What this ticket explicitly does not include]
```

---

## Dependency Patterns

### Common Dependency Chains

```
1. Schema migrations
   ↓
2. Type definitions / interfaces
   ↓
3. Data access layer (repositories)
   ↓
4. Business logic (services)
   ↓
5. API handlers
   ↓
6. UI components
   ↓
7. E2E tests
```

### Breaking Circular Dependencies

If A depends on B and B depends on A:
1. Extract the shared concern into ticket C
2. A and B both depend on C
3. A and B can then be parallelized

### Handling Unknowns

> "If your team estimates a story at more than about 3 weeks, split it—on the grounds that we don't understand it."
> — Ron Jeffries

If a ticket is too large or unclear:
1. Create a spike/research ticket first
2. Spike output informs how to split the work
3. Create the real tickets after the spike

---

## The Burndown Rule

**Work the backlog top to bottom. No skipping.**

When you pick up the next ticket:
1. All dependencies should already be complete
2. If they're not, something is wrong with the order
3. Fix the order, don't skip ahead

> "Proper ordering takes deep knowledge of the business, market, and engineering dependencies between items."
> — Scrum.org

---

## Checklist

Before starting burndown:

- [ ] GitHub Project exists (kanban board)
- [ ] All tickets created from ERD requirements
- [ ] Each ticket has clear acceptance criteria
- [ ] Each ticket is INVEST-compliant (especially Small and Testable)
- [ ] Dependencies documented in each ticket
- [ ] Tickets ordered by dependency graph
- [ ] No ticket depends on one below it in the backlog
- [ ] First ticket has no dependencies

---

## Quick Reference

```bash
# Auth with project scope
gh auth refresh -s project

# List existing projects
gh project list --owner <owner>

# Create new project
gh project create --owner <owner> --title "Project Name"

# Create issue and add to project
gh issue create \
  --title "feat(scope): description" \
  --body "Issue body" \
  --project "Project Name"

# List project items
gh project item-list <number> --owner <owner>

# Add existing issue to project
gh project item-add <number> --owner <owner> --url <issue-url>
```

---

## Sources

This guide synthesizes best practices from:

- [Allen Holub](https://holub.com/classes/stories2code/) — Vertical slicing, smallest valuable increment
- [Kent Beck](https://tidyfirst.substack.com/p/scaling-extreme-programming-dependencies) — XP task breakdown, dependency management
- [Scrum.org](https://www.scrum.org/resources/ordered-not-prioritized) — Ordering vs prioritization, dependency awareness
- [Atlassian](https://www.atlassian.com/agile/project-management/epics) — Epic breakdown, user story best practices
- [Humanizing Work](https://www.humanizingwork.com/the-humanizing-work-guide-to-splitting-user-stories/) — Story splitting techniques
- [GitHub CLI](https://cli.github.com/manual/gh_project) — Project and issue management commands
- [GitHub Blog](https://github.blog/developer-skills/github/github-cli-project-command-is-now-generally-available/) — gh project command documentation
