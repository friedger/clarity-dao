import {
  Client,
  Provider,
  ProviderRegistry,
  Result,
} from "@blockstack/clarity";
import { assert } from "chai";

describe("dao token contract test suite", () => {
  let daoTokenClient: Client;
  let daoTokenTraitClient: Client;
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    daoTokenTraitClient = new Client(
      "S1G2081040G2081040G2081040G208105NK8PE5.dao-token-trait",
      "dao-token-trait",
      provider
    );
    daoTokenClient = new Client(
      "S1G2081040G2081040G2081040G208105NK8PE5.dao-token",
      "dao-token",
      provider
    );
  });

  it("should have a valid syntax", async () => {
    await daoTokenTraitClient.deployContract();
    await daoTokenClient.checkContract();
  });

  describe("deploying an instance of the contract", () => {
    before(async () => {
      await daoTokenClient.deployContract();
    });
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
