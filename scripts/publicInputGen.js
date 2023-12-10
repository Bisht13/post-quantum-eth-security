const { ethers } = require("ethers");
const contractAbi = require("./abi.json");
const fs = require("fs");
require("dotenv").config();

const yourAddress = process.env.SIGNER_ADDRESS;
const nonce = process.env.NONCE;

const contractAddress = "0x8bF42b42C49082E85a9c42A7A052B487A1BEE2e8";

const provider = new ethers.providers.JsonRpcProvider(
  "https://rpc.ankr.com/eth_sepolia"
);
const wallet = new ethers.Wallet("0x" + "", provider);

const contract = new ethers.Contract(contractAddress, contractAbi, wallet);

async function getData() {
  try {
    let result = await contract.getData(yourAddress, nonce);

    result = result.substring(2); // Remove 0x

    // Break result into 2 equal parts
    let firstHalf = result.substring(0, result.length / 2);
    let secondHalf = result.substring(result.length / 2, result.length);
    // Convert hex to bigInt
    firstHalf = BigInt("0x" + firstHalf);
    secondHalf = BigInt("0x" + secondHalf);
    const dataToWrite = `${nonce},${firstHalf},${secondHalf}`;
    const filePath = "publicInput.txt";
    // Write to the file
    fs.writeFile(filePath, dataToWrite, (err) => {
      if (err) {
        console.error("Error writing to file:", err);
      } else {
        console.log("Data has been written to the file successfully.");
      }
    });
  } catch (error) {
    console.error("Error:", error);
  }
}

getData();
