# Add the connector actions in Copilot Studio

The local agent scaffold contains its instructions. Connector tools must be attached to the agent in a Power Platform environment after the connector is imported:

1. Open the agent in Copilot Studio and choose **Tools** > **Add a tool** > **Connector**.
2. Select the `vrno.cc URL Shortener` custom connector and add these actions: `ListLinks`, `CreateLink`, `GetLink`, and `DeleteLink`.
3. Create or select a connection. Enter the complete header value (`Bearer <your-token>`) in the connector's **Bearer token** field; the token is stored as a secure connection value, not in the agent instructions.
4. Configure `DeleteLink` to require confirmation before it runs. The agent instructions also require a confirmation turn before deletion.
5. Save the agent and export the updated agent solution as an unmanaged solution. Use that export as the agent ZIP when building the outer bundle.

The connection token needs `read` scope for listing and looking up links, and `write` scope for creating and deleting them.
