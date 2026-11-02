# UDM — University Discipleship Mission

UDM equips university students to know Christ, grow in faith, live out biblical truth, and make disciples.

## Project status

This repository is at the Phase 1 architecture and project setup stage. The architecture, domain model, delivery roadmap, and initial mobile design system are documented in [`docs/`](docs/). Feature work will proceed in the roadmap order; no production integrations or operational features are claimed yet.

## Product pillars

- **Know Christ:** Scripture, devotionals, prayer, biblical study, and memory.
- **Grow in Christ:** Courses, mentors, accountability, fellowship, and spiritual disciplines.
- **Make disciples:** Evangelism, missions, outreach, leadership, and disciple making.

## Planned stack

- Flutter / Dart mobile client using GetX, Dio, and offline-capable local persistence.
- Django REST Framework API with PostgreSQL and JWT authentication.
- Redis/Celery for background jobs; object storage for media; FCM for push delivery.
- Docker-based development and deployment, introduced with the backend bootstrap.

See [architecture](docs/architecture.md), [domain model](docs/domain-model.md), [roadmap](docs/roadmap.md), and [design system](docs/design-system.md).
