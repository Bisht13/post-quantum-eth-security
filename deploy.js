const { Web3 } = require("web3");

// Loading the contract ABI and Bytecode
// (the results of a previous compilation step)
const fs = require("fs");
const { abi, bytecode } = JSON.parse(
  fs.readFileSync("./bin/contracts/gps/GpsStatementVerifier.json")
);

async function main() {
  // Configuring the connection to an Ethereum node
  const network = process.env.ETHEREUM_NETWORK;
  const web3 = new Web3(
    new Web3.providers.HttpProvider("https://rpc.ankr.com/eth_sepolia")
  );
  // Creating a signing account from a private key
  const signer = web3.eth.accounts.privateKeyToAccount(
    "0x" + process.env.SIGNER_PRIVATE_KEY
  );
  web3.eth.accounts.wallet.add(signer);

  // Using the signing account to deploy the contract
  const contract = new web3.eth.Contract(abi);
  contract.options.data = bytecode;
  CairoBootloaderProgramPart1 = "0x93a2f43b7077a70A3f3C5146b2c47E19Bf6fc129";
  CairoBootloaderProgramPart2 = "0x9709DfC33B8Fa0B266fc18B966483a0Ae4C54Da8";
  memoryPageFactRegistry = "0xD11cbd0b252569Ff67551A95b33da45b23814d24";
  cairoVerifierContracts = [
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
    "0xC11B019217c0B9d33f6C253B5ad8e5079370fb45",
  ];
  hashedSupportedCairoVerifiers =
    "3178097804922730583543126053422762895998573737925004508949311089390705597156";

  simpleBootloaderProgramHash =
    "2962621603719000361370283216422448934312521782617806945663080079725495842070";

  const deployTx = contract.deploy({
    arguments: [
      CairoBootloaderProgramPart1,
      CairoBootloaderProgramPart2,
      memoryPageFactRegistry,
      cairoVerifierContracts,
      hashedSupportedCairoVerifiers,
      simpleBootloaderProgramHash,
    ],
  });
  const deployedContract = await deployTx
    .send({
      from: signer.address,
      gas: await deployTx.estimateGas(),
    })
    .once("transactionHash", (txhash) => {
      console.log(`Mining deployment transaction ...`);
      console.log(`https://${network}.etherscan.io/tx/${txhash}`);
    });
  // The contract is now deployed on chain!
  console.log(`Contract deployed at ${deployedContract.options.address}`);
  console.log(
    `Add DEMO_CONTRACT to the.env file to store the contract address: ${deployedContract.options.address}`
  );
}

require("dotenv").config();
main();
