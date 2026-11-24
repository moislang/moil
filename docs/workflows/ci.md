# Documentation and governance CI

The initial workflow checks that the planning structure exists and that local references in Markdown resolve. It does not compile Moislang and does not prove the architecture. Once code exists, add per-phase gates without turning checks that are not implemented yet into empty successes.

## Triggers

- Pull requests and pushes to `main` that change documentation, rules, skills, workflows or validation scripts.
- Manual runs through `workflow_dispatch`.

## Policy

- Do not publish artifacts or deploy.
- Do not access or modify the neighboring checkout.
- Do not install network dependencies to validate Markdown.
- A compiler check enters only once there is a reproducible, versioned way to run it.
