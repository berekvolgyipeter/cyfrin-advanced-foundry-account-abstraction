# cyfrin-advanced-foundry-account-abstraction

This project is a section of the [Cyfrin Foundry Solidity Course](https://github.com/Cyfrin/foundry-full-course-cu?tab=readme-ov-file#advanced-foundry-section-6-foundry-account-abstraction).

- [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337)
- [EntryPoint contract](https://etherscan.deth.net/address/0x0000000071727de22e5e9d8baf0edac6f37da032)

## What is Account Abstraction?

Externally Owned Accounts (EOAs) are now smart contracts. That's all account abstraction is.

But what does that mean?

Right now, every single transaction in web3 stems from a single private key.

> account abstraction means that not only the execution of a transaction can be arbitrarily complex computation logic as specified by the EVM, but also the authorization logic.

- [Vitalik Buterin](https://ethereum-magicians.org/t/implementing-account-abstraction-as-part-of-eth1-x/4020)
- [EntryPoint Contract v0.6](https://etherscan.io/address/0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789)
- [EntryPoint Contract v0.7](https://etherscan.io/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032)
- [zkSync AA Transaction Flow](https://docs.zksync.io/build/developer-reference/account-abstraction.html#the-transaction-flow)

![alt text](images/AA-ethereum-transaction.png)

![alt text](images/AA-ethereum.png)

![alt text](images/ethereum-transaction.png)

![alt text](images/AA-zksync.png)

## What does this repo show?

1. A minimal EVM "Smart Wallet" using alt-mempool AA
   1. We even send a transactoin to the `EntryPoint.sol`
2. A minimal zkSync "Smart Wallet" using native AA
   1. [zkSync uses native AA, which is slightly different than ERC-4337](https://docs.zksync.io/build/developer-reference/account-abstraction.html#iaccount-interface)
   2. We *do* send our zkSync transaction to the alt-mempool

## What does this repo not show?

1. Sending your userop to the alt-mempool
   1. You can learn how to do this via the [alchemy docs](https://alchemy.com/?a=673c802981)

## Implementation details

### Ethereum

`MinimalAccount` is respinsible for the custom authorization and transaction cost payment logics of its related EOA.
In our case the owner of `MinimalAccount` has to sign the transaction and `MinimalAccount` pays for its cost.

#### Flow

We'd like to make a transaction. In the unit test example it is minting some amount of an ERC20 token to the `MinimalAccount`.

##### Offchain operations

1. We encode this minting function call.
2. We encode a function call to `MinimalAccount.execute` with the following args:
   1. destination is the ERC20 contract address
   2. value is 0
   3. function data is the encoded minting function call from step 1
3. A `PackedUserOperation` struct with a signature by the EOA is created from the above execute calldata and some other parameters.

##### Onchain operations

1. The `handleOps` function of the [EntryPoint contract](https://etherscan.deth.net/address/0x0000000071727de22e5e9d8baf0edac6f37da032) is called with the packed used operation.
It doesn't matter who calls this function as long as the signature is valid. The `handleOps` does the followings:
   1. Calls `MinimalAccount.validateUserOp`, which:
      1. Validates the signature *(can be any custom validtaion - in our case the signer has to be the owner of `MinimalAccount`)*
      2. Pays cost of performing user operation to the `EntryPoint` *(Note: a paymaster can be set up)*
   2. If the validation is successful, calls `MinimalAccount.execute` which executes the transaction.

### ZkSync

`ZkMinimalAccount` has the same responsibilities and authorization- and payment logics as the ethereum implementation.

ZkSync natively supports AA, so no `EntryPoint` contract and alt-mempool are needed. Instead we send type 113 transactions directly to the account contract.

#### Lifecycle of a type 113 (0x71) transaction

msg.sender is the bootloader system contract

##### Phase 1 Validation

1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
2. The zkSync API client checks to see if the nonce is unique by querying the NonceHolder system contract
3. The zkSync API client calls validateTransaction, which MUST update the nonce
4. The zkSync API client checks the nonce is updated
5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
6. The zkSync API client verifies that the bootloader gets paid

##### Phase 2 Execution

1. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
2. The main node calls executeTransaction
   1. If we make a transaction to a system contract, we have to handle it differently to be compatible with the ZkSync rollup.
   Our implementation only handles the deployer system contract call, but we culd write the handlig to all the system contracts.
3. If a paymaster was used, the postTransaction is called

## Pipelines

3 Github workflow pipelines are configured:

1. Slither check
2. ZkSync test using Foundry-ZKsync
3. Ethereum test using Foundry
