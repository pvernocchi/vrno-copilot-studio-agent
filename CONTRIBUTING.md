# Contributing to vrno.cc Link Assistant

This repository contains a Microsoft Copilot Studio agent for managing vrno.cc short links, the custom connector definition, and Power Platform packaging scripts. It does not host the vrno.cc API. If you report a bug, say whether it occurs during packaging, solution import, connector setup, or a conversation with the agent. Include steps to reproduce it and the expected and actual behavior, with credentials and private link data removed.

## Where to make changes

| Change | Files |
| --- | --- |
| Agent behavior in English and Spanish | [`agent/instructions.md`](agent/instructions.md), which the build embeds in the base agent |
| Tool setup or connection guidance | [`agent/tool-setup.md`](agent/tool-setup.md) and the deployment steps in [`README.md`](README.md) |
| API operations, inputs, or authentication | [`connector/vrno-cc/`](connector/vrno-cc/), which contains the Swagger 2.0 definition and connection metadata |
| Packaging or validation | [`scripts/`](scripts/) and the [base-agent build workflow](.github/workflows/build-agent-solution.yml) |

Keep the connector definition, tool setup, and agent instructions aligned. `GetLink` looks up a short code, while `DeleteLink` takes the numeric ID from the API response. Deletion requires confirmation both in the conversation and in the Copilot Studio tool configuration. The agent should respond in the user's language and report success only after a tool confirms it.

## Validate your change

**Connector changes:** From the repository root, run:

```sh
node scripts/Validate-Connector.mjs
```

This checks the connector definition and authentication metadata without a token or live API access.

**Agent instructions or build changes:** On Windows with the [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction), run from the repository root:

```powershell
.\scripts\Build-AgentSolution.ps1 -Initialize
```

This writes the unmanaged base solution to `artifacts/vrno_ccAgent.zip`. Initialization needs an empty workspace, so pass `-WorkspacePath` with a fresh path if the default `build/agent-workspace` already contains files. The build does not require sign-in. The GitHub Actions workflow checks that the ZIP unpacks with the expected agent and topic components; it does not test solution import or live connector calls.

**Tool behavior changes:** Follow the [deployment steps](README.md#deploy-to-power-platform) in a test Power Platform environment with Dataverse and Copilot Studio access. The base ZIP does not include the connector, tool bindings, a connection reference, or credentials. Create the connector and connection in that environment and attach the tools before testing. Use a token with `read` scope for `ListLinks` and `GetLink`, and `write` scope for `CreateLink` and `DeleteLink`. Enter the complete `Bearer <your-token>` value only in the secure Power Platform connection field, never in chat, commits, or pull requests.

Exercise the affected operation in **Test your agent**. For conversation changes, try equivalent prompts in English and Spanish. To test deletion, use a disposable link and verify that declining leaves it intact and that confirming deletes only the intended link.

## Open a pull request

Check for an existing issue, then make your change on a branch from `main`. Keep the pull request focused and commit source files rather than generated ZIPs, build workspaces, or environment exports. Update the README or tool setup guide if the deployment process or user-facing behavior changes.

Describe what changed, why, and which checks you ran. If you did not have access to a Power Platform test environment, note which import or live behavior still needs verification.
