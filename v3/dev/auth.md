# Authentication

Guidelines for implementing authentication. Always roll your own auth.

---

## Core Principles

### Email/Password with Session-Based Management

All authentication uses email/password credentials with server-side session management.

- Sessions are stored server-side (database or Redis)
- Session tokens are issued to clients via secure cookies
- No JWTs for session management
- Always hash passwords with bcrypt or argon2

### Always Home-Roll Auth

Do not use third-party auth providers (Auth0, Clerk, Firebase Auth, etc.). Build authentication from scratch using the patterns below.

**Why:**
- Full control over the auth flow
- No vendor lock-in
- No external dependencies for critical infrastructure
- Predictable behavior and debugging

---

## Row Level Security is Forbidden

**Never use database-level Row Level Security (RLS).**

RLS causes:
- **Session pinning**: Each request must use the same database connection to maintain the RLS context, breaking connection pooling
- **Performance degradation at scale**: Session pinning means you can't efficiently distribute queries across a connection pool
- **Fragile security**: RLS policies are easy to misconfigure and hard to audit

**Instead:** Handle access control in application code. Query the data you need, filter based on user context, and return only what the user is authorized to see.

---

## Multi-Tenant Filtering

Tenant-based filtering is **only necessary for multi-tenant applications**.

### If Multi-Tenant (B2B SaaS with multiple organizations)

**Organization Schema Requirements:**

Organizations must have a `slug` field for URL routing:

```prisma
model Organization {
  id        String   @id @default(cuid())
  name      String
  slug      String   @unique  // Required for multi-tenant routing
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  members  UserOrganization[]
  // ... other relations
}
```

**User Schema:**

Users must have an optional `name` field:

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?  // Optional
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  sessions  Session[]
  // ... other relations
}
```

**Query Filtering:**

Add `tenant_id` or `organization_id` to relevant tables and filter all queries:

```typescript
// Always include tenant filter in queries
const users = await prisma.user.findMany({
  where: {
    organizationId: currentUser.organizationId,
    // ... other filters
  },
});
```

**Rules:**
- Every query on tenant-scoped data must include the tenant filter
- Validate tenant ownership at the service layer, not in the database
- Create helper functions to enforce consistent filtering
- Organizations must have a unique `slug` for URL routing

### If B2C (Single-tenant, consumer application)

Tenant filtering is not applicable. Users access their own data via user ID:

```typescript
const orders = await prisma.order.findMany({
  where: {
    userId: currentUser.id,
  },
});
```

No organization/tenant abstraction needed.

---

## Session Implementation

### Database Schema

```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT
);

CREATE INDEX sessions_user_id_idx ON sessions(user_id);
CREATE INDEX sessions_expires_at_idx ON sessions(expires_at);
```

### Session Lifecycle

1. **Login**: Create session, set secure cookie (uses POST-redirect-GET pattern - see [tRPC Guide](./trpc.md))
2. **Request**: Validate session from cookie, attach user to request context (via tRPC context)
3. **Logout**: Delete session from database, clear cookie (uses POST-redirect-GET pattern)
4. **Expiration**: Background job cleans up expired sessions

**Note:** Login/logout are the only endpoints that write cookies. They use POST-redirect-GET pattern (see [tRPC Guide](./trpc.md)). All other auth operations (checking session, getting current user, etc.) use tRPC.

### Cookie Settings

```typescript
const sessionCookie = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 7, // 7 days
  path: '/',
};
```

---

## Conditional Routing and Redirects

**All pages must respect authentication state.** Never show auth pages to logged-in users, and never show application pages to logged-out users.

### Home Page (`/`)

The home page must conditionally render based on auth state:

- **Logged out:** Show marketing/landing page
- **Logged in:** Show the application (dashboard, main app view, etc.)

**Do NOT put the application under a different route** (e.g., `/app` or `/dashboard`). The root path `/` is the application when authenticated.

### Multi-Tenant Routing

**If the application has organizations (multi-tenant):**

The application must be at `/organization-slug` so URLs are shareable. When users copy and paste URLs, they work correctly because the organization context is in the URL path.

**Why:** Users may belong to multiple organizations. URLs must include the organization slug so:
- Shared URLs work correctly (recipient sees the same organization context)
- Users can easily switch between organizations
- URLs are bookmarkable and shareable

**Example:** If a user belongs to "Acme Corp" (slug: `acme-corp`), the application is at `/acme-corp`, not `/`. The root `/` redirects to the user's default organization or shows an organization selector.

### Auth Pages (`/sign-in`, `/sign-up`)

Auth pages must redirect logged-in users to the home page (or their organization if multi-tenant).

**Same pattern for `/sign-up`** — redirect if already logged in.

### Navigation Components

Navigation must conditionally show/hide auth buttons based on auth state:

- Never show "Sign In" or "Sign Up" buttons when logged in
- Never show user menu or "Logout" when logged out
- Use tRPC `auth.getMe` query to check auth state in client components
- Use server-side session check in page components for redirects

---

## Role-Based Access Control (RBAC)

Implement RBAC in application code, not at the database level.

### Schema

```sql
CREATE TABLE roles (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,  -- 'admin', 'member', 'viewer'
  description TEXT
);

