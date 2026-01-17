# Product Documentation

Guides for product planning and requirements.

## Contents

- [Product Requirements Document](./prd.md) - How to write PRDs that get used

## Key Constraint

**No external services by default.** Projects must run immediately on checkout.

**Email is the exception:** Mailhog runs locally via Docker Compose, SendGrid is used in production (via `STAGE` env var).

If a PRD requires other external services (Auth0, Supabase, Stripe, etc.), it must be explicitly stated and justified.

## Related

- [Engineering Requirements Document](../dev/erd.md) - Technical counterpart to the PRD
- [Create Tickets from ERD](../dev/create-tickets-from-erd.md) - Break down ERDs into actionable tickets
- [Project Setup](../dev/setup.md) - The technical stack (Next.js, Prisma, SQLite, Sprite)
