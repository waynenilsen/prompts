# Tech Debt Engineering Requirements Document (ERD)

The technical specification for identifying and addressing technical debt in the codebase.

---

## Philosophy

> "Technical debt is like financial debt: some is good, but too much will kill you."
> — Ward Cunningham

Technical debt accumulates naturally as code evolves. Regular cycles dedicated to reducing it prevent the codebase from becoming unmaintainable.

---

## When to Use This Template

**Use this template when the next ERD number ends in 5 or 0** (e.g., `0005`, `0010`, `0015`, `0020`).

This corresponds to a tech debt PRD cycle. Every 5th cycle is dedicated to paying down technical debt.

---

## Core Principles

### 1. Must Not Violate Prompts Folder Directives

**CRITICAL:** Any tech debt remediation must align with all guidance in the `prompts/` folder. You cannot:

- Introduce patterns that contradict existing prompts
- Remove practices required by prompts
- Add external services when prompts forbid them
- Change architecture patterns defined in prompts

**Before making any change, verify it aligns with:**

- [Project Setup](./setup.md) - Stack and configuration
- [tRPC Guide](./trpc.md) - API patterns (never Server Actions)
- [Authentication](./auth.md) - Auth patterns
- [Frontend Architecture](./frontend.md) - Component/hook organization
- [Unit Testing](./unit-testing.md) - Testing patterns
- [Pre-Push Cleanup](./cleanup.md) - Code quality standards

### 2. Identify Tech Debt Categories

Tech debt manifests in five primary forms:

#### Code Duplication

**Symptoms:**

- Same logic appears in multiple files
- Copy-pasted functions with slight variations
- Repeated validation patterns
- Duplicate type definitions

**Remediation:**

- Extract shared logic into reusable functions
- Create shared utilities or hooks
- Consolidate type definitions
- Use composition over duplication

**Example:**

```typescript
// Before: Duplicated validation
// src/components/LoginForm.tsx
if (email && email.includes('@')) { ... }

// src/components/SignupForm.tsx
if (email && email.includes('@')) { ... }

// After: Extracted utility
// src/lib/validation.ts
export function isValidEmail(email: string): boolean {
  return Boolean(email && email.includes('@'));
}
```

#### Lacking Test Coverage

**Symptoms:**

- Functions without corresponding test files
- Test coverage below 95% threshold (see [Unit Testing](./unit-testing.md))
- Missing edge case coverage
- E2E tests missing for critical flows

**Remediation:**

- Add unit tests (`*.test.ts` next to source files)
- Add E2E tests (`e2e/*.e2e.ts`) for user flows
- Achieve 95% coverage threshold
- Test error paths and edge cases

**Verification:**

```bash
bun test --coverage
```

Coverage reports will show gaps. Address them systematically.

#### Misalignment with Prompts Folder Directives

**Symptoms:**

- Server Actions used instead of tRPC
- External services added without PRD approval
- Tests in wrong location (`tests/` instead of next to source)
- Missing TypeDoc comments on public APIs
- Business logic in components instead of hooks
- Hardcoded values instead of constants
- Schema changes committed without migrations
- Migrations committed without schema changes
- Schema and migration split across multiple commits

**Remediation:**

- Replace Server Actions with tRPC routers (see [tRPC Guide](./trpc.md))
- Remove unauthorized external services
- Move tests to correct locations
- Add TypeDoc comments (see [Pre-Push Cleanup](./cleanup.md))
- Extract hooks from components (see [Frontend Architecture](./frontend.md))
- Extract constants from magic numbers
- Ensure schema changes and migrations are committed together (see [Database Schema and Migrations](./db.md))

#### God Mode / God Classes

**Symptoms:**

- Single files exceeding 500+ lines
- Classes or modules with too many responsibilities
- Files that import from dozens of other modules
- Abstractions that handle multiple unrelated concerns
- Difficult to test due to size and complexity
- Hard to understand or modify without breaking other parts
- Barrel exports (`index.ts`) that re-export everything from a single large file

