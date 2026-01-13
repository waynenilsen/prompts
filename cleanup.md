# Pre-Push Cleanup

You're done. Tests pass. Before you push, review your own work.

---

## The Process

### 1. Format

Run your formatter. Don't make reviewers comment on whitespace.

```bash
npm run format
# or
cargo fmt
# or
black .
```

### 2. Stage Everything

```bash
git add -A
```

### 3. Review Your Own Diff

```bash
git diff --staged
```

Read it like a reviewer would. Line by line.

---

## What to Look For

### Repeated Code

You wrote the same logic twice? Three times? Extract it.

```typescript
// Before: copy-pasted validation
if (user.email && user.email.includes('@')) { ... }
// ... 40 lines later ...
if (admin.email && admin.email.includes('@')) { ... }

// After: one function
function isValidEmail(email: string): boolean {
  return Boolean(email && email.includes('@'));
}
```

### Debug Leftovers

```typescript
console.log('here');           // delete
console.log('user:', user);    // delete
debugger;                      // delete
// TODO: remove this           // remove this
```

### Commented-Out Code

```typescript
// const oldImplementation = () => {
//   ...50 lines...
// };
```

Delete it. Git remembers.

### Hardcoded Values That Should Be Constants

```typescript
// Before
if (retries > 3) { ... }
setTimeout(fn, 5000);

// After
const MAX_RETRIES = 3;
const TIMEOUT_MS = 5000;
```

### Inconsistent Naming

You called it `userData` in one place and `userInfo` in another. Pick one.

### Missing Error Handling

You added the happy path. What happens when:
- The network fails?
- The input is null?
- The array is empty?

### Accidental Complexity

That clever one-liner? Replace it with three readable lines.

```typescript
// Before: clever
const result = data?.items?.filter(Boolean).reduce((a, b) => ({...a, [b.id]: b}), {}) ?? {};

// After: readable
const result: Record<string, Item> = {};
for (const item of data?.items ?? []) {
  if (item) {
    result[item.id] = item;
  }
}
```

### Scope Creep

You were fixing a bug in the login flow. Why is there a refactored date utility in this diff?

Keep commits focused. Split unrelated changes.

### Type Shortcuts

```typescript
// Before
const data: any = fetchData();
const config = response as unknown as Config;

// After: actual types
const data: UserResponse = fetchData();
const config: Config = parseConfig(response);
```

### Dead Code

That function you wrote but never called? That variable you assigned but never read? Delete it.

---

## The Checklist

Before pushing:

- [ ] Code is formatted
- [ ] No console.log / debugger / print statements
- [ ] No commented-out code
- [ ] No copy-pasted blocks (DRY)
- [ ] Naming is consistent
- [ ] No `any` types or unsafe casts
- [ ] No hardcoded magic numbers
- [ ] Error cases are handled
- [ ] No unrelated changes in the diff
- [ ] Every function/variable is actually used

---

## Why Self-Review

Every issue you catch is one less:
- Code review comment to address
- Back-and-forth with reviewers
- Context switch when you revisit later
- Bug in production

Your reviewer's time is valuable. Don't waste it on things you could have caught yourself.

---

## Quick Reference

```bash
# Format
npm run format

# Stage
git add -A

# Review
git diff --staged

# Commit when clean
git commit -m "feat(auth): add password reset flow"
```

Read your diff. Fix what you find. Then push.
