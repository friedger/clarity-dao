import { describe } from "mocha";
import {
  bufferCVFromString,
  callReadOnlyFunction,
  contractPrincipalCV,
  cvToHex,
  falseCV,
  listCV,
  makeContractCall,
  PostConditionMode,
  someCV,
  standardPrincipalCV,
  trueCV,
  uintCV,
} from "@stacks/transactions";
import {
  contractAddress,
  deployContract,
  handleTransaction,
  network,
  secretKey,
} from "./utils";
import { testnetKeyMap, ADDR2, ADDR3 } from "./mocknet";

const daoTokenContractName = "dao-token";
const contractName = "dao";

describe("dao proposal suite", () => {
  before("deploys", async () => {
    await deployContract("dao-token-trait");
    await deployContract(daoTokenContractName);
    await deployContract(contractName);
  });

  it("should get some dao tokens from faucet", async () => {
    const tx = await makeContractCall({
      contractAddress,
      contractName: daoTokenContractName,
      functionName: "faucet",
      functionArgs: [],
      senderKey: secretKey,
      network,
    });
    await handleTransaction(tx);
  });
  describe("submit proposal", () => {
    it("should submit a proposal", async () => {
      const tx = await makeContractCall({
        contractAddress,
        contractName,
        functionName: "submit-proposal",
        functionArgs: [
          standardPrincipalCV(contractAddress),
          uintCV(10),
          uintCV(10),
          uintCV(1000),
          contractPrincipalCV(contractAddress, "dao-token"),
          uintCV(0),
          contractPrincipalCV(contractAddress, "dao-token"),
          bufferCVFromString("just do it"),
        ],
        postConditionMode: PostConditionMode.Allow,
        senderKey: secretKey,
        network,
      });
      let result = await handleTransaction(tx);
      console.log(result);

      const proposal = await callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: "get-proposal-by-id?",
        functionArgs: [uintCV(1)],
        senderAddress: contractAddress,
        network,
      });
      console.log(JSON.stringify(proposal));
    });
  });
  describe("sponsor proposal", () => {
    it("should sponsor a proposal", async () => {
      const tx = await makeContractCall({
        contractAddress,
        contractName,
        functionName: "sponsor-proposal",
        functionArgs: [uintCV(1)],
        postConditionMode: PostConditionMode.Allow,
        senderKey: secretKey,
        network,
      });
      let result = await handleTransaction(tx);
      console.log(result);
      const url = network.getReadOnlyFunctionCallApiUrl(
        contractAddress,
        contractName,
        "get-proposal-by-id?"
      );
      const r = await fetch(url, {
        method: "post",
        headers: { "content-type": "application/json" },
        body: `{ "sender": "${contractAddress}", "arguments": ["${cvToHex(
          uintCV("1")
        )}"] } `,
      });
      console.log(await r.json());
      const proposal = await callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: "get-proposal-by-id?",
        functionArgs: [uintCV(1)],
        senderAddress: contractAddress,
        network,
      });
      console.log(JSON.stringify(proposal));
    });
  });

  describe("submit votes", () => {
    it("should submit votes", async () => {
      const tx1 = await makeContractCall({
        contractAddress,
        contractName,
        functionName: "submit-vote",
        functionArgs: [uintCV(1), someCV(trueCV())],
        postConditionMode: PostConditionMode.Allow,
        senderKey: secretKey,
        network,
      });
      const tx2 = await makeContractCall({
        contractAddress,
        contractName,
        functionName: "submit-vote",
        functionArgs: [uintCV(1), someCV(trueCV())],
        postConditionMode: PostConditionMode.Allow,
        senderKey: testnetKeyMap[ADDR2].secretKey,
        network,
      });
      const tx3 = await makeContractCall({
        contractAddress,
        contractName,
        functionName: "submit-vote",
        functionArgs: [uintCV(1), someCV(falseCV())],
        postConditionMode: PostConditionMode.Allow,
        senderKey: testnetKeyMap[ADDR3].secretKey,
        network,
      });
      await Promise.all([
        handleTransaction(tx1),
        handleTransaction(tx2),
        handleTransaction(tx3),
      ]);

      const proposal = await callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: "get-proposal-by-id?",
        functionArgs: [uintCV(1)],
        senderAddress: contractAddress,
        network,
      });
      console.log(JSON.stringify(proposal));
    });
  });
  describe("process proposal", () => {
    it("should process proposal", async () => {
      const tx = await makeContractCall({
        contractAddress,
        contractName,
        functionName: "process-proposal",
        functionArgs: [uintCV(1)],
        postConditionMode: PostConditionMode.Allow,
        senderKey: secretKey,
        network,
      });
      let result = await handleTransaction(tx);

      const proposal = await callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: "get-proposal-by-id?",
        functionArgs: [uintCV(1)],
        senderAddress: contractAddress,
        network,
      });
      console.log(JSON.stringify(proposal));
    });
  });

  it("should ragequit user C", async () => {
    const tx = await makeContractCall({
      contractAddress,
      contractName,
      functionName: "ragequit",
      functionArgs: [
        listCV([contractPrincipalCV(contractAddress, daoTokenContractName)]),
        uintCV(1),
        uintCV(0),
      ],
      postConditionMode: PostConditionMode.Allow,
      senderKey: testnetKeyMap[ADDR3].secretKey,
      network,
    });
    try {
      await handleTransaction(tx);
    } catch (e) {
      // tx handling failure due to https://github.com/blockstack/stacks.js/issues/872
      console.log(e);
    }

    const balance = await callReadOnlyFunction({
      contractAddress,
      contractName: daoTokenContractName,
      functionName: "get-balance",
      functionArgs: [],
      senderAddress: testnetKeyMap[ADDR3].address,
      network,
    });
    console.log(JSON.stringify(balance));
  });

  it("should withdraw balance for user C", async () => {
    const tx = await makeContractCall({
      contractAddress,
      contractName,
      functionName: "withdraw-balance",
      functionArgs: [
        listCV([contractPrincipalCV(contractAddress, daoTokenContractName)]),
        uintCV(100),
      ],
      postConditionMode: PostConditionMode.Allow,
      senderKey: testnetKeyMap[ADDR3].secretKey,
      network,
    });
    try {
      await handleTransaction(tx);
    } catch (e) {
      // tx handling failure due to https://github.com/blockstack/stacks.js/issues/872
      console.log(e);
    }

    const balance = await callReadOnlyFunction({
      contractAddress,
      contractName: daoTokenContractName,
      functionName: "get-balance",
      functionArgs: [],
      senderAddress: testnetKeyMap[ADDR3].address,
      network,
    });
    console.log(JSON.stringify(balance));
  });
});
