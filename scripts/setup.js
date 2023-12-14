const fs = require("fs");
const { ethers } = require("ethers");
require("dotenv").config({ override: true });

let privateKey = process.env.SIGNER_PRIVATE_KEY;
privateKey = privateKey.substring(2, privateKey.length);
let txnHash = process.env.TXN_HASH;
txnHash = txnHash.substring(2, txnHash.length);

// Get the public key from the private key
const wallet = new ethers.Wallet(privateKey);
let publicKey = wallet.publicKey;
publicKey = publicKey.substring(4, publicKey.length);

// Get the address from the public key
let address = wallet.address;
address = address.substring(2, address.length);

// const filePath = "privateInput.txt";

// Break the public key into 4 equal parts
let firstHalf = publicKey.substring(0, publicKey.length / 4);
let secondHalf = publicKey.substring(
  publicKey.length / 4,
  publicKey.length / 2
);
let thirdHalf = publicKey.substring(
  publicKey.length / 2,
  (3 * publicKey.length) / 4
);
let fourthHalf = publicKey.substring(
  (3 * publicKey.length) / 4,
  publicKey.length
);

// Convert hex to bigInt
firstHalf = BigInt("0x" + firstHalf);
secondHalf = BigInt("0x" + secondHalf);
thirdHalf = BigInt("0x" + thirdHalf);
fourthHalf = BigInt("0x" + fourthHalf);

// Break the transaction hash into 2 equal parts
let firstHalfTxnHash = txnHash.substring(0, txnHash.length / 2);
let secondHalfTxnHash = txnHash.substring(txnHash.length / 2, txnHash.length);

// Convert hex to bigInt
firstHalfTxnHash = BigInt("0x" + firstHalfTxnHash);
secondHalfTxnHash = BigInt("0x" + secondHalfTxnHash);

// const dataToWrite = `${firstHalf},\n${secondHalf},\n${thirdHalf},\n${fourthHalf}`;

// // Write to the file
// fs.writeFile(filePath, dataToWrite, (err) => {
//   if (err) {
//     console.error("Error writing to file:", err);
//   } else {
//     console.log("Data has been written to the file successfully.");
//   }
// });

// Clear bootloader_inputs.json and update with the address
const bootloaderInputsPath =
  "./sandstorm-starkware-verifier-integration/bootloader_inputs.json";
let bootloaderInputs = {
  x_high: firstHalf,
  x_low: secondHalf,
  y_high: thirdHalf,
  y_low: fourthHalf,
  address: BigInt("0x" + address),
  hash_high: firstHalfTxnHash,
  hash_low: secondHalfTxnHash,
};
const writeStream = fs.createWriteStream(bootloaderInputsPath);
let dataToWrite = ["{"];
for (let key in bootloaderInputs) {
  dataToWrite.push(`\"${key}\"\:${bootloaderInputs[key]}\,`);
}
dataToWrite[dataToWrite.length - 1] = dataToWrite[dataToWrite.length - 1].slice(
  0,
  dataToWrite[dataToWrite.length - 1].length - 1
);
dataToWrite.push("}");
writeStream.write(dataToWrite.join(""));
writeStream.end();
