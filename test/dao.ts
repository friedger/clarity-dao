import {
  Client,
  Provider,
  ProviderRegistry,
  Result,
} from "@blockstack/clarity";
import { assert } from "chai";

describe("dao contract test suite", () => {
  let daoClient: Client;
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    daoClient = new Client(
      "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.dao",
      "dao",
      provider
    );
  });

  it("should have a valid syntax", async () => {
    await daoClient.checkContract();
  });

  describe("deploying an instance of the contract", () => {
    before(async () => {
      await daoClient.deployContract();
    });
  });

  after(async () => {
    await provider.close();
  });
});
