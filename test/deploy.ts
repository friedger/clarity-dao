import { describe } from "mocha";
import { deployContract } from "./utils";

const contractName = "dao";

describe("dao deploys suite", () => {
  it("deploys", async () => {
    await deployContract("dao-token-trait");
    await deployContract("dao-token");
    await deployContract(contractName);
  });
});
