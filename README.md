# PPFX Stargate Hooks

This repo contains hook contracts that interact with Stargate V2 contracts.

- `DepositHook` Allows users to deposit USDT from their origin chain, e.g. Ethereum L1 or Arbitrum L2, and then directly deposit to PPFX.
- `WithdrawHook` Allows users to withdraw and claim USDT from PPFX, and send to their destination chain directly.

The main benefit is to allow users to easily move funds to/from PPFX without managing gas on the L2 blockchain.

## Setup

PPFX is built with [Foundry](https://book.getfoundry.sh/). 

```shell
# build
$ forge build

# test
$ forge test

# lint/formatter
$ forge fmt

# gas snapshot
$ forge snapshot

```

## DepositHook

The DepositHook receives message from StargateV2 after USDT tokens are sent cross-chain. 
- StargateV2 calls `lzCompose`.
- The hook decomposes the message to get the user address and deposit amount.
- The hook calls PPFX contract to depost tokens on behalf of user

```
TODO: stargate calling example w/ SendParams
```

## WithdrawHook

The WithdrawHook claims USDT tokens from PPFX on behalf of users, and then sends them cross-chain on StargateV2. 
- User signs message and delegates `withdraw`, `claim` to an Operator to execute txn on their behalf.
- Withdraw Service claims USDT tokens, and then calls Stargate contract to send the tokens to user cross-chain.
- Optionally, a withdraw fee may be charged (which may be needed to cover gas)

```
TODO: stargate calling example
```