**Remediation:**

- Break large files into smaller, focused modules (single responsibility principle)
- Split god classes into multiple smaller classes or functions
- **Consider existing abstractions and design patterns** when refactoring (e.g., Repository pattern, Factory pattern, Strategy pattern, Observer pattern) rather than reinventing solutions
- Use barrel exports (`index.ts`) to organize related exports, not to hide large implementations
- Each module should have its own unit test file (`*.test.ts`)
- Extract related functionality into separate files with clear boundaries
- Group related exports in barrel files, but keep implementations separate
- Aim for files under 300 lines (200 lines ideal)

**Example:**

```typescript
// Before: God class in single file
// src/lib/users.ts (800+ lines)
export class UserManager {
  // Authentication logic
  // Authorization logic
  // CRUD operations
  // Email sending
  // Validation
  // Caching
  // Analytics
  // ... too many responsibilities
}

// After: Split into focused modules
// src/lib/users/auth.ts
export function authenticateUser(email: string, password: string) { ... }

// src/lib/users/authorization.ts
export function checkPermission(userId: string, resource: string) { ... }

// src/lib/users/crud.ts
export function createUser(data: UserData) { ... }
export function updateUser(id: string, data: Partial<UserData>) { ... }

// src/lib/users/index.ts (barrel export)
export * from './auth';
export * from './authorization';
export * from './crud';
export * from './types';

// Each file has its own test:
// src/lib/users/auth.test.ts
// src/lib/users/authorization.test.ts
// src/lib/users/crud.test.ts
```

**Verification:**

- Check file sizes: `find src -name "*.ts" -o -name "*.tsx" | xargs wc -l | sort -rn`
- Review imports: files importing from 10+ modules may be doing too much
- Check test coverage: large files often have incomplete test coverage

#### Spaghetti Code

**Symptoms:**

- Unclear control flow with deeply nested conditionals
- Functions with multiple return points scattered throughout
- Circular dependencies between modules
- Unclear data flow (data passed through many layers without clear purpose)
- Mixed levels of abstraction in the same function
- Long parameter lists (5+ parameters)
- Functions that do multiple unrelated things
- Global state mutations from multiple places
- Inconsistent error handling patterns
- Code that's hard to follow linearly

**Remediation:**

- Extract functions to reduce nesting (early returns, guard clauses)
- Break complex functions into smaller, single-purpose functions
- **Consider existing abstractions and design patterns** when refactoring (e.g., Command pattern, Chain of Responsibility, State pattern, Template Method) rather than creating ad-hoc solutions
- Use clear variable names that express intent
- Eliminate circular dependencies by introducing interfaces or dependency inversion
- Establish clear data flow patterns (unidirectional where possible)
- Use consistent error handling (see [Error Handling Patterns](./frontend.md))
- Reduce function parameters by grouping related data into objects
- Extract complex conditionals into well-named functions or variables
- Use composition to build complex behavior from simple parts
- Apply consistent patterns throughout the codebase

**Example:**

```typescript
// Before: Spaghetti code
function processOrder(order: Order, user: User, payment: Payment, inventory: Inventory, email: EmailService, logger: Logger) {
  if (order) {
    if (user) {
      if (user.isActive) {
        if (payment) {
          if (payment.isValid) {
            if (inventory) {
              if (inventory.hasStock(order.items)) {
                // ... 50 more lines of nested logic
                if (email) {
                  email.send(order.id);
                }
              } else {
                logger.error('no stock');
              }
            }
          } else {
            logger.error('invalid payment');
          }
        }
      } else {
        logger.error('inactive user');
      }
    }
  }
}

// After: Clear, linear flow with early returns
function processOrder(params: ProcessOrderParams) {
  const { order, user, payment, inventory, emailService, logger } = params;
  
  if (!order) throw new Error('Order required');
  if (!isActiveUser(user)) throw new Error('User must be active');
  if (!isValidPayment(payment)) throw new Error('Invalid payment');
  if (!hasStock(inventory, order.items)) throw new Error('Insufficient stock');
  
  const result = fulfillOrder(order, inventory);
  emailService.sendOrderConfirmation(order.id);
  
  return result;
}

function isActiveUser(user: User): boolean {
  return user?.isActive === true;
}

function isValidPayment(payment: Payment): boolean {
  return payment?.isValid === true;
}

function hasStock(inventory: Inventory, items: OrderItem[]): boolean {
  return items.every(item => inventory.hasItem(item.id, item.quantity));
}
```

