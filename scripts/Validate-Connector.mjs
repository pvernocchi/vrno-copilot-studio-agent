import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const connectorDirectory = path.resolve(scriptDirectory, "../connector/vrno-cc");
const definition = JSON.parse(
  await readFile(path.join(connectorDirectory, "apiDefinition.swagger.json"), "utf8"),
);
const properties = JSON.parse(
  await readFile(path.join(connectorDirectory, "apiProperties.json"), "utf8"),
);

function resolveReference(reference) {
  assert.ok(reference.startsWith("#/"), `Expected a local reference: ${reference}`);
  const resolved = reference
    .slice(2)
    .split("/")
    .map((part) => part.replaceAll("~1", "/").replaceAll("~0", "~"))
    .reduce((current, part) => current?.[part], definition);
  assert.notEqual(resolved, undefined, `Unresolved reference: ${reference}`);
}

function validateReferences(value) {
  if (Array.isArray(value)) {
    value.forEach(validateReferences);
    return;
  }
  if (value && typeof value === "object") {
    if (typeof value.$ref === "string") {
      resolveReference(value.$ref);
    }
    Object.values(value).forEach(validateReferences);
  }
}

assert.equal(definition.swagger, "2.0");
assert.equal(definition.host, "vrno.cc");
assert.equal(definition.basePath, "/api/v1");
validateReferences(definition);
const pathShapes = Object.keys(definition.paths).map((apiPath) =>
  apiPath.replace(/\{[^}]+\}/g, "{}"),
);
assert.equal(new Set(pathShapes).size, pathShapes.length, "Duplicate templated paths are invalid.");
assert.deepEqual(definition.security, [{ bearerToken: [] }]);
assert.deepEqual(definition.securityDefinitions.bearerToken, {
  type: "apiKey",
  in: "header",
  name: "Authorization",
});
assert.equal(properties.properties.connectionParameters.bearerToken.type, "securestring");

const operations = Object.values(definition.paths).flatMap((pathDefinition) =>
  Object.entries(pathDefinition)
    .filter(([method]) => ["get", "post", "delete"].includes(method))
    .map(([, operation]) => operation),
);
assert.deepEqual(
  operations.map((operation) => operation.operationId).sort(),
  ["CreateLink", "DeleteLink", "GetLink", "ListLinks"].sort(),
);
assert.equal(new Set(operations.map((operation) => operation.operationId)).size, operations.length);
assert.equal(definition.paths["/links/{linkIdentifier}"].delete.parameters[0].name, "linkIdentifier");
assert.equal(definition.paths["/links/{linkIdentifier}"].get.parameters[0].name, "linkIdentifier");
assert.equal(
  definition.paths["/links/{linkIdentifier}"].delete.parameters[0]["x-ms-summary"],
  "Numeric link ID",
);
assert.equal(
  definition.paths["/links/{linkIdentifier}"].get.parameters[0]["x-ms-summary"],
  "Short code",
);
assert.match(
  definition.definitions.LinkCreateRequest.properties.expires_at.pattern,
  /^\^.*\$$/,
);

console.log("Connector OpenAPI and authentication metadata are structurally valid.");
