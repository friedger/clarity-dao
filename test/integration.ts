import { describe } from "mocha";
import {
  broadcastTransaction,
  bufferCV,
  bufferCVFromString,
  contractPrincipalCV,
  makeContractCall,
  makeContractDeploy,
  standardPrincipalCV,
  TxBroadcastResultOk,
  TxBroadcastResultRejected,
  uintCV,
} from "@stacks/transactions";
import { StacksTestnet } from "@stacks/network";
import * as fs from "fs";

export const local = true;
export const mocknet = true;
export const noSidecar = true;

const STACKS_CORE_API_URL = local
  ? noSidecar
    ? "http://localhost:20443"
    : "http://localhost:3999"
  : "http://testnet-master.blockstack.org:20443";
export const STACKS_API_URL = local
  ? "http://localhost:3999"
  : "https://stacks-node-api.blockstack.org";
export const network = new StacksTestnet();
network.coreApiUrl = STACKS_CORE_API_URL;

const stxAddress = "ST2ZRX0K27GW0SP3GJCEMHD95TQGJMKB7G9Y0X1MH";
const senderKey =
  "b8d99fd45da58038d630d9855d3ca2466e8e0f89d3894c4724f0efc9ff4b51f001";

export async function deployContract(contractName: string) {
  const codeBody = fs
    .readFileSync(`./contracts/${contractName}.clar`)
    .toString();
  var transaction = await makeContractDeploy({
    contractName,
    codeBody: codeBody,
    senderKey,
    network,
  });
  console.log(`deploy contract ${contractName}`);
  const result = await broadcastTransaction(transaction, network);
  console.log(result);
  return result;
}

function timeout(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

describe("dao test suite", () => {
  before("deploys", async () => {
    let result = await deployContract("dao-token-trait");
    if (!((result as unknown) as TxBroadcastResultRejected).error) {
      await timeout(10000);
    }
    result = await deployContract("dao-token");
    if (!((result as unknown) as TxBroadcastResultRejected).error) {
      await timeout(10000);
    }
    result = await deployContract("dao");
    if (!((result as unknown) as TxBroadcastResultRejected).error) {
      await timeout(10000);
    }
  });

  it("should accept a proposal", async () => {
    const tx = await makeContractCall({
      contractAddress: stxAddress,
      contractName: "dao",
      functionName: "submit-proposal",
      functionArgs: [
        standardPrincipalCV(stxAddress),
        uintCV(10),
        uintCV(10),
        uintCV(0),
        contractPrincipalCV(stxAddress, "dao-token"),
        uintCV(0),
        contractPrincipalCV(stxAddress, "dao-token"),
        bufferCVFromString("just do it"),
      ],
      senderKey,
      network,
    });
    const result = await broadcastTransaction(tx, network);
    console.log(result);
  });
});
