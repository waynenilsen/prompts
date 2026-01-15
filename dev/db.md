# Database Schema and Migrations

Guidelines for managing Prisma schema changes and migrations in a multi-file schema setup.

---

## Philosophy

> "Schema changes without migrations are like promises without commitments."
> — Database Engineering Best Practices

Database schema changes are irreversible operations that affect the entire application. Migrations ensure these changes are versioned, reproducible, and safe to deploy.

---

## Critical Rule: Schema and Migration Must Be Atomic

**NEVER modify the schema without creating the corresponding migration in the same commit.**

### Why This Matters

- **Schema drift:** If schema changes are committed without migrations, the database can drift from the schema definition
- **Team conflicts:** Other developers' databases become out of sync
- **Deployment failures:** Production deployments fail when migrations are missing
- **Rollback issues:** Without migrations, you can't safely roll back schema changes
- **CI/CD failures:** Automated tests fail when schema doesn't match database state

### The Rule

**Every commit that modifies `prisma/*.prisma` files MUST include the corresponding migration file in `prisma/migrations/`.**

---

## Multi-File Schema Structure

We use **multi-file Prisma schemas** — one file per domain:

```
prisma/
├── schema.prisma       # Generator + datasource only
├── user.prisma         # User model
├── post.prisma         # Post model
└── migrations/
    ├── 20240101000000_init/
    │   └── migration.sql
    └── 20240102000000_add_posts/
        └── migration.sql
```

**Requires** `prisma.schema` config in `package.json`:

```json
{
  "prisma": {
    "schema": "./prisma"
  }
}
```

---

## The Workflow

### Step 1: Modify Schema Files

Edit the appropriate `.prisma` file(s):

```prisma
// prisma/user.prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### Step 2: Create Migration Immediately

**Do not commit schema changes without a migration.**

```bash
# Create migration from schema changes
bunx prisma migrate dev --name add_user_table

# This will:
# 1. Detect schema changes
# 2. Generate migration SQL
# 3. Apply migration to dev database
# 4. Create migration file in prisma/migrations/
```

### Step 3: Verify Migration

Check that the migration file was created:

```bash
ls -la prisma/migrations/
```

You should see a new directory with a `migration.sql` file.

### Step 4: Commit Together

**Both schema changes AND migration must be in the same commit:**

```bash
git add prisma/user.prisma
git add prisma/migrations/20240101000000_add_user_table/
git commit -m "feat(db): add user table schema and migration"
```

**Never:**

- Commit schema changes without migration
- Commit migration without schema changes
- Split schema and migration across multiple commits

---

## Ticket Breakdown: Schema and Migration Separation

When breaking down tickets from an ERD, **separate out the creation of the database schema AND migration** as a distinct ticket.

### The Schema Ticket Pattern

**There must be exactly ONE ticket that demands changes to schema files.**

This ticket should:

1. **Create the schema files** (`prisma/*.prisma`)
2. **Create the migration** (`prisma/migrations/*/migration.sql`)
3. **Verify the migration runs** (`bunx prisma migrate dev`)
4. **Commit both together** (schema + migration in same commit)

### Example Ticket

```markdown
## Context

ERD: ERD-0001
Depends on: None (foundation)

## Requirements

- REQ-001: User table with id, email, name, created_at, updated_at
- REQ-002: Unique constraint on email

## Acceptance Criteria

- [ ] `prisma/user.prisma` defines User model matching ERD specification
- [ ] Migration created (`bunx prisma migrate dev --name add_user_table`)
- [ ] Migration file exists in `prisma/migrations/`
- [ ] Migration runs successfully (`bunx prisma migrate dev`)
- [ ] Schema and migration committed together in same commit
- [ ] No other tickets modify schema files

## Technical Notes

- Uses SQLite with Prisma
- Multi-file schema structure (see [Database Guide](./db.md))
- Schema changes MUST include migration in same commit
```

### Why Separate This Ticket

- **Clear dependency:** Other tickets depend on schema existing
- **Single source of truth:** Only one ticket touches schema files
- **Atomic changes:** Schema + migration stay together
- **Easier review:** Schema changes are isolated and reviewable

---

## Common Patterns

### Adding a New Model

```bash
# 1. Create schema file
# prisma/post.prisma
model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
}

# 2. Create migration
bunx prisma migrate dev --name add_post_table

