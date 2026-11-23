# vrno.cc Copilot Studio agent

This repository contains source for an optional Copilot Studio agent that can manage a user's `vrno.cc` short links. Administrators import and configure it in their own Power Platform environment; no environment, API key, or live `vrno.cc` access is used to build the included package.

## What is available

- `connector/vrno-cc/` contains the Swagger 2.0 definition and secure API-key connection metadata for the four link operations.
- `agent/` contains bilingual agent instructions and the manual tool-setup checklist.
- The GitHub Actions workflow builds an **unmanaged base-agent solution ZIP** as the `vrno-cc-agent-base` workflow artifact. Download it from the latest successful **Build base agent solution** run under **Actions**. The workflow artifact is retained for 30 days.

The base-agent ZIP contains the Copilot Studio agent and its standard topics. It does **not** contain the custom connector, connector actions, a connection reference, or a configured connection. It is not the final connected agent solution.

## Why there is no connector or connected-agent ZIP

Power Platform CLI 2.16.1 can scaffold and package the base agent offline. The custom connector definition in this repository is source, not a solution export: `pac connector init` only creates API-properties scaffolding, while `pac connector create` creates the connector record in Dataverse and requires an authenticated environment. Exporting/cloning the connector solution and adding its connection reference and actions to the agent likewise requires an environment. `pac solution pack` packages a complete solution source tree; it does not create those environment-owned component identities or bindings.

Accordingly, this repository does not publish a connector-solution ZIP, a connected-agent ZIP, or an outer bundle. The local base-agent ZIP is validated by unpacking it with PAC, but actual import and runtime behavior still need to be verified in the administrator's environment.

## Build the base-agent ZIP locally

Install the official [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction), then run:

```powershell
.\scripts\Build-AgentSolution.ps1 -Initialize
```

This creates `build/agent-workspace` and writes the base solution ZIP to `artifacts/`. If the workspace already exists, back it up or choose a different `-WorkspacePath`; initialization does not overwrite existing files. To use a PAC executable outside `PATH`, pass `-PacPath`.

The CI workflow downloads the official Power Platform CLI NuGet package using normal TLS certificate validation, builds the same base solution, and checks that PAC can unpack its agent and topics before uploading the ZIP artifact.

## Configure it in your environment

1. In Power Apps, create a custom connector from `connector/vrno-cc/apiDefinition.swagger.json`. Configure API-key authentication in the `Authorization` header and name the secure connection field **Bearer token**; `apiProperties.json` records its intended label and help text for connector tooling.
2. Create a connection with the complete value `Bearer <your-token>` in the secure field. Use a token with `read` scope for listing/lookups and `write` scope for creating/deleting links. Never paste the token into chat or commit it.
3. Import the `vrno-cc-agent-base` ZIP as an unmanaged solution.
4. In Copilot Studio, add the connector's `ListLinks`, `CreateLink`, `GetLink`, and `DeleteLink` operations as tools, bind the connection when prompted, and require confirmation for `DeleteLink`. See [`agent/tool-setup.md`](agent/tool-setup.md).
5. Save and export the configured agent from your environment if you need a solution ZIP containing the connector actions and connection references. Those components are intentionally not fabricated in this repository.

The agent answers in Spanish or English according to the user's language. Expiry values must be supplied as `YYYY-MM-DD HH:MM:SS`; ambiguous dates or times should be clarified rather than guessed.

## Validation

Run the local connector-source checks with Node.js:

```powershell
node .\scripts\Validate-Connector.mjs
```

The CI workflow also runs `pac solution unpack` against the generated base-agent ZIP. This verifies the package structure, not importability or connector execution in a real Power Platform environment.

Microsoft references: [custom connectors in solutions](https://learn.microsoft.com/connectors/custom-connectors/customconnectorssolutions), [`pac connector` commands](https://learn.microsoft.com/power-platform/developer/cli/reference/connector), [solution YAML source control format](https://learn.microsoft.com/power-platform/alm/solution-source-control-yaml-format), and [`pac copilot` CLI commands](https://learn.microsoft.com/power-platform/developer/cli/reference/copilot).
