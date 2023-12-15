# Post Quantum Ethereum Security

This project is a proof of concept on how one can make Ethereum post quantumly secure without any modifications to the core protocol.  

## Table of Contents

- [Post Quantum Ethereum Security](#post-quantum-ethereum-security)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Running](#running)

## Introduction

The problem with the current signature algorithm, ECDSA, is that the public key of the user is exposed on chain. This means that in post quantum world, the public key can be used to derive the private key. This is a huge problem as the attacker can then use the private key to sign transactions and steal funds from the user.

To solve this problem, we can create a ZK STARK proof that the user has the public key corresponding to the address. This proof can be verified on the chain using account abstraction, although it is not implemented in this Proof of Concept (PoC). This way, the public key is not exposed on chain and the user can still sign transactions.

This is possible because ZK STARKs are post quantum secure. This means that even if the attacker has a quantum computer, he cannot forge a proof.

The proof of concept works as follows:
- A user generates public and private inputs for a ZK STARK proof corresponding to their transaction.
- Using Sandstorm, the user generates a proof for the inputs.
- The user then submits the proof to the blockchain for verification.

The proof can then be verified by a smart contract wallet using account abstraction. The smart contract wallet can then be used to send transactions.

For verifying the proof of a transaction, in the function *_validateSignature* of SimpleAccount.sol, the smart contract needs to call the verifying contract. If the proof is valid, the transaction will take place else it will revert resulting the signature validation to fail.


## Getting Started

For generating the proof, a program has been written in Cairo. The program can be found in the folder `sandstorm-starkware-verifier-integration/test.cairo`. The program takes in the following inputs:
- The public key of the user
- nonce
- keccak hash of address and nonce

The program essentially checks if the hash of the address generated from the public key and nonce is equal to the keccak hash provided. The program will fail if this condition is not met. 

Then using Sandstorm, a proof is generated for this computation and multiple JS files are created for submitting the proof to the blockchain. The proof is verified on chain using modified StarkEx contracts.

Modified StarkEx contracts can be found in the folder `contracts`. These contracts are responsible for verifying the proof on chain and are engineered specifically to only verify the proofs generated by our Cairo program.

One can deploy these contracts themselves on any chain, currently the contracts are deployed on the Sepolia testnet. The addresses of the contracts are present in the file `contract-addresses.json`.

`Note: Currently, it takes 10 transactions to verify a proof. This is because the proof is too large to be submitted in a single transaction. There are 6 FRI verifications, 3 Merkle verifications and finally, the proof verification.`

### Prerequisites

To run the project, you need to setup the following:
- Rust
- NodeJS version 18.0.0 or later
- Python3.9
- [Cairo](https://docs.cairo-lang.org/quickstart.html)
- Sandstorm-CLI
  ```sh
  cargo +nightly install --features parallel --git https://github.com/andrewmilson/sandstorm sandstorm-cli
  ```
### Running

Step-by-step instructions on how to generate and verify the proof. Currently, works only on the Sepolia testnet.

1. Boot up the bundler. We would run our own bundler with custom settings.
   ```sh
    cd bundler
    yarn && yarn preprocess
    yarn run bundler --network sepolia --mnemonic [path_to_mnemonic.txt] --unsafe
    cd ..
   ```
2. Then we will run Trampoline for creating our smart contract wallet.
   ```sh
    cd trampoline
    yarn && yarn start
    cd ..
   ```
3. After building Trampoline, we have to import the extension in our browser and create the wallet. Our wallet will be empty and not deployed yet. Send some funds to the wallet address. On attempting to send a transaction, you will find the private key in the console log as well as the transaction hash being prompted on Trampoline. Using these, setup the environment variables.
4. Generate public and private inputs for the proof. 
    ```sh
    npm i
    node scripts/setup.js
    ```
    This will populate `sandstorm-starkware-verifier-integration/bootloader_inputs.json`.
5. Generate the proof.
    ```sh
    cd sandstorm-starkware-verifier-integration

    cairo-run --program_input ./bootloader_inputs.json \
        --program ./bootloader_compiled.json \
        --air_private_input ./air-private-input.json \
        --air_public_input ./air-public-input.json \
        --trace_file ./trace.bin \
        --memory_file ./memory.bin \
        --layout starknet \
        --min_steps 128 \
        --proof_mode \
        --print_info

    sandstorm-cli --program bootloader_compiled.json \
        --air-public-input air-public-input.json \
        prove --lde-blowup-factor 4 --num-queries 33 --proof-of-work-bits 30 --air-private-input air-private-input.json \
        --output bootloader-proof.bin

    cargo +nightly run

    cd ..
    ```
6. After the proof is generated, we would a blob.txt file in scripts folder. This file contains the proof in hex format.
   ```sh
    python3.9 scripts/generateProof.py \
        --proof ./sandstorm-starkware-verifier-integration/test/AutoGenProofData.sol \
        --output_folder ./scripts \
        --public_inputs ./sandstorm-starkware-verifier-integration/bootloader_inputs.json
   ```
7. Copy the proof from blob.txt and paste it in the prompt on Trampoline and send the transaction.


There you go! You have successfully made a quantum secure transaction on Ethereum.


To see a demo of the project, check out this [video](https://www.youtube.com/watch?v=Oa2ylMyyswQ).
For on-chain verification, check out this [video](https://drive.google.com/file/d/1pzCRlZFrfC4wWtRjAEcGmLhl6ieIb9rG/view?usp=sharing).