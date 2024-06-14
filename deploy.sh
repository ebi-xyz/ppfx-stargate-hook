#!/bin/bash
HEX_REGEX='^[0-9a-fA-F]+$'

COMMIT=$(git rev-parse HEAD)
echo "Deploying PPFX with commit:\n    $COMMIT"

ACCOUNT=$1

### Load Config ###
DEPLOY_CONFIG=$(cat config/deployConfig.json | jq)
TESTNET=$(echo "$DEPLOY_CONFIG" | jq -r '.IsTestnet')
EBI_TESTNET_RPC=$(echo "$DEPLOY_CONFIG" | jq -r '.EbiTestnetRPC')
EBI_MAINNET_RPC=$(echo "$DEPLOY_CONFIG" | jq -r '.EbiMainnetRPC')
EBI_MAINNET_VERIFY_URL="https://explorer.ebi.xyz/api\?",
EBI_TESTNET_VERIFY_URL="https://explorer.figarolabs.dev/api\?"

RPC=$(if [ "$TESTNET" = true ]; then echo "$EBI_TESTNET_RPC"; else echo "$EBI_MAINNET_RPC"; fi)
VERIFY_URL=$(if [ "$TESTNET" = true ]; then echo "$EBI_TESTNET_VERIFY_URL"; else echo "$EBI_MAINNET_VERIFY_URL"; fi)

CONFIG=$(cat config/hooksConfig.json | jq)

ADMIN=$(echo "$CONFIG" | jq -r '.admin')
PPFX=$(echo "$CONFIG" | jq -r '.ppfx')
TREASURY=$(echo "$CONFIG" | jq -r '.treasury')
STARGATE=$(echo "$CONFIG" | jq -r '.stargate')
LZ_ENDPOINT=$(echo "$CONFIG" | jq -r '.lzEndpoint')

echo "Hooks configs: "
echo "    PPFX=$PPFX"
echo "    ADMIN=$ADMIN"
echo "    TREASURY=$TREASURY"
echo "    LZ_ENDPOINT=$LZ_ENDPOINT"
echo "    STARGATE=$STARGATE"

if [[ $ACCOUNT =~ $HEX_REGEX ]]; then
    echo "Using Private key to deploy hooks"
    forge clean && forge script script/HooksDeployment.s.sol:HooksDeploymentScript --broadcast --verify --verifier blockscout --verifier-url $VERIFY_URL --rpc-url $RPC --private-key $ACCOUNT --gas-estimate-multiplier 2000 --optimize --optimizer-runs 200
else    
    echo "Using Account: $ACCOUNT to deploy hooks"
    forge clean && forge script script/HooksDeployment.s.sol:HooksDeploymentScript --broadcast --verify --verifier blockscout --verifier-url $VERIFY_URL --rpc-url $RPC --account $ACCOUNT --gas-estimate-multiplier 2000 --optimize --optimizer-runs 200
fi