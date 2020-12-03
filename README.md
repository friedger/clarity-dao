# DAO in Clarity

![team](images/team.jpg)

## Moloch DAO

A conversion of [Moloch DAO 2.1 in Solidity](https://github.com/HausDAO/Molochv2.1/blob/6840897f8766d4c5cc6cfd7a4b8a8f98cb9644b5/Flat_Moloch_v2.1.sol) into Clarity

Moloch DAO is a grant-making internet community contract that can hold multiple tokens, make investments, give grants, trade tokens. Members of the dao can vote for proposal. A proposal passes with a simple majority. However, members that did not vote yes can quit the community and take their fair shares. This incentivices proposals that all member can live with. It has a small set of features to make it understandable and less error prone. It been described in various places and forms:

- [(First github repository](https://github.com/austintgriffith/moloch)
- [Audio](https://epicenter.tv/episodes/297/)
- [FAQ](https://daohaus.club/help#xDAI)
- [Primer for humans](https://medium.com/raid-guild/moloch-evolved-v2-primer-25c9cdeab455)

The Solidity version has been deployed to the Ethereum chain and xDai chain and is accessible via https://daohaus.club

### Implementation in Clarity

The Clarity code is very close to the origin Solidity code, the same variables and functions names have been used.

The main functions are

1. `submit-proposal*` and `cancel-proposal`
1. `sponsor-proposal`
1. `submit-vote`
1. `process-proposal*`
1. `ragequit` and `ragequit`

Other functions are available to manage tokens.

The contract supports any token that implements a basic fungible token trait.

#### Testing

The contract can be deployed to the mocknet or testnet. In `test/integration.ts` the relevant functions are defined such that you can run `yarn mocha test/integration.ts` to deploy and execute the contract.

#### Remarks

- The contract maintains an internal balance of tokens for all members in addition to the balance of total tokens, an escrow and the dao bank. These are prepresented by contract principals as contracts can never be a transaction sender. In solidity special, well-known addresses were used.
- Currently, the contract uses many checks that result in aborting the transaction (`panic`). This does not provide information to the user of the contract. This can be improved by changing to early return (`asserts!`) with the required additional error handling.
- Withdrawing a set of tokens in one transaction was not implemented due to handling traits in tuples (needs more investigation).
- The contract contains some reusable functions for handling a list of flags (that here represent that possible states of a proposal).
- The current tooling makes development and testing difficult.
  - Currently, the Clarity RPL does not support `contract-of` and `string-utf8`. Therefore, typos, syntax errors and type errors could not be detected in Visual Studio code, but only after deploying on mocknet.
  - Currently, the Clartiy SDK does not support `contract-of`. Therefore, no unit tests were written.
- The contract is structured through comments in between different sections:
  - Data storage
  - Public functions
  - Functions that do not change the state with subsections for different areas
  - Functions that change the state also with subsections for different areas  
Currently, there is no other support for long contracts. It might be possible to split the contract into several contracts (needs more investigation).
- There are few long functions that update one or more values of a map. [Type aliases](https://github.com/clarity-lang/reference/issues/6) and [merge function](https://github.com/blockstack/stacks-blockchain/pull/2117) would have been helpful here.

The contract has **NOT** been tested thoroughly. Use with care!
