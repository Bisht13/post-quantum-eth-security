const fs = require("fs");
require("dotenv").config();

publicKey =
  "29c6430dd799756a96fc675ab7e7a7be1a1eafe9e979846771a36b5a5ad832f9c315e5ca5718cb5a5b50b95488dc78d802b5422edf4acc79e77d7249480f73fd";

const filePath = "privateInput.txt";

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

const dataToWrite = `${firstHalf},\n${secondHalf},\n${thirdHalf},\n${fourthHalf}`;

// Write to the file
fs.writeFile(filePath, dataToWrite, (err) => {
  if (err) {
    console.error("Error writing to file:", err);
  } else {
    console.log("Data has been written to the file successfully.");
  }
});