# 3. Commit together
git add prisma/post.prisma prisma/migrations/
git commit -m "feat(db): add post table schema and migration"
```

### Modifying an Existing Model

```bash
# 1. Edit schema file
# prisma/user.prisma - add new field
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  bio       String?  # NEW FIELD
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

# 2. Create migration
bunx prisma migrate dev --name add_user_bio

# 3. Commit together
git add prisma/user.prisma prisma/migrations/
git commit -m "feat(db): add bio field to user schema and migration"
```

### Adding Relations

```bash
# 1. Edit both schema files
# prisma/user.prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  posts     Post[]   # NEW RELATION
  createdAt DateTime @default(now())
}

# prisma/post.prisma
model Post {
  id        String   @id @default(cuid())
  title     String
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String   # NEW FIELD
  createdAt DateTime @default(now())
}

# 2. Create migration
bunx prisma migrate dev --name add_user_post_relation

# 3. Commit together
git add prisma/user.prisma prisma/post.prisma prisma/migrations/
git commit -m "feat(db): add user-post relation schema and migration"
```

---

## Verification Checklist

Before committing schema changes:

- [ ] Schema file(s) modified (`prisma/*.prisma`)
- [ ] Migration created (`bunx prisma migrate dev --name <name>`)
- [ ] Migration file exists (`prisma/migrations/<timestamp>_<name>/migration.sql`)
- [ ] Migration runs successfully (`bunx prisma migrate dev`)
- [ ] Both schema and migration staged together (`git add prisma/`)
- [ ] Commit message mentions both schema and migration

---

## Anti-Patterns

### ❌ Schema Without Migration

```bash
# WRONG: Committing schema without migration
git add prisma/user.prisma
git commit -m "feat(db): add user table"
# Missing: prisma/migrations/
```

**Problem:** Database state doesn't match schema. Other developers' databases break.

### ❌ Migration Without Schema

```bash
# WRONG: Committing migration without schema changes
git add prisma/migrations/20240101000000_add_user_table/
git commit -m "feat(db): add user migration"
# Missing: prisma/user.prisma changes
```

**Problem:** Migration references schema that doesn't exist. Prisma validation fails.

### ❌ Split Across Commits

```bash
# WRONG: Schema and migration in separate commits
git add prisma/user.prisma
git commit -m "feat(db): add user schema"

git add prisma/migrations/
git commit -m "feat(db): add user migration"
```

**Problem:** Intermediate state breaks the build. Other developers can't sync.

### ❌ Multiple Tickets Modifying Schema

```bash
# WRONG: Multiple tickets touching schema files
# Ticket 1: Add user table
# Ticket 2: Add user bio field  # Also modifies prisma/user.prisma
```

**Problem:** Merge conflicts, unclear ownership, schema drift.

**Solution:** Only ONE ticket modifies schema. Other tickets depend on it.

---

## Migration Naming Convention

Use descriptive names that explain what changed:

```bash
# Good
bunx prisma migrate dev --name add_user_table
bunx prisma migrate dev --name add_user_bio_field
bunx prisma migrate dev --name add_user_post_relation

# Bad (too vague)
bunx prisma migrate dev --name update_schema
bunx prisma migrate dev --name changes
bunx prisma migrate dev --name migration_1
```

---

## Production Deployment

When deploying to production:

```bash
# Production uses migrate deploy (doesn't modify schema)
bunx prisma migrate deploy

# This applies all pending migrations without modifying schema files
```

**Never run `prisma migrate dev` in production.** It's for development only.

---

## Related

- [Project Setup](./setup.md) - Multi-file schema configuration
- [Create Tickets from ERD](./create-tickets-from-erd.md) - Breaking down ERDs into tickets
- [Implement Ticket](./implement-ticket.md) - Process for completing tickets
- [Pre-Push Cleanup](./cleanup.md) - Self-review checklist
- [Engineering Requirements Document](./erd.md) - ERD data model sections

---

## Quick Reference

```bash
# Create migration from schema changes
bunx prisma migrate dev --name <descriptive_name>

# Verify migration exists
ls -la prisma/migrations/

# Apply migrations (production)
bunx prisma migrate deploy

# Reset database (dev only - destroys data)
bunx prisma migrate reset

# Check migration status
bunx prisma migrate status
```

**Remember:** Schema changes and migrations are atomic. They must be committed together.
