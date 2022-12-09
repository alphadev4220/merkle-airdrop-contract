#!/bin/bash

#Build Flag
PARAM=$1
SUBPARAM=$2
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
FILE_CONTRACT_ADDR="contractaddr-airdrop-block"
FILE_MERKLEROOT="merkleroot.txt"
FILE_CODE_ID="code.txt"

# ADDR_MARBLE="juno1gxlwgusm7mngml9kzlkmjw3fskekldxdsswvpy"
ADDR_MARBLE="juno1zzru8wptsc23z2lw9rvw4dq606p8fz0z6k6ggn"
ADDR_LUKE="juno1ddcvnnq0puupr0f3cyq77ffmk32ylaxcd3ahjg"

PUBLIC_AIRDROP_CONTRACT7="juno1t5jvvwhe0jx42staqd4hr50kcp77zaglhv34z2v9rxtxc2rdljsqqsn685"   #this is the start
PUBLIC_AIRDROP_CONTRACT8="juno167qa45awpjy9dn7s8j44kqp5w858ckavk2xdvw2myxunphnyl2wsmck34v"
PUBLIC_AIRDROP_CONTRACT9="juno1w57zrq76h2fgvefxuc4sllm5qa8djcdg3j30hwux4087fafeza5qe562hj"
PUBLIC_AIRDROP_CONTRACT10="juno1ce5t0gj8y5qk4g8cm7muqndv9x5wp9udfyauqusr3au0sqvc4a4swrvqag"
PUBLIC_AIRDROP_CONTRACT11="juno1zv5aqa8pw8rc7u7f4734z7yzccmu533csew2px4lqqgxpuvxa7fq3e6q6k"
PUBLIC_AIRDROP_CONTRACT12="juno125l3jmtxy3l3tkhckh38p42jplxrp4yv60d3su6se8mp567qvdsqg8mk0y"
PUBLIC_AIRDROP_CONTRACT13="juno1mq6gshslutgwt6g3dvzv7vrawnh00xnve89kevwl08gn9zc5shtswkkjdl"
PUBLIC_AIRDROP_CONTRACT14="juno1qgpcutfagv84n8uwzjspctevly6ftpztmj0tr38g98j3x90vgpyqsvctg4"
PUBLIC_AIRDROP_CONTRACT15="juno1fwwe690sfnectw5z3va2gp36qfrfkhn50fnwd26xc6tangf5scxqkljfkv"
PUBLIC_AIRDROP_CONTRACT16="juno1h9j6y00fw76dp0hwukznh0tpe57e7mfl83m55w72pqkehgqs76gs5js8el"
PUBLIC_AIRDROP_CONTRACT17="juno1hy9awpf3937es5wcqpd64tzpyert7dcurrcmmhvnu2p0v9r5lnwqjccrwr"
PUBLIC_AIRDROP_CONTRACT18="juno10jc6rnvfg97v7c6t6s3tcs62sfpml6vprf7jkqy35camtjz6lwesghdw8j"
PUBLIC_AIRDROP_CONTRACT19="juno1erel3a7x3n8f78ggnagxy45f7z92uzwjs64qm8plpz54s6vcngvqmggqls"

AIRDROP_LIST_PREFIX="/achilles/airdrop/airdrop-extractor/marble/earlylpparser/result/data"

Instantiate() { 
    echo "================================================="
    echo "Instantiate Contract $SUBPARAM"
    #read from FILE_CODE_ID
    CODE_ID=309
    
    TXHASH=$(junod tx wasm instantiate $CODE_ID '{"cw20_token_address":"'$TOKEN_BLOCK'", "owner":"'$ADDR_MARBLE'"}' --label "Block Airdrop $SUBPARAM" --admin $ADDR_MARBLE $WALLET $TXFLAG -y --output json | jq -r '.txhash')
    echo $TXHASH
    CONTRACT_ADDR=""
    while [[ $CONTRACT_ADDR == "" ]]
    do
        sleep 3
        CONTRACT_ADDR=$(junod query tx $TXHASH $NODECHAIN --output json | jq -r '.logs[0].events[0].attributes[0].value')
    done
    echo $CONTRACT_ADDR
    echo $CONTRACT_ADDR > $FILE_CONTRACT_ADDR$SUBPARAM".txt"

    SetMerkleString
}



###################################################################################################
###################################################################################################
###################################################################################################
###################################################################################################


SetMerkleString() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR$SUBPARAM".txt")

    # cd helpers
    echo $AIRDROP_LIST_PREFIX$SUBPARAM".json"
    MERKLEROOT=$(merkle-airdrop-cli generateRoot --file $AIRDROP_LIST_PREFIX$SUBPARAM".json")
    # cd ..
    echo $MERKLEROOT
    echo $MERKLEROOT > $FILE_MERKLEROOT

    sleep 3
    #junod tx wasm execute $CONTRACT_MERKLE '{"register_merkle_root":{"merkle_root":"'$MERKLEROOT'", "expiration": {"at_time":"1648641334"}, "start": {"at_time":"1648641334"}}}' $WALLET $TXFLAG -y
    junod tx wasm execute $CONTRACT_MERKLE '{"register_merkle_root":{"merkle_root":"'$MERKLEROOT'"}}' $WALLET $TXFLAG -y
    sleep 3
}

#Send initial tokens
SetFund() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR$SUBPARAM".txt")
    junod tx wasm execute $TOKEN_BLOCK '{"send":{"amount":"600000000000","contract":"'$CONTRACT_MERKLE'","msg":""}}' $WALLET $TXFLAG -y
    #junod tx wasm execute $TOKEN_BLOCK '{"send":{"amount":"100","contract":"'$CONTRACT_MERKLE'","msg":""}}' $WALLET $TXFLAG
}

UpdateConfig() {
    CONTRACT_MERKLE=$(cat $FILE_CONTRACT_ADDR$SUBPARAM".txt")
    junod tx wasm execute $CONTRACT_MERKLE '{"update_config":{"new_owner":"'$ADDR_LUKE'"}}' $WALLET $TXFLAG -y
}


Withdraw() {
    
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT7 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT8 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT9 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT10 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT11 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT12 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT13 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT14 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT15 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT16 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT17 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT18 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
    sleep 5
    junod tx wasm execute $PUBLIC_AIRDROP_CONTRACT19 '{"withdraw_all":{"stage":1}}' $WALLET $TXFLAG -y
}

#################################################################################
PrintWalletBalance() {
    junod query bank balances $ADDR_MARBLE $NODECHAIN
    junod query wasm contract-state smart $TOKEN_BLOCK '{"balance":{"address":"'$ADDR_MARBLE'"}}' $NODECHAIN
}

#################################### End of Function ###################################################
if [[ $PARAM == "" ]]; then
    PrintWalletBalance
else
    echo $SUBPARAM
    $PARAM 
fi
