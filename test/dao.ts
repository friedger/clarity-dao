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
  let provider: Provider;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    daoClient = new Client(
      "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.dao",
      "dao",
      provider
    );
    tokenClient = new Client(
      "SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.dao-token",
      "dao-token",
      provider
    );
  });

  it("should have a valid syntax", async () => {
    await daoClient.checkContract();
    await tokenClient.checkContract();
  });

  describe("deploying an instance of the contract", () => {
    before(async () => {
      await tokenClient.deployContract();
      await daoClient.deployContract();
    });
    it("should run", async () => {
      provider.eval("SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.dao", "(* 2 3)");
    });
  });

  after(async () => {
    await provider.close();
  });
});
