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
    await daoClient.deployContract();
  });

  describe("membership proposal", () => {
    it("should submit proposal", async () => {
      const result = await provider.eval(
        "dao",
        `(submit-proposal 'SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB u1 u0 u100 'SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.dao-token u0 'SP3GWX3NE58KXHESRYE4DYQ1S31PQJTCRXB3PE9SB.dao-token)`
      );
      console.log(result);
    });
  });

  after(async () => {
    await provider.close();
  });
});
