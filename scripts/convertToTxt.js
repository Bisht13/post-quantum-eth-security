// ------------------------------------ Driver Code Start ------------------------------------
const fs = require("fs");

// Specify the path to the binary file
const filePath = "blob.bin";
var dataHex = null;

// Read the file
let Data = "";

// Create a readable stream
fs.readFile(filePath, (err, data) => {
  if (err) throw err;
  Data = data;
  dataHex = Data.toString("hex");
  // ------------------------------------ Driver Code End ------------------------------------

  // ------------------------------------ Main Snippet Start ------------------------------------
  // dataHex is the signature in hex format that contain whole blob
  // make a array containing the hex values of dataHex in chunks of 32 bytes
  let FriArray = [];
  let MerkleArray = [];
  let gps = "";

  // 1st 32 bytes is no of FriBlocks, store in a int variable
  let currLen = 0;
  let FriBlocks = parseInt(dataHex.slice(0, 64), 16);
  let MerkleBlocks = parseInt(dataHex.slice(64, 128), 16);
  let GpsBlocks = parseInt(dataHex.slice(128, 192), 16);
  currLen = 192;

  // storing in array
  for (let i = 0; i < FriBlocks; i++) {
    FriArray.push(
      dataHex.slice(
        currLen + 64,
        currLen + 64 + parseInt(dataHex.slice(currLen, currLen + 64), 16) * 2
      )
    );
    currLen += 64 + parseInt(dataHex.slice(currLen, currLen + 64), 16) * 2;
  }

  for (let i = 0; i < MerkleBlocks; i++) {
    MerkleArray.push(
      dataHex.slice(
        currLen + 64,
        currLen + 64 + parseInt(dataHex.slice(currLen, currLen + 64), 16) * 2
      )
    );
    currLen += 64 + parseInt(dataHex.slice(currLen, currLen + 64), 16) * 2;
  }

  gps = dataHex.slice(
    currLen + 64,
    currLen + 64 + parseInt(dataHex.slice(currLen, currLen + 64), 16) * 2
  );
  // ------------------------------------ Main Snippet End ------------------------------------

  // ------------------------------------Testing Start------------------------------------
  // write the array each array element in a file one by one
  for (let i = 0; i < FriArray.length; i++) {
    fs.writeFile("Fri" + i + ".txt", FriArray[i], (err) => {
      if (err) throw err;
      console.log("Fri" + i + ".txt saved!");
    });
  }

  for (let i = 0; i < MerkleArray.length; i++) {
    fs.writeFile("Merkle" + i + ".txt", MerkleArray[i], (err) => {
      if (err) throw err;
      console.log("Merkle" + i + ".txt saved!");
    });
  }

  fs.writeFile("Gps.txt", gps, (err) => {
    if (err) throw err;
    console.log("Gps.txt saved!");
  });

  fs.writeFile("blob.txt", dataHex, (err) => {
    if (err) throw err;
    console.log("blob.txt saved!");
  });
  // ------------------------------------Testing End------------------------------------
});
