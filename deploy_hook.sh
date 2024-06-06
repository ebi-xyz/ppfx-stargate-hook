#!/bin/bash

# configs
EBI_RPC=https://rpc.ebi.xyz
EBI_LZENDPOINT=0x6F475642a6e85809B1c36Fa62763669b1b48DD5B
EBI_STARGATE=0xF8c61c8F4Fdd41dd444f7b582C9F440e1b1ADcc8
ADMIN=0x7C44e3ab48a8b7b5779BE7fFB06Fec0eB6a41faE
TREASURY=0x16b68c1F569Ffc6D594c43CEFf7dF1116005Bfe4

EBI_PPFX=$1
DEPLOYER_ACCOUNT_NAME=$2

COMMIT=$(git rev-parse HEAD)
echo "Deploying Hooks with commit:"
echo "    $COMMIT"

echo "Hooks configs: "
echo "    PPFX=$EBI_PPFX"
echo "    DEPLOYER_ACCOUNT=$DEPLOYER_ACCOUNT_NAME"
echo "    ADMIN=$ADMIN"
echo "    TREASURY=$TREASURY"
echo "    LZ_ENDPOINT=$EBI_LZENDPOINT"
echo "    STARGATE=$EBI_STARGATE"


echo "Creating Deposit Hook...."
forge create src/PPFXStargateDepositHook.sol:PPFXStargateDepositHook \
--constructor-args $EBI_PPFX $EBI_LZENDPOINT $EBI_STARGATE \
--rpc-url $EBI_RPC --account $DEPLOYER_ACCOUNT_NAME

echo "Creating Withdraw Hook...."
forge create src/PPFXStargateWithdrawHook.sol:PPFXStargateWithdrawHook \
--constructor-args $EBI_PPFX $ADMIN $TREASURY $EBI_STARGATE \
--rpc-url $EBI_RPC --account $DEPLOYER_ACCOUNT_NAME