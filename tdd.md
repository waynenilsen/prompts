# Test-Driven Development

Write tests first. Make them fail for the right reasons. Then implement.

## The Cycle

```
Red → Green → Refactor
```

1. **Red** - Write a failing test
2. **Green** - Write minimal code to pass
3. **Refactor** - Clean up without changing behavior

Repeat.

---

## The Critical Rule: Fail for the Right Reason

**Tests must fail because the logic is wrong, not because the code doesn't exist.**

### Wrong Way to Fail

```
ERROR: Cannot find module './userService'
ERROR: TypeError: getUserById is not a function
ERROR: Connection refused: localhost:5432
ERROR: Class 'OrderProcessor' not found
```

These are **infrastructure failures**. They tell you nothing about your logic. They waste your time debugging setup instead of design.

### Right Way to Fail

```
FAIL: Expected getUserById(1) to return { id: 1, name: 'Alice' }
      Received: null

FAIL: Expected calculateTotal([10, 20, 30]) to return 60
      Received: 0
```

This is a **logic failure**. The function exists, it runs, it returns the wrong thing. Now you implement.

---

## The Process

### Step 1: Write the Test

```typescript
test('getUserById returns user with matching id', () => {
  const user = getUserById(1);
  expect(user).toEqual({ id: 1, name: 'Alice' });
});
```

### Step 2: Write the Signature with a Stub

```typescript
interface User {
  id: number;
  name: string;
}

function getUserById(id: number): User | null {
  return null;  // stub implementation
}
```

**The stub must:**
- Have the correct signature (params, return type)
- Return a constant that will fail the test
- Compile cleanly

### Step 3: Verify the Test Fails Correctly

Run the test. You should see:

```
FAIL: Expected { id: 1, name: 'Alice' }
      Received: null
```

**Not** `function not found`. **Not** `cannot connect to database`.

If you see an infrastructure error, fix it before proceeding. The test must call your function and fail on the return value.

### Step 4: Implement

Only now do you write the actual logic:

```typescript
function getUserById(id: number): User | null {
  return users.find(u => u.id === id) ?? null;
}
```

### Step 5: Verify the Test Passes

```
PASS: getUserById returns user with matching id
```

### Step 6: Refactor

Clean up. Extract. Rename. The tests protect you.

---

## Stub Patterns

### Return Constants

```typescript
function add(a: number, b: number): number {
  return 0;
}

function isValid(input: string): boolean {
  return false;
}

function fetchUser(id: string): Promise<User> {
  return Promise.resolve({ id: '', name: '' });
}
```

### Throw Not Implemented

For complex cases where a constant doesn't make sense:

```typescript
function processOrder(order: Order): Receipt {
  throw new Error('Not implemented');
}
```

The test will fail with a clear error, and the code compiles.

### Empty Collections

```typescript
function getActiveUsers(): User[] {
  return [];
}

function groupByCategory(items: Item[]): Map<string, Item[]> {
  return new Map();
}
```

---

## The Checklist

Before implementing any function body, verify:

- [ ] Test file exists and imports work
- [ ] Function/class signature is defined
- [ ] Types/interfaces are defined
- [ ] Stub returns a constant (wrong) value
- [ ] **Code compiles**
- [ ] **Test runs**
- [ ] **Test fails on assertion, not on infrastructure**

Only when all boxes are checked: implement.

---

## Why This Matters

### Trivial failures waste time

Debugging `module not found` or `connection refused` is not TDD. It's yak shaving. Get the plumbing working first.

### Correct failures validate your test

If your test passes with a stub that returns `null`, your test is broken. A properly failing test proves the test itself works.

### Signatures force design decisions

Writing `function getUserById(id: number): User | null` before implementing forces you to decide:
- What are the inputs?
- What is the return type?
- Can it fail? How?

This is the value of test-first: **interface before implementation**.

---

## Common Mistakes

### Writing the implementation first

You wrote the function, now you're writing tests to cover it. That's test-after. You're testing what you built, not building what you tested.

### Testing against the database in unit tests

Your unit test shouldn't need Postgres running. Mock the data layer. Save integration tests for integration.

### Skipping the stub

You write the test, then immediately write the full implementation. You never saw it fail. How do you know the test works?

### Giant test lists

Don't write 50 tests before implementing anything. Write one test, stub, fail, implement, pass. Then the next.

---

## Quick Reference

```
1. Write test
2. Write signature + stub (return constant)
3. Compile
4. Run test → fails on ASSERTION (not infrastructure)
5. Implement
6. Run test → passes
7. Refactor
8. Repeat
```

The test must fail because your logic is wrong, not because your code doesn't exist.
