#!/bin/bash

#Build Flag
PARAM=$1
####################################    Constants    ##################################################

#depends on mainnet or testnet
NODE="--node https://rpc-juno.itastakers.com:443"
CHAIN_ID=juno-1
DENOM="ujuno"
TOKEN_BLOCK="juno1y9rf7ql6ffwkv02hsgd4yruz23pn4w97p75e2slsnkm0mnamhzysvqnxaq"

#not depends
NODECHAIN=" $NODE --chain-id $CHAIN_ID"
TXFLAG=" $NODECHAIN --gas-prices 0.001$DENOM --gas auto --gas-adjustment 1.3"
WALLET="--from new_marble"

# CODE_ID=87
WASMFILE="artifacts/merkleairdrop-block.wasm"

FILE_UPLOADHASH="uploadtx.txt"
FILE_CONTRACT_ADDR="contractaddr-airdrop-block.txt"
FILE_MERKLEROOT="merkleroot.txt"
FILE_CODE_ID="code.txt"

# ADDR_MARBLE="juno1gxlwgusm7mngml9kzlkmjw3fskekldxdsswvpy"
ADDR_MARBLE="juno1zzru8wptsc23z2lw9rvw4dq606p8fz0z6k6ggn"
ADDR_LUKE="juno1ddcvnnq0puupr0f3cyq77ffmk32ylaxcd3ahjg"


AIRDROP_LIST="/achilles/airdrop/airdrop-extractor/airdroplists/proposal_block6.json"

###################################################################################################
###################################################################################################
###################################################################################################
###################################################################################################

RustBuild() {

    echo "================================================="
    echo "Rust Optimize Build Start"

    RUSTFLAGS='-C link-arg=-s' cargo wasm

    mkdir artifacts
    cp target/wasm32-unknown-unknown/release/block_merkle_airdrop.wasm $WASMFILE
}

Upload() {
    echo "================================================="
    echo "Upload $WASMFILE"
    
    UPLOADTX=$(junod tx wasm store $WASMFILE $WALLET $TXFLAG --output json -y | jq -r '.txhash')
    echo "Upload txHash:"$UPLOADTX
    
    #save to FILE_UPLOADHASH
    echo $UPLOADTX > $FILE_UPLOADHASH
    echo "wrote last transaction hash to $FILE_UPLOADHASH"
}

GetCode() {
    echo "================================================="
    echo "Get code from transaction hash written on $FILE_UPLOADHASH"
    
    #read from FILE_UPLOADHASH
    TXHASH=$(cat $FILE_UPLOADHASH)
    echo "read last transaction hash from $FILE_UPLOADHASH"
    echo $TXHASH
    
    QUERYTX="junod query tx $TXHASH $NODECHAIN --output json"
	CODE_ID=$(junod query tx $TXHASH $NODECHAIN --output json | jq -r '.logs[0].events[-1].attributes[0].value')
	echo "Contract Code_id:"$CODE_ID

    #save to FILE_CODE_ID
    echo $CODE_ID > $FILE_CODE_ID
}

#Instantiate Contract
Instantiate() {
    echo "================================================="
    echo "Instantiate Contract"

    CODE_ID=$(cat $FILE_CODE_ID)    
    junod tx wasm instantiate $CODE_ID '{"cw20_token_address":"'$TOKEN_BLOCK'", "owner":"'$ADDR_MARBLE'"}' --label "Block Airdrop" $WALLET --no-admin $TXFLAG -y
}

#Get Instantiated Contract Address
GetContractAddress() {
    echo "================================================="
    echo "Get contract address by code"
    
    #read from FILE_CODE_ID
    CODE_ID=$(cat $FILE_CODE_ID)
    junod query wasm list-contract-by-code $CODE_ID $NODECHAIN --output json
    CONTRACT_ADDR=$(junod query wasm list-contract-by-code $CODE_ID $NODECHAIN --output json | jq -r '.contracts[-1]')
    
    echo "Contract Address : "$CONTRACT_ADDR

    #save to FILE_CONTRACT_ADDR
    echo $CONTRACT_ADDR > $FILE_CONTRACT_ADDR
}


###################################################################################################
###################################################################################################
###################################################################################################
###################################################################################################

GetMerkleRoot() {
    cd helpers
    MERKLEROOT=$(merkle-airdrop-cli generateRoot --file $AIRDROP_LIST)
    cd ..
    echo $MERKLEROOT > $FILE_MERKLEROOT
}

