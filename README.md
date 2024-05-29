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
    // coonstruct message
    const composeMsg = abiCoder.encode(["uint256", "address"], [receiveAmount, fromAddress])
    const sendParam = {
        dstEid, // lz endpoint Id
        to, // Recipient address
        amountLD,// Send amount
        minAmountLD, // amountLD less slippage+fee
        extraOptions,
        composeMsg,
        oftCmd: new Uint8Array(), // Can leave empty
    }

    // quote gas and fees
    const [nativeFee, lzTokenFee] = await stargateUSDTPoolContract.quoteSend(sendParam, false)
    const messagingFee = {
        nativeFee,
        lzTokenFee
    }
    
    const bridgeResult = await stargateUSDTPoolContract.sendToken(sendParam, messagingFee, fromAddress, {
        value: nativeFee
    });
    console.log("https://layerzeroscan.com/tx/" + bridgeResult.hash)

```

## WithdrawHook

The WithdrawHook claims USDT tokens from PPFX on behalf of users, and then sends them cross-chain on StargateV2. 
- User signs message and delegates `withdraw`, `claim` to an Operator to execute txn on their behalf.
- Withdraw Service claims USDT tokens, and then calls Stargate contract to send the tokens to user cross-chain.
- Optionally, a withdraw fee may be charged (which may be needed to cover gas)

```
        const methodID = ppfxContract.WITHDRAW_SELECTOR();

        const data = abiCoder.encode(
            // (user, delegate, amount, nonce, methodID, signedAt)
            ["address", "address", "uint256", "uint256", "bytes4", "uint48"],
            [   
                fromAddress,
                withdrawHookContractAddress,
                withdrawAmount, 
                hookNonce,
                methodID,
                signTime
            ]
        );

        // ** All the .slice(2) are for removing the '0x' prefix
        // Feel free to use a better way to convert the hex data to uint8Array

        const rawDataBytes = fromHexString(data.slice(2));

        const hash = await ppfxContract.getWithdrawHash(fromAddress, withdrawHookContractAddress, withdrawAmount, hookNonce, methodID, signTime)

        const hashBytes = fromHexString(hash.slice(2));

        // Sign hashed data bytes
        const sig = await account.signMessage(hashBytes)

        // Concat the data
        const data = new Uint8Array([
            ...fromHexString(ppfxContractAddress.slice(2)),
            ...rawDataBytes,
            ...fromHexString(sig.slice(2))
        ])


    // execute txn on behalf of user w/ signed data
    withdrawHook.withdrawForUser(fromAddress, withdrawAmount, data)
```