**Verification:**

- Review cyclomatic complexity: functions with complexity > 10 need refactoring
- Check for circular dependencies: `npx madge --circular src`
- Trace data flow: can you follow data from input to output?
- Review function length: functions > 50 lines often need splitting

#### Security Vulnerabilities

**Symptoms:**

- Cross-Site Scripting (XSS) vulnerabilities
- SQL injection risks (raw queries without Prisma)
- Poor cookie security practices
- Cross-Site Request Forgery (CSRF) vulnerabilities
- Missing authentication/authorization checks
- Sensitive data exposure (API keys, passwords in logs/code)
- Insecure direct object references
- Missing input validation (not using Zod schemas)
- Missing rate limiting
- Weak session management
- Dependency vulnerabilities (outdated packages)
- Missing HTTPS enforcement
- Information disclosure (error messages revealing too much)
- Insecure file uploads (if applicable)

**Remediation:**

**XSS Prevention:**

- Sanitize all user input before rendering
- Use React's built-in escaping (don't use `dangerouslySetInnerHTML` without sanitization)
- Validate and sanitize data from tRPC inputs
- Use Content Security Policy (CSP) headers

```typescript
// Wrong: Direct rendering
<div>{userInput}</div>

// Right: React auto-escapes, but validate input
<div>{sanitize(userInput)}</div>
```

**SQL Injection Prevention:**

- Always use Prisma queries (never raw SQL with user input)
- If raw queries are necessary, use parameterized queries only
- Never concatenate user input into SQL strings

```typescript
// Wrong: Raw SQL with user input
prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;

// Right: Prisma query builder
prisma.user.findUnique({ where: { email } });
```

**Cookie Security:**

- Set `httpOnly: true` (prevents JavaScript access)
- Set `secure: true` in production (HTTPS only)
- Set `sameSite: 'lax'` or `'strict'` (CSRF protection)
- Use strong session tokens (crypto.randomBytes)
- Set appropriate `maxAge` and implement expiration

```typescript
// src/lib/auth.ts
cookies().set("session", token, {
  httpOnly: true,
  secure: process.env.STAGE === "production",
  sameSite: "lax",
  maxAge: 60 * 60 * 24 * 7, // 7 days
});
```

**CSRF Protection:**

- Use SameSite cookies (`sameSite: 'lax'` or `'strict'`)
- Verify Origin/Referer headers for state-changing operations
- Use CSRF tokens for forms (if not using SameSite cookies)

**Authentication/Authorization:**

- Always verify user identity before sensitive operations
- Check authorization (ownership/permissions) before data access
- Use middleware for protected routes
- Never trust client-side authorization checks alone

```typescript
// src/server/routers/user.ts
update: protectedProcedure
  .input(z.object({ id: z.string(), name: z.string() }))
  .mutation(async ({ ctx, input }) => {
    // Verify ownership
    const user = await ctx.prisma.user.findUnique({
      where: { id: input.id },
    });
    if (user?.id !== ctx.session.userId) {
      throw new TRPCError({ code: 'FORBIDDEN' });
    }
    // ... update logic
  }),
```

**Sensitive Data Exposure:**