SetMerkleString() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    GetMerkleRoot
    sleep 3
    MERKLEROOT=$(cat $FILE_MERKLEROOT)
    #junod tx wasm execute $CONTRACT_MERKLE '{"register_merkle_root":{"merkle_root":"'$MERKLEROOT'", "expiration": {"at_time":"1648641334"}, "start": {"at_time":"1648641334"}}}' $WALLET $TXFLAG -y
    junod tx wasm execute $CONTRACT_MERKLE '{"register_merkle_root":{"merkle_root":"'$MERKLEROOT'"}}' $WALLET $TXFLAG -y
}

#Send initial tokens
SetFund() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $TOKEN_BLOCK '{"send":{"amount":"99980590420842","contract":"'$CONTRACT_MERKLE'","msg":""}}' $WALLET $TXFLAG
    #junod tx wasm execute $TOKEN_BLOCK '{"send":{"amount":"100","contract":"'$CONTRACT_MERKLE'","msg":""}}' $WALLET $TXFLAG
}

UpdateConfig() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_MERKLE '{"update_config":{"new_owner":"'$ADDR_LUKE'"}}' $WALLET $TXFLAG -y
}

# Claim() {
#     CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
#     junod tx wasm execute $CONTRACT_MERKLE '{"claim":{ "stage":1, "amount":"4962779", "proof": ["c43534644ee4611cffb91858ea4e50372fdcb8b3e8857167069a394aa25e90ea","a2cb5e5bb42ce528f8c678bcb7d04c6e52bfc1c906ff46c00a906d536d515920","a119e01d90c7839e712124ddf98eaadbc3aea8c8f8aa4ddea01ffb758e219002","58b737ce9f35040a006976ce01bcb903eb5ec1e7d2749f683800b89fca61a3d7","90d71d2fab3972179b3021779a8757a776f9bc9b69dd472aa518c060714e98f7","2f7b385a1d3d00af43346bdabf5b56b05557ba4e70d15e95fbd54b0d02780303","6393cd19a3db5a52e6bda15bde666b7c47f4e9ba7deac367155d9d43eb55b53d","57a91e5e4fac357e09848d4890ff64d28516a9c96a8fd5e1789166f2cd12ab15","f21c6d915cfe28e44f28ea21d70ddd05c3a2e12b4527c854328c8395be761ac3","dd09530e4608b7d266258fb5dcf7bdbfe6d044548934dcce39c2f7e39c501c69","f063f516e14e99b91a80bff2db990e6fb3a596090ef9498c07a8b3d9f48bd7b5","02398ce9c8f138605df42b4dfe477d48ba4b4a5f39b48563516da8c5b96c6d28","92ca51326196edf6890166c8b9e5305b47ee1ff092eb836733df2cdaf6aa5a1b","eda4dddda5c01810e92af04b92939a1fe7362dfcd16c0058c7ce2f7dd0edd55f"]}}' $WALLET $TXFLAG
# }

# Burn() {
#     CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
#     junod tx wasm execute $CONTRACT_MERKLE '{"burn":{ "stage":1}}' $WALLET $TXFLAG
# }

Withdraw() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_MERKLE '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG
}


PrintMerkleConfig() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"config":{}}' $NODECHAIN
}

PrintMerkleRoot() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"merkle_root":{"stage":1}}' $NODECHAIN
}

PrintLatestStage() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"latest_stage":{}}' $NODECHAIN
}

PrintIsClaimed() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"is_claimed":{"stage": 1, "address": "'$ADDR_MARBLE'"}}' $NODECHAIN
}
PrintTotalClaimed() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"total_claimed":{ "stage":1 }}' $NODECHAIN
}
#################################################################################
PrintWalletBalance() {
    junod query bank balances $ADDR_MARBLE $NODECHAIN
    junod query wasm contract-state smart $TOKEN_BLOCK '{"balance":{"address":"'$ADDR_MARBLE'"}}' $NODECHAIN
}

#################################### End of Function ###################################################
if [[ $PARAM == "" ]]; then
    Instantiate
sleep 10
    GetContractAddress
sleep 5
   SetMerkleString
# sleep 5
#     UpdateConfig
# sleep 5
#    SetFund
# sleep 5
#    PrintTotalClaimed
# sleep 5
#    Withdraw
else
    $PARAM
fi
