#!/bin/bash

#Build Flag
PARAM=$1
####################################    Constants    ##################################################

#depends on mainnet or testnet
# NODE="--node https://rpc.junomint.com:443"
# CHAIN_ID=juno-1
# DENOM="ujuno"
# CONTRACT_CW20_TOKEN="juno1k0std830mz8ad34792pm9f5skv0rm2l7jgdqchn7msajatta4zcqq2krdu"

NODE="--node https://rpc.juno.giansalex.dev:443"
#NODE="--node https://rpc.uni.junomint.com:443"
CHAIN_ID=uni-2
DENOM="ujunox"
CONTRACT_CW20_TOKEN="juno1gx39x40hhgqqq0wwwnpa8jqvrxga72jk374vp0sqfr9xtz0ljmgqvypgmz" #CREW TOKEN

#not depends
NODECHAIN=" $NODE --chain-id $CHAIN_ID"
TXFLAG=" $NODECHAIN --gas-prices 0.03$DENOM --gas auto --gas-adjustment 1.3"
WALLET="--from workshop"

WASMFILE="artifacts/cw20_merkle_airdrop.wasm"

FILE_UPLOADHASH="uploadtx.txt"
FILE_CONTRACT_ADDR="contractaddr.txt"
FILE_CODE_ID="code.txt"
FILE_MERKLEROOT="merkleroot.txt"
ADDR_WORKSHOP="juno1htjut8n7jv736dhuqnad5mcydk6tf4ydeaan4s"
ADDR_ACHILLES="juno15fg4zvl8xgj3txslr56ztnyspf3jc7n9j44vhz"

# AIRDROP_LIST="proposal_14.json"
AIRDROP_LIST="/achilles/fortis/airdrop-extractor/airdroplists/marble-airdrop.json"

###################################################################################################
###################################################################################################
###################################################################################################
###################################################################################################
#Environment Functions
CreateEnv() {
    sudo apt-get update && sudo apt upgrade -y
    sudo apt-get install make build-essential gcc git jq chrony -y
    wget https://golang.org/dl/go1.17.3.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.17.3.linux-amd64.tar.gz
    rm -rf go1.17.3.linux-amd64.tar.gz

    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export GO111MODULE=on
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    
    rustup default stable
    rustup target add wasm32-unknown-unknown

    git clone https://github.com/CosmosContracts/juno
    cd juno
    git fetch
    git checkout v2.1.0
    make install

    rm -rf juno

    junod keys import workshop workshop.key

}

#Contract Functions

#Build Optimized Contracts
OptimizeBuild() {

    echo "================================================="
    echo "Optimize Build Start"
    
    docker run --rm -v "$(pwd)":/code \
        --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
        --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
        cosmwasm/rust-optimizer:0.12.4
}

RustBuild() {

    echo "================================================="
    echo "Rust Optimize Build Start"

    RUSTFLAGS='-C link-arg=-s' cargo wasm

    mkdir artifacts
    cp target/wasm32-unknown-unknown/release/cw20_merkle_airdrop.wasm $WASMFILE
}

#Writing to FILE_UPLOADHASH
Upload() {
    echo "================================================="
    echo "Upload $WASMFILE"
    
    UPLOADTX=$(junod tx wasm store $WASMFILE $WALLET $TXFLAG --output json -y | jq -r '.txhash')
    echo "Upload txHash:"$UPLOADTX
    
    #save to FILE_UPLOADHASH
    echo $UPLOADTX > $FILE_UPLOADHASH
    echo "wrote last transaction hash to $FILE_UPLOADHASH"
}

UploadTest() {
    echo "================================================="
    echo "Upload $WASMFILE"
    
    junod tx wasm store $WASMFILE $WALLET $TXFLAG --output json -y
    
}

#Read code from FILE_UPLOADHASH
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
    
    #read from FILE_CODE_ID
    CODE_ID=$(cat $FILE_CODE_ID)
    junod tx wasm instantiate $CODE_ID '{"cw20_token_address":"'$CONTRACT_CW20_TOKEN'", "owner":"juno1erdj5eg83f6ycvyzqlwlx4sl2zvxe7nt5x25dk"}' --label "vMarble Airdrop from 8" $WALLET $TXFLAG -y
}

#Get Instantiated Contract Address
GetContractAddress() {
    echo "================================================="
    echo "Get contract address by code"
    
    
    #read from FILE_CODE_ID
    CODE_ID=$(cat $FILE_CODE_ID)
    junod query wasm list-contract-by-code $CODE_ID $NODECHAIN --output json
    CONTRACT_ADDR=$(junod query wasm list-contract-by-code $CODE_ID $NODECHAIN --output json | jq -r '.contracts[0]')
    
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
    #junod tx wasm execute $CONTRACT_MERKLE '{"update_config":{"new_owner":"'$ADDR_WORKSHOP'"}}' $WALLET $TXFLAG
    junod tx wasm execute $CONTRACT_MERKLE '{"register_merkle_root":{"merkle_root":"'$MERKLEROOT'"}}' $WALLET $TXFLAG
}

#Send initial tokens
SetFund() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_CW20_TOKEN '{"send":{"amount":"3020","contract":"'$CONTRACT_MERKLE'","msg":""}}' --from workshop $TXFLAG
}

Claim() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_MERKLE '{"claim":{ "stage":1, "amount":"100", "proof": ["3c99157847651cbeec8d57797510663bd6167aaa478f96e080a507034147452e"]}}' $WALLET $TXFLAG
}

Burn() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_MERKLE '{"burn":{ "stage":1}}' $WALLET $TXFLAG
}

Withdraw() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_MERKLE '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG
}


# SetPrice() {
#     CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
#     junod tx wasm execute $CONTRACT_MERKLE '{"set_price":{"denom":"ujuno", "price":"100"}}' $WALLET $TXFLAG
# }


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
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"is_claimed":{"stage": 1, "address": "'$ADDR_ACHILLES'"}}' $NODECHAIN
}
PrintTotalClaimed() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_MERKLE '{"total_claimed":{ "stage":1 }}' $NODECHAIN
}
#################################################################################
PrintMerkleContractState() {
    #code id 32
    junod query wasm list-code $NODECHAIN --output json
    junod query wasm list-contract-by-code 32 $NODECHAIN
    
}
#################################################################################
PrintWalletBalance() {
    junod query bank balances $ADDR_WORKSHOP $NODECHAIN
    junod query wasm contract-state smart $CONTRACT_CW20_TOKEN '{"balance":{"address":"'$ADDR_WORKSHOP'"}}' $NODECHAIN
    junod query wasm contract-state smart $CONTRACT_CW20_TOKEN '{"token_info":{}}' $NODECHAIN
}

#################################### End of Function ###################################################
if [[ $PARAM == "" ]]; then
    RustBuild
    Upload
sleep 8
    GetCode
sleep 10
    Instantiate
sleep 10
    GetContractAddress
sleep 5
   SetMerkleString
sleep 5
   SetFund
sleep 5
   PrintTotalClaimed
# sleep 5
#    Withdraw
else
    $PARAM
fi

# OptimizeBuild
# Upload
# GetCode
# Instantiate
# GetContractAddress
# CreateEscrow
# TopUp

