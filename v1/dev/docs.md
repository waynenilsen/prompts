# Documentation Guidelines

## Overview

Documentation is **critical** - it describes what code is intended to do in plain English. It's not optional, it's not trivial, and it's not just for you. Documentation may be public and will be read by humans (including future you) who need to understand the code's purpose and behavior.

## Requirements

### Every Function Must Have Documentation

- **All exported functions, methods, classes, interfaces, type aliases, and variables must have JSDoc comments**
- TypeDoc is configured to fail the build if documentation is missing
- This is enforced automatically - you cannot skip it

### Documentation Quality Standards

Documentation must be:

1. **Descriptive, not trivial**: Don't just restate the function name. Explain what the function is **intended to do** in plain English.

2. **Detailed about intent**: Describe the purpose, behavior, and reasoning. What problem does this solve? Why does it exist?

3. **Include context**: Where relevant, include:
   - **Pre-conditions**: What must be true before calling this function?
   - **Post-conditions**: What is guaranteed to be true after it completes?
   - **Side effects**: Does it modify global state, make network calls, etc.?
   - **Edge cases**: How does it handle unusual inputs or conditions?

4. **Written for humans**: Assume someone reading this later has no context. Write clearly and comprehensively.

## Format

Use JSDoc format with TypeScript:

```typescript
/**
 * Merges class names with Tailwind CSS conflict resolution.
 * Combines clsx and tailwind-merge to handle conditional classes and Tailwind conflicts.
 * 
 * This function is essential for component styling - it ensures that Tailwind classes
 * override correctly when conditionally applied. For example, if you have both
 * "px-4" and "px-6" in the inputs, only "px-6" will be in the output.
 *
 * @param inputs - Class names or conditional class objects (e.g., { 'active': isActive })
 * @returns Merged class string with Tailwind conflicts resolved
 * 
 * @example
 * ```tsx
 * cn('foo', 'bar') // => 'foo bar'
 * cn('px-4', 'px-6') // => 'px-6' (Tailwind conflict resolved)
 * cn({ 'active': true, 'disabled': false }) // => 'active'
 * ```
 */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
```

## Examples

### Good Documentation

```typescript
/**
 * Sends an email using the configured transport.
 * 
 * This function abstracts email delivery across different environments:
 * - Local/test: Uses Mailhog or console logging for development visibility
 * - Production: Uses SendGrid API for actual delivery
 * 
 * The function handles rendering React Email templates to HTML and manages
 * transport selection based on the STAGE environment variable. All email
 * failures are caught and returned as errors rather than throwing.
 *
 * @param options - Email configuration
 * @param options.to - Recipient email address(es) - single string or array
 * @param options.subject - Email subject line
 * @param options.template - React Email template component to render
 * @param options.from - Optional sender address (defaults to EMAIL_FROM env var)
 * @returns Promise resolving to send result with success status and message ID
 * 
 * @example
 * ```tsx
 * const result = await sendEmail({
 *   to: 'user@example.com',
 *   subject: 'Welcome!',
 *   template: <WelcomeEmail name="Alice" loginUrl="/login" />
 * });
 * if (result.success) {
 *   console.log('Email sent:', result.messageId);
 * }
 * ```
 */
export async function sendEmail({
  to,
  subject,
  template,
  from,
}: SendEmailOptions): Promise<SendEmailResult> {
  // ... implementation
}
```

### Bad Documentation (Don't Do This)

```typescript
// ❌ Too trivial - just restates the function name
/** Sends an email */
export async function sendEmail(...) { }

// ❌ Missing - will cause TypeDoc to fail
export async function sendEmail(...) { }

// ❌ Vague - doesn't explain behavior or intent
/** Email function */
export async function sendEmail(...) { }
```

## Maintenance

### Keep Documentation Up to Date

- **If you notice documentation has drifted from the implementation, fix it immediately**
- Even if it's not your current area of work, update incorrect or outdated docs
- Documentation drift is a bug - treat it as such

### When to Update Documentation

Update documentation when:
- The function's behavior changes
- Pre/post conditions change
- New edge cases are discovered
- The function's purpose or intent evolves
- You notice the docs don't match reality

## TypeDoc Integration

- TypeDoc automatically generates HTML documentation from JSDoc comments
- Run `bun run docs` to generate documentation
- The build will fail if any exported symbols lack documentation
- Generated docs are available in the `docs/` directory

## Best Practices

1. **Start with "what" and "why"**: Explain the function's purpose before diving into details
2. **Use examples**: Show how to use the function, especially for complex APIs
3. **Document parameters**: Use `@param` tags to describe each parameter
4. **Document return values**: Use `@returns` to explain what the function returns
5. **Note side effects**: Mention if the function modifies state, makes network calls, etc.
6. **Explain edge cases**: How does it handle null, empty arrays, errors, etc.?
7. **Reference related functions**: Link to related functions or concepts when helpful

## Common Patterns

### Async Functions

```typescript
/**
 * Fetches user data from the API.
 * 
 * Makes an authenticated request to the user endpoint. Returns null if the
 * user doesn't exist or if the request fails. Caches the result for the
 * duration of the request.
 *
 * @param userId - The user ID to fetch
 * @returns Promise resolving to user object or null if not found
 * @throws {AuthError} If authentication fails
 */
export async function fetchUser(userId: string): Promise<User | null> {
  // ...
}
```

### React Components

```typescript
/**
 * Button component with variant support.
 * 
 * Renders a button with configurable styles via variants. Supports all
 * standard button interactions (click, focus, disabled states). Automatically
 * handles accessibility attributes.
 *
 * @param props - Button props
 * @param props.variant - Visual style variant (default, destructive, outline, etc.)
 * @param props.size - Size variant (sm, md, lg)
 * @param props.children - Button content
 * @returns Button element
 */
export function Button({ variant, size, children, ...props }: ButtonProps) {
  // ...
}
```

### Type Aliases and Interfaces

```typescript
/**
 * Configuration options for sending emails.
 * 
 * All fields except `from` are required. The `from` field defaults to
 * the EMAIL_FROM environment variable if not provided.
 */
export interface SendEmailOptions {
  /** Recipient email address(es) */
  to: string | string[];
  /** Email subject line */
  subject: string;
  /** React Email template component to render */
  template: React.ReactElement;
  /** Optional sender address */
  from?: string;
}
```

## Enforcement

- TypeDoc validation runs on every `bun run docs` command
- The build process fails if documentation is missing
- CI/CD pipelines will catch missing documentation before merge
- No exceptions - all exported symbols must be documented

## Remember

Documentation is not optional. It's not "nice to have." It's a **requirement** for maintainable, understandable code. Write documentation as if someone's job depends on understanding your code - because it might.
