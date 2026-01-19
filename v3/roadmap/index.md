# Roadmap Documentation

Strategic planning and milestone-based product roadmaps.

## Contents

- [Roadmap Guide](./roadmap.md) - How to write roadmaps that provide strategic steering

## Key Constraint

**Roadmaps are strategic, not tactical.** They define WHAT features are needed in each phase, not HOW to build them. Implementation details belong in PRDs and ERDs.

**Context Management:** Roadmaps are only read when the backlog is empty and PRDs need to be created. They MUST NOT be loaded during ticket implementation to prevent context rot.

## Hierarchy

```
Roadmap (strategic phases)
  ↓ produces N
PRDs (product requirements)
  ↓ each produces 1
ERD (engineering requirements)
  ↓ each breaks down into M (where M > N)
Tickets (implementation tasks)
```

**One roadmap phase produces N PRDs.** Each PRD has one corresponding ERD (N PRDs → N ERDs). Each ERD breaks down into multiple tickets (M tickets, where M > N).

## Related

- [Product Requirements Document](../product/prd.md) - Feature-level requirements (produced by roadmap phases)
- [Engineering Requirements Document](../dev/erd.md) - Technical implementation (produced by PRDs)
- [Create Tickets from ERD](../dev/create-tickets-from-erd.md) - Break down ERDs into actionable tickets