CREATE TABLE permissions (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,  -- 'users:read', 'users:write', 'billing:manage'
  description TEXT
);

CREATE TABLE role_permissions (
  role_id TEXT REFERENCES roles(id) ON DELETE CASCADE,
  permission_id TEXT REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  role_id TEXT REFERENCES roles(id) ON DELETE CASCADE,
  organization_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,  -- if multi-tenant
  PRIMARY KEY (user_id, role_id, organization_id)
);
```

### Permission Checks

Check permissions in application code at the service layer:

```typescript
// Load user permissions once per request (cache in request context)
async function getUserPermissions(userId: string, orgId?: string): Promise<Set<string>> {
  const roles = await prisma.userRole.findMany({
    where: { userId, organizationId: orgId },
    include: { role: { include: { permissions: true } } },
  });

  const permissions = new Set<string>();
  for (const ur of roles) {
    for (const rp of ur.role.permissions) {
      permissions.add(rp.permission.name);
    }
  }
  return permissions;
}

// Check before performing action
function requirePermission(permissions: Set<string>, required: string): void {
  if (!permissions.has(required)) {
    throw new ForbiddenError(`Missing permission: ${required}`);
  }
}

// Usage in service
async function deleteUser(ctx: RequestContext, targetUserId: string) {
  requirePermission(ctx.permissions, 'users:delete');
  await prisma.user.delete({ where: { id: targetUserId } });
}
```

### Permission Naming Convention

Use `resource:action` format:

- `users:read` - View users
- `users:write` - Create/update users
- `users:delete` - Delete users
- `billing:manage` - Manage billing settings
- `settings:admin` - Access admin settings

### Keep It Simple

- Start with a few roles: `admin`, `member`, `viewer`
- Add granular permissions only when needed
- Avoid deeply nested role hierarchies
- Cache permissions per request, not globally

---

## Ralph Service Mode (systemd)

When instructed to serviceize Ralph with systemd, the service must run with the same `bashrc` and in the project working directory. This is critical because Ralph relies on local tools (`gh`, `jq`, `claude`, `bun`, `node`) and repo-relative paths. systemd does not load your shell environment, and it does not set the working directory unless you tell it to.

### Footguns to avoid

- **No shell init**: systemd does not read `.bashrc`/`.zshrc`; PATH and tool shims will be missing.
- **Wrong working directory**: default is `/`; relative paths and `git` commands will fail.
- **No TTY**: interactive tools or prompts can hang or error.
- **Wrong HOME**: auth tokens (`gh`, `claude`) and config live under `$HOME`.
- **Missing environment**: `.env`, `.tool-versions`, asdf/volta, bun install paths, etc.
- **No SSH agent**: git/gh commands may fail if they require agent-based auth.

### Systemd unit (safe defaults)

Use absolute paths. Ensure the user and working directory match the repo.

```ini
# /etc/systemd/system/ralph.service
[Unit]
Description=Ralph prompt loop
After=network.target

[Service]
Type=simple
User=YOUR_USER
Group=YOUR_GROUP
WorkingDirectory=/absolute/path/to/repo

# Ensure HOME and PATH are correct for toolchains and auth
Environment=HOME=/home/YOUR_USER
Environment=PATH=/home/YOUR_USER/.bun/bin:/home/YOUR_USER/.local/bin:/usr/local/bin:/usr/bin:/bin

# Force bashrc to load and pin working directory
ExecStart=/bin/bash -lc 'source ~/.bashrc; cd /absolute/path/to/repo; ./loop.sh'
Restart=on-failure
RestartSec=3

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Enable

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ralph.service
sudo systemctl status ralph.service
```

**Rule:** If the service cannot run the exact same CLI toolchain as your interactive shell, do not serviceize it until that is fixed.

---

## Checklist

When implementing auth:

- [ ] Using email/password, not OAuth/social login
- [ ] Sessions stored server-side
- [ ] Passwords hashed with bcrypt or argon2
- [ ] No Row Level Security
- [ ] Multi-tenant filtering only if actually multi-tenant
- [ ] Secure cookie settings
- [ ] Session expiration and cleanup
- [ ] No third-party auth providers
- [ ] RBAC checks in application code, not database
- [ ] Permissions cached per request
- [ ] Home page (`/`) conditionally renders marketing vs application based on auth state
- [ ] Auth pages (`/sign-in`, `/sign-up`) redirect to `/` if already logged in
- [ ] Navigation conditionally shows/hides auth buttons based on auth state
- [ ] Application is at `/` when logged in (not under `/app` or `/dashboard`)
- [ ] If multi-tenant: Application is at `/organization-slug` for shareable URLs
- [ ] If multi-tenant: Organizations have a unique `slug` field
- [ ] User model includes optional `name` field

---

## Related

- [tRPC](./trpc.md) - API patterns (login/logout use POST-redirect-GET, everything else uses tRPC)
- [Implement Ticket](./implement-ticket.md) - Development workflow
- [Unit Testing](./unit-testing.md) - Testing auth flows
