import {
  Client,
  Provider,
  ProviderRegistry,
  Result,
} from "@blockstack/clarity";
import { assert } from "chai";

describe("dao contract test suite", () => {
  let daoClient: Client;
  let tokenClient: Client;
  let tokenTraitClient: Client;
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    daoClient = new Client(
      "S1G2081040G2081040G2081040G208105NK8PE5.dao",
      "dao",
      provider
    );
    tokenClient = new Client(
      "S1G2081040G2081040G2081040G208105NK8PE5.dao-token",
      "dao-token",
      provider
    );
    tokenTraitClient = new Client(
      "S1G2081040G2081040G2081040G208105NK8PE5.dao-token-trait",
      "dao-token-trait",
      provider
    );
  });

  it("should have a valid syntax", async () => {
    await tokenTraitClient.deployContract();
    await tokenClient.deployContract();
    await daoClient.checkContract();
  });

  describe("deploying an instance of the trait and token contract", () => {
    it("should run", async () => {
      await provider.eval(
        "S1G2081040G2081040G2081040G208105NK8PE5.dao-token",
        "(* 2 3)"
      );
    });
  });

  after(async () => {
    await provider.close();
  });
});
