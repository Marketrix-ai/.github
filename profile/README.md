# Marketrix

**Software that supports itself.**

Marketrix is an AI-powered customer support platform where autonomous agents learn your product by actually using it — not by reading docs. Our proprietary simulation engine explores your application's interface continuously, building a living understanding that stays current with every deployment.

## What We Build

**Simulation Engine** — Agents autonomously navigate your app, clicking buttons, filling forms, and mapping every state. The result is a semantic understanding of your product that adapts to UI changes without brittle selectors or manual configuration.

**Zero Tickets** — Pre-cognitive intervention that blocks invalid actions before they reach your database, preventing errors instead of responding to them.

**Instant Onboarding** — Adaptive, role-aware guides generated from real interface exploration. No manual tour authoring needed.

**Automated QA** — Self-healing regression tests that run by exploring your app like a real user. When buttons move or rename, the tests adapt automatically.

**Natural Growth** — Contextual feature discovery and upgrade suggestions triggered by real usage patterns.

## How Agents Help Users

| Mode | Description |
|------|-------------|
| **Tell** | Answer questions using knowledge base + interface understanding |
| **Show** | Demonstrate tasks step-by-step based on real exploration |
| **Do** | Perform actions on behalf of users |

## Architecture

Our platform is built as a set of independent services:

- **Dashboard** — Next.js app for managing applications, agents, simulations, and analytics
- **API** — Central service connecting all clients and the agent engine
- **Agent** — Python service powering LLM orchestration, browser automation, and knowledge graphs
- **Widget** — Embeddable chat widget customers deploy on their sites
- **Docs** — Customer-facing documentation at [docs.marketrix.ai](https://docs.marketrix.ai)

## Links

- [Website](https://marketrix.ai)
- [Documentation](https://docs.marketrix.ai)
