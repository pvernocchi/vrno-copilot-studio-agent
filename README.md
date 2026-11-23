# 🔗 vrno.cc Link Assistant

**Manage your [vrno.cc](https://vrno.cc) short links from Microsoft Copilot Studio.** Create, list, look up, and delete links in English or Spanish without leaving the conversation.

[![Copilot Studio](https://img.shields.io/badge/Microsoft-Copilot%20Studio-5B5FC7)](https://www.microsoft.com/microsoft-copilot/microsoft-copilot-studio)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue)](LICENSE)

[**Deploy**](#deploy-to-power-platform) · [**Try it**](#try-the-agent) · [**Explore the repo**](#whats-in-the-repo) · [**Move to another environment**](#move-to-another-environment)

> [!IMPORTANT]
> The **unmanaged base-agent ZIP** contains the agent, its instructions, and standard topics. It does **not** include the custom connector, tool bindings, a connection reference, or credentials. Set those up in your Power Platform environment before the agent can call vrno.cc. This repo does not host the URL shortener API.

## What the agent can do

| | Capability | Copilot Studio tool | Token scope |
| :---: | --- | --- | --- |
| 📋 | List your short links, 20 per page | `ListLinks` | `read` |
| ✨ | Create a short link with an optional custom code, title, redirect type, or expiry | `CreateLink` | `write` |
| 🔎 | Look up a link by its short code | `GetLink` | `read` |
| 🗑️ | Delete a link by numeric ID, only after confirmation | `DeleteLink` | `write` |

## Deploy to Power Platform

**Before you start:** Use a Power Platform environment with Dataverse and Copilot Studio access. You'll need permission to import solutions, create custom connectors and connections, and edit and publish the agent. Have a vrno.cc API token with the scopes for the operations you plan to enable.

### 1. Get the base-agent ZIP

| Path | What to do |
| --- | --- |
| ☁️ **GitHub Actions** | Open [Build base agent solution](https://github.com/pvernocchi/vrno-copilot-studio-agent/actions/workflows/build-agent-solution.yml), select a successful run, and download **vrno-cc-agent-base** under **Artifacts**. Unzip the artifact to get `vrno_ccAgent.zip`. Artifacts expire after 30 days. If none is available, use **Run workflow** if you have permission, or build locally. |
| 💻 **Local build** | Run the PowerShell command below from the repo root on Windows. It writes `artifacts/vrno_ccAgent.zip`. |

<details>
<summary><strong>Local build commands</strong></summary>

Install the official [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) (`pac`). CI uses version **2.16.1**. The build does not need Dataverse sign-in, an API token, or live vrno.cc access.

```powershell
.\scripts\Build-AgentSolution.ps1 -Initialize
```

Initialization requires an empty workspace (default: `build/agent-workspace`). If one already exists, pass `-WorkspacePath` with a new path. Use `-PacPath` if the PAC executable isn't on `PATH`.

</details>

### 2. Create the connector and connection

1. In [Power Apps](https://make.powerapps.com/), select the target environment. Under **Custom connectors**, create a connector by importing [`apiDefinition.swagger.json`](connector/vrno-cc/apiDefinition.swagger.json).
2. On the connector's **Security** page, verify **API Key** authentication uses the `Authorization` header. Set the parameter label to **Bearer token**. [`apiProperties.json`](connector/vrno-cc/apiProperties.json) documents the intended secure field and help text.
3. Save the connector and create a connection. In **Bearer token**, enter the complete value `Bearer <your-token>`, including the prefix and space.

> [!CAUTION]
> Enter the token only in the secure Power Platform connection field. Never paste it into Copilot chat or commit it to the repository.

### 3. Import the agent and attach the tools

1. In the same environment, go to **Power Apps → Solutions → Import solution** and select `vrno_ccAgent.zip`. Import it as an unmanaged solution.
2. In [Copilot Studio](https://copilotstudio.microsoft.com/), open **vrno.cc Link Assistant**. Go to **Tools → Add a tool → Connector** and select **vrno.cc URL Shortener**.
3. Add `ListLinks`, `CreateLink`, `GetLink`, and `DeleteLink`. Select the connection you created when prompted. Configure `DeleteLink` to require confirmation before it runs, then save the agent. See the [tool setup checklist](agent/tool-setup.md).

### 4. Test and publish

Use Copilot Studio's **Test your agent** pane to check that the tools return results. Use a disposable link to verify that deletion asks for confirmation and does not run before you confirm. When the agent works in your environment, select **Publish** and configure the channel where you want to make it available.

## Try the agent

| Try saying… | What to expect |
| --- | --- |
| “Show me my short links.” | Lists the first page of links. |
| “Crea un enlace corto para `https://example.com`.” | Creates a link and replies in Spanish. |
| “Look up the link with short code `spring-sale`.” | Looks up the link by short code, not by numeric ID. |
| “Delete the `spring-sale` link.” | Identifies the link and asks for confirmation before deleting it. |

For expiry, use `YYYY-MM-DD HH:MM:SS`. The agent asks for clarification when the date, time, or timezone is ambiguous.

## What's in the repo

| Path | What's inside |
| --- | --- |
| [`agent/`](agent/) | Bilingual agent instructions and the connector tool setup checklist. |
| [`connector/vrno-cc/`](connector/vrno-cc/) | Swagger 2.0 API definition and secure connection metadata for the four vrno.cc operations. |
| [`scripts/Build-AgentSolution.ps1`](scripts/Build-AgentSolution.ps1) | Scaffolds and packages the base agent with Power Platform CLI. |
| [`scripts/New-SolutionBundle.ps1`](scripts/New-SolutionBundle.ps1) | Bundles two existing Power Platform solution exports for distribution. |
| [`scripts/Validate-Connector.mjs`](scripts/Validate-Connector.mjs) | Checks the connector source locally with Node.js. |
| [`.github/workflows/build-agent-solution.yml`](.github/workflows/build-agent-solution.yml) | Builds the ZIP, verifies with PAC that it unpacks with the expected agent and topics, and uploads the artifact. |

Run `node scripts/Validate-Connector.mjs` from the repo root to check the connector source. CI checks package structure; actual imports and connector calls must be tested in your environment.

## Move to another environment

For a repeat deployment, export the custom connector in its own solution and export the configured agent with its tools and connection reference from the source environment. In the target environment, **import the connector solution first**, create a new connection, then **import the agent solution** and bind its connection reference to that connection. Test and publish again in the target environment.

<details>
<summary><strong>Optional: bundle both exports for distribution</strong></summary>

```powershell
.\scripts\New-SolutionBundle.ps1 `
  -ConnectorSolutionPath .\exports\connector.zip `
  -AgentSolutionPath .\exports\connected-agent.zip
```

The script produces `artifacts/vrno-cc-copilot-solutions.zip`. **Extract it first** and follow `IMPORT_ORDER.txt`; only the two inner solution ZIPs can be imported into Power Platform.

The repository does not publish these exports. PAC can build the base agent offline, but creating the custom connector and binding its actions requires an authenticated environment. Packing a Swagger file cannot generate those solution components.

</details>

---

[GPL v3 license](LICENSE) · [Microsoft: Custom connectors in solutions](https://learn.microsoft.com/connectors/custom-connectors/customconnectorssolutions) · [Microsoft: PAC Copilot commands](https://learn.microsoft.com/power-platform/developer/cli/reference/copilot)