- Never log passwords, API keys, or tokens
- Use environment variables for secrets (never commit)
- Sanitize error messages (don't expose stack traces in production)
- Use `.env` files with `.gitignore` protection

**Input Validation:**

- Always use Zod schemas for tRPC inputs
- Validate on both client and server
- Reject invalid input early

```typescript
// src/server/routers/user.ts
create: publicProcedure
  .input(
    z.object({
      email: z.string().email(), // Validates email format
      name: z.string().min(1).max(100), // Length validation
    })
  )
  .mutation(async ({ ctx, input }) => {
    // Input is guaranteed valid here
  }),
```

**Rate Limiting:**

- Implement rate limiting for authentication endpoints
- Protect against brute force attacks
- Use middleware or tRPC middleware for rate limiting

**Session Management:**

- Use cryptographically secure random tokens
- Implement session expiration
- Invalidate sessions on logout
- Store sessions securely (database, not cookies for large data)

**Dependency Security:**

- Regularly update dependencies (`bun update`)
- Run security audits (`bun audit` or similar)
- Review changelogs for security patches
- Pin critical dependency versions

**HTTPS Enforcement:**

- Enforce HTTPS in production
- Use secure cookies (`secure: true`)
- Redirect HTTP to HTTPS
- Use HSTS headers

**Information Disclosure:**

- Don't expose stack traces in production errors
- Sanitize error messages (don't reveal internal structure)
- Use generic error messages for users, detailed logs for developers

```typescript
// Wrong: Exposing internal details
throw new Error(`Database connection failed: ${dbPassword}`);

// Right: Generic user message, detailed server logs
logger.error("Database connection failed", { error });
throw new TRPCError({
  code: "INTERNAL_SERVER_ERROR",
  message: "An error occurred. Please try again.",
});
```

**File Upload Security (if applicable):**

- Validate file types (whitelist, not blacklist)
- Scan for malware
- Store uploads outside web root
- Rename files to prevent path traversal
- Limit file size

---

## The Template

### Metadata

```
ERD: [4-digit ID ending in 5 or 0]
Title: Tech Debt Reduction Cycle
Author: [Engineer Name]
Status: [Draft | In Review | Approved | In Progress | Complete]
PRD: [Link to corresponding tech debt PRD]
Last Updated: [Date]
Reviewers: [List of reviewers]
```

### Overview

**One paragraph** summarizing the tech debt areas identified and the remediation strategy.

### Background

What context led to this tech debt cycle? Link to:

- Previous PRDs that may have introduced debt
- Code review feedback
- Test coverage reports
- Static analysis findings

### Goals and Non-Goals

**Goals:**

- Reduce code duplication by X%
- Increase test coverage to 95%
- Align codebase with prompts folder directives
- Break down god classes/files into focused modules with barrel exports
- Refactor spaghetti code into clear, linear control flow
- Remediate security vulnerabilities (XSS, SQL injection, insecure cookies, etc.)
- Improve maintainability without changing functionality

**Non-Goals:**

- Adding new features (this is a refactoring cycle)
- Changing user-facing behavior
- Introducing new patterns not in prompts folder
- Performance optimization (unless it's misalignment with directives)

### Tech Debt Inventory

Create a systematic inventory of tech debt:

| Category           | Location                                | Severity | Effort | Priority |
| ------------------ | --------------------------------------- | -------- | ------ | -------- |
| Code Duplication   | `src/lib/users.ts`, `src/lib/admins.ts` | High     | Medium | 1        |
| Missing Tests      | `src/hooks/use-orders.ts`               | Medium   | Low    | 2        |
| Server Action      | `src/app/api/users/route.ts`            | High     | Medium | 3        |
| God Class          | `src/lib/order-manager.ts` (800+ lines) | High     | High   | 4        |
| Spaghetti Code     | `src/components/Checkout.tsx`           | Medium   | Medium | 5        |
| XSS Vulnerability  | `src/components/Comment.tsx`            | High     | Low    | 6        |
| Insecure Cookies   | `src/lib/auth.ts`                       | High     | Low    | 7        |
| Missing Auth Check | `src/server/routers/admin.ts`           | High     | Medium | 8        |
| Hardcoded Values   | `src/components/Payment.tsx`            | Low      | Low    | 9        |

**Severity levels:**

- **High:** Blocks maintainability or violates core directives
- **Medium:** Creates friction but doesn't block work
- **Low:** Minor improvement opportunity

**Effort levels:**

- **High:** Requires significant refactoring
- **Medium:** Moderate refactoring needed
- **Low:** Quick fix

### Technical Requirements

Use requirement IDs for traceability.

| ID      | Requirement                                                            | Priority |
| ------- | ---------------------------------------------------------------------- | -------- |
| REQ-001 | All duplicated validation logic shall be extracted to shared utilities | Must     |
| REQ-002 | Test coverage shall reach 95% for all modified files                   | Must     |
| REQ-003 | All Server Actions shall be replaced with tRPC routers                 | Must     |
| REQ-004 | All XSS vulnerabilities shall be remediated (sanitize user input)      | Must     |
| REQ-005 | All cookies shall use secure, httpOnly, and sameSite flags             | Must     |
| REQ-006 | All protected routes shall verify authentication and authorization     | Must     |
| REQ-007 | All user input shall be validated with Zod schemas                     | Must     |
| REQ-008 | All files exceeding 500 lines shall be split into focused modules      | Must     |
| REQ-009 | All god classes shall be broken into smaller, single-responsibility modules | Must     |
| REQ-010 | All barrel exports shall organize separate implementations, not hide large files | Must     |
| REQ-011 | All complex functions (>50 lines or complexity >10) shall be refactored | Must     |
| REQ-012 | All circular dependencies shall be eliminated                          | Must     |
| REQ-013 | All hardcoded values shall be extracted to constants                   | Should   |
| REQ-014 | All public APIs shall have TypeDoc comments                            | Must     |
| REQ-015 | Rate limiting shall be implemented for authentication endpoints        | Should   |

### Remediation Strategy

**Phase 1: Critical Security Vulnerabilities**

- Fix XSS vulnerabilities (sanitize all user input)
- Secure cookies (httpOnly, secure, sameSite flags)
- Add missing authentication/authorization checks
- Fix SQL injection risks (use Prisma, no raw queries)
- Implement CSRF protection

**Phase 2: High-Priority Violations**

- Replace Server Actions with tRPC
- Remove unauthorized external services
- Fix test location violations
- Add input validation (Zod schemas)

**Phase 3: Code Duplication**

- Identify duplicated patterns
- Extract shared utilities
- Update all call sites

**Phase 4: God Classes and Large Files**

- Identify files exceeding 500 lines
- Break god classes into focused modules
- Create barrel exports for organization
- Ensure each module has its own unit test
- Verify no single file exceeds 300 lines

**Phase 5: Spaghetti Code**

- Identify complex functions (high cyclomatic complexity)
- Refactor deeply nested conditionals with early returns
- Break complex functions into smaller, single-purpose functions
- Eliminate circular dependencies
- Establish clear data flow patterns
- Reduce function parameters by grouping related data

**Phase 6: Test Coverage**

- Add missing unit tests
- Add missing E2E tests
- Verify 95% coverage threshold

**Phase 7: Code Quality**

- Extract constants
- Add TypeDoc comments
- Extract hooks from components
- Implement rate limiting
- Update dependencies (security patches)

### Verification

After remediation, verify:

```bash
# Format and lint
bun run check

# Compile docs
bun run docs

# Test coverage
bun test --coverage

# Build
bun run build

# E2E tests
bun run test:e2e
```

All must pass.

### Testing Strategy

- **Unit tests:** Add `*.test.ts` files next to source files
- **E2E tests:** Add `*.e2e.ts` files in `e2e/` directory
- **Coverage:** Achieve 95% threshold (see [Unit Testing](./unit-testing.md))
- **No behavior changes:** Refactoring should not change functionality

### Constraints Checklist

Before proceeding, verify:

- [ ] All changes align with prompts folder directives
- [ ] No external services added (unless approved in PRD)
- [ ] Tests are in correct locations (`*.test.ts` next to source, `*.e2e.ts` in `e2e/`)
- [ ] No Server Actions introduced (use tRPC)
- [ ] No new patterns that contradict existing prompts
- [ ] TypeDoc comments added for public APIs
- [ ] Hooks extracted from components where appropriate
- [ ] All user input sanitized (XSS prevention)
- [ ] Cookies use secure, httpOnly, and sameSite flags
- [ ] Authentication/authorization checks in place
- [ ] All inputs validated with Zod schemas
- [ ] No sensitive data in logs or error messages
- [ ] Dependencies updated (security patches)
- [ ] All files exceeding 500 lines split into focused modules
- [ ] All god classes broken into smaller, single-responsibility modules
- [ ] Barrel exports organize separate implementations, not hide large files
- [ ] All complex functions refactored (no functions >50 lines or complexity >10)
- [ ] All circular dependencies eliminated
- [ ] Control flow is clear and linear (no deeply nested conditionals)

### Open Questions

What's unresolved? What needs input?

### Dependencies

- No external service dependencies (by design)
- May depend on previous PRDs if they introduced the debt
- Timeline blockers

---

## Anti-Patterns

### Changing Functionality

Tech debt cycles are for refactoring, not feature work. Don't change what the code does, only how it's structured.

### Violating Prompts Directives

You cannot fix tech debt by introducing patterns that contradict the prompts folder. That's creating new debt, not paying it down.

### Skipping Tests

Refactoring without tests is dangerous. Add tests first, then refactor.

### Scope Creep

Don't try to fix everything at once. Focus on the highest-priority items that align with the inventory.

### Creating New God Classes

Breaking down a god class by creating another god class defeats the purpose. Each new module should have a single, clear responsibility.

### Hiding Complexity in Barrel Exports

Using barrel exports (`index.ts`) to hide large implementations doesn't solve the problem. Barrel exports should organize small, focused modules, not mask god classes.

### Refactoring Without Understanding Flow

Refactoring spaghetti code without first understanding the data flow and control flow can introduce bugs. Trace execution paths before restructuring.

---

## Checklist

Before requesting review:

- [ ] Links to corresponding tech debt PRD
- [ ] Tech debt inventory completed
- [ ] All changes align with prompts folder directives
- [ ] Test coverage at 95% threshold
- [ ] No Server Actions (all use tRPC)
- [ ] No unauthorized external services
- [ ] Tests in correct locations
- [ ] TypeDoc comments added
- [ ] All XSS vulnerabilities remediated (user input sanitized)
- [ ] All cookies use secure, httpOnly, and sameSite flags
- [ ] Authentication/authorization checks in place
- [ ] All inputs validated with Zod schemas
- [ ] No sensitive data in logs or error messages
- [ ] Dependencies updated (security patches)
- [ ] All files exceeding 500 lines split into focused modules
- [ ] All god classes broken into smaller modules with barrel exports
- [ ] All complex functions refactored (no functions >50 lines or complexity >10)
- [ ] All circular dependencies eliminated
- [ ] Control flow is clear and linear (no spaghetti code)
- [ ] All verification steps pass
- [ ] No functionality changes (refactoring only)

---

## Related

- [Product Requirements Document](../product/prd.md) - Standard PRD template
- [Tech Debt PRD](../product/tech-debt-prd.md) - Minimal PRD for tech debt cycles
- [Pre-Push Cleanup](./cleanup.md) - Code quality standards
- [Unit Testing](./unit-testing.md) - Testing patterns and coverage thresholds
- [tRPC Guide](./trpc.md) - API patterns (never use Server Actions)
- [Frontend Architecture](./frontend.md) - Component and hook organization
- [Database Schema and Migrations](./db.md) - Schema changes and migration management
- [Implement Ticket](./implement-ticket.md) - Process for completing tickets
