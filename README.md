# vrno.cc Copilot Studio agent

Source and packaging scripts for a Copilot Studio agent that manages a user's short links through a `vrno.cc` custom connector.

The repo contains the connector's OpenAPI 2.0 definition and authentication metadata (`connector/vrno-cc/`), the agent instructions (`agent/instructions.md`), and the Copilot Studio setup checklist (`agent/tool-setup.md`). It does not contain a token, a Power Platform environment export, or a generated solution archive.

## What the agent can do

- List links, 20 per page.
- Create a short link with an optional code, title, 301/302 redirect, or expiry.
- Look up a link by its short code.
- Delete a link by numeric ID, only after confirmation.

It answers in Spanish or English according to the user's language. Expiry values must be supplied as `YYYY-MM-DD HH:MM:SS`; ambiguous dates or times should be clarified rather than guessed.

## Create and export the solutions

The final deliverable is an **outer ZIP bundle** containing two separate, importable Power Platform solution ZIPs. Import the connector solution first, then the agent solution; do not import the outer bundle itself.

1. In Power Apps, create an unmanaged solution for the connector. Add a **Custom connector** to that solution by importing `connector/vrno-cc/apiDefinition.swagger.json`. Confirm the security scheme uses API key authentication in the `Authorization` header, set the secure connection field's display name to **Bearer token**, save the connector, and export the solution as an unmanaged ZIP. The supplied `apiProperties.json` carries the matching field label and help text for connector tooling that consumes API properties.
2. Install the [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction). Create a clean workspace and scaffold/package the base agent:

   ```powershell
   .\scripts\Build-AgentSolution.ps1 -Initialize
   ```

   This writes the workspace under `build/agent-workspace` and the base solution under `artifacts/`. If that workspace already exists, back it up or choose a new `-WorkspacePath`; initialization does not overwrite existing files.
3. Import the connector solution ZIP into the target environment. Create a connector connection and enter the **complete** value `Bearer <your-token>` in the secure **Bearer token** field. Do not paste the token into chat or commit it to this repository. Use a token with `read` scope for listing/lookup and `write` scope for create/delete.
4. Import the base agent solution ZIP. In Copilot Studio, add the four connector operations (`ListLinks`, `CreateLink`, `GetLink`, and `DeleteLink`) to the agent as tools, bind the connection, and configure `DeleteLink` to require confirmation. See [`agent/tool-setup.md`](agent/tool-setup.md). Save and export the configured agent as an unmanaged solution ZIP; this export is the agent package for the final bundle.
5. Package both exported solution ZIPs:

   ```powershell
   .\scripts\New-SolutionBundle.ps1 `
     -ConnectorSolutionPath .\path\to\connector-solution.zip `
     -AgentSolutionPath .\path\to\configured-agent-solution.zip
   ```

   The output is `artifacts/vrno-cc-copilot-solutions.zip`, containing `solutions/01-vrno-cc-connector.zip`, `solutions/02-vrno-cc-agent.zip`, and `IMPORT_ORDER.txt`.

The custom connector has to be created and exported in a Power Platform environment before the outer bundle can be assembled. Its connection credentials are environment-specific and must be entered again when creating a connection in another environment. The bundle script refuses inputs that are not solution ZIPs containing a root `solution.xml`.

## Validation

Run the local connector structure checks with Node.js:

```powershell
node .\scripts\Validate-Connector.mjs
```

The agent solution script requires an installed, working `pac` CLI. `pac copilot pack` creates a local agent solution; it does not provision an environment, create the custom connector, bind a connection, or add connector tools to the agent. The configured agent must be saved and exported from Copilot Studio before it is included in the final bundle.

Microsoft references: [custom connectors in solutions](https://learn.microsoft.com/connectors/custom-connectors/customconnectorssolutions), [connectors as Copilot Studio tools](https://learn.microsoft.com/microsoft-copilot-studio/advanced-connectors), and [`pac copilot` CLI commands](https://learn.microsoft.com/power-platform/developer/cli/reference/copilot).
