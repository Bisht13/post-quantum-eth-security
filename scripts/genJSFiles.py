import re
import json
import argparse
import os

def listFromStr(str):
    pattern = r'\[([\d\s,]+)\]'
    matches = re.findall(pattern, str)
    if matches:
        numbers_str = matches[0]
        numbers = [num.strip() for num in numbers_str.split(',')]
        return numbers
    
def numberFromStr(str):
    pattern = r'= (\d+)'
    matches = re.findall(pattern, str)
    if matches:
        return int(matches[0])
    else:
        return -1
    
    
parser = argparse.ArgumentParser(description="Generate JS files script")
parser.add_argument("--proof", required=True, help="Path to the proof file (.sol)")
parser.add_argument("--output_folder", required=True, help="Path to the output folder")
parser.add_argument("--public_inputs", required=True, help="Path to the public inputs file (.json)")
args = parser.parse_args()

proof_pattern = r'proofItems\[(\d+)\]\s*=\s*(\d+);'
queue_pattern = r'queueItems\[(\d+)\]\s*=\s*(\d+);'
root_pattern = r'uint256\s+root\s*=\s*(\d+);'
evalpoint_pattern = r'uint256\s+evalPoint\s*=\s*(\d+);'
stepSize_pattern = r'uint256\s+stepSize\s*=\s*(\d+);'
proofItems = []
queueItems = []
data1 =[]
data2 = []
i=0
j=0
root_arr = []
evalpoint_arr = []
stepsize_arr = []
a = 0
baseData = {}
extensionData = {}
compositionData = {}

gpsData = {}

with open(args.proof, 'r') as f:
    lines = f.readlines()

    for line in lines:

        match1 = re.search(proof_pattern, line)
        match2 = re.search(queue_pattern, line)
        match3 = re.search(root_pattern, line)
        match4 = re.search(evalpoint_pattern, line)
        match5 = re.search(stepSize_pattern, line)

        if 'baseTraceMerkleView' in line: baseData['baseTraceMerkleView'] = listFromStr(line)
        if 'baseTraceMerkleInitials' in line: baseData['baseTraceMerkleInitials'] = listFromStr(line)
        if 'baseTraceMerkleHeight' in line: baseData['baseTraceMerkleHeight'] = numberFromStr(line)
        if 'baseTraceMerkleRoot' in line: baseData['baseTraceMerkleRoot'] = numberFromStr(line)

        if 'extensionTraceMerkleView' in line: extensionData['extensionTraceMerkleView'] = listFromStr(line)
        if 'extensionTraceMerkleInitials' in line: extensionData['extensionTraceMerkleInitials'] = listFromStr(line)
        if 'extensionTraceMerkleHeight' in line: extensionData['extensionTraceMerkleHeight'] = numberFromStr(line)
        if 'extensionTraceMerkleRoot' in line: extensionData['extensionTraceMerkleRoot'] = numberFromStr(line)
        
        if 'compositionTraceMerkleView' in line: compositionData['compositionTraceMerkleView'] = listFromStr(line)
        if 'compositionTraceMerkleInitials' in line: compositionData['compositionTraceMerkleInitials'] = listFromStr(line)
        if 'compositionTraceMerkleHeight' in line: compositionData['compositionTraceMerkleHeight'] = numberFromStr(line)
        if 'compositionTraceMerkleRoot' in line: compositionData['compositionTraceMerkleRoot'] = numberFromStr(line)
        
        if 'proofParams' in line: gpsData['proofParams'] = listFromStr(line)
        if 'proof = [' in line: gpsData['proof'] = listFromStr(line)
        if 'cairoAuxInput' in line: gpsData['cairoAuxInput'] = listFromStr(line)
        if match1:
            index = int(match1.group(1))  
            value = match1.group(2)           
            if index < i:
                proofItems.append(data1)
                data1 = []
                i = 0
                a +=1
            else:
                i = index
            if a == 5:
                proofItems.append(data1)
            data1.append(value)
        if match2:
            index = int(match2.group(1)) 
            value = match2.group(2)          
            if index < j:
                queueItems.append(data2)
                data2 = []
                j = 0
            else:
                j = index
            if a == 5 :
                queueItems.append(data2)
            data2.append(value)
        if match3: root_arr.append(match3.group(1))
        if match4: evalpoint_arr.append(match4.group(1))
        if match5: stepsize_arr.append(match5.group(1))
        
          
merkleHeader = """
const { ethers } = require("ethers");
const myContractABI = require("./merkle.json");
const HttpProvider = "https://rpc.ankr.com/eth_sepolia";
require("dotenv").config();
const privateKey = "";
async function main() {
  try {
    const provider = new ethers.providers.JsonRpcProvider(HttpProvider);
    const signer = new ethers.Wallet(privateKey, provider);
    const contractAddress = "0xe23195D7359297Be8d89F37a06240D63E527B623";
    const contract = new ethers.Contract(
      contractAddress,
      myContractABI,
      signer
    );
"""
fri_header = """
const { ethers } = require("ethers");
const myContractABI = require("./fri.json");

const HttpProvider = "https://rpc.ankr.com/eth_sepolia";

require("dotenv").config();
const privateKey = "";

async function main() {
try {
    const provider = new ethers.providers.JsonRpcProvider(HttpProvider);
    const signer = new ethers.Wallet(privateKey, provider);

    const contractAddress = "0x757c47a259FC8d3d4fDB53db53972C1B207976C1";

    const contract = new ethers.Contract(
    contractAddress,
    myContractABI,
    signer
    );
"""

fri_footer = """
const txn = await contract.verifyFRI(
    proofItems,
    queueItems,
    evalPoint,
    stepSize,
    root
);

    await txn.wait();
    console.log("Mined -- ", txn.hash);

    // web3.eth.sendSignedTransaction((await signedTransaction).rawTransaction);
  } catch (error) {
    console.log("Connection Error! ", error);
  }
}

main();
"""
gpsHeader = """
const { ethers } = require("ethers");
const myContractABI = require("./gps.json");
const HttpProvider = "https://rpc.ankr.com/eth_sepolia";
require("dotenv").config();
const privateKey = "";
async function main() {
  try {
    const provider = new ethers.providers.JsonRpcProvider(HttpProvider);
    const signer = new ethers.Wallet(privateKey, provider);
    const contractAddress = "0x46b18558a21Ce1B49166D5ab23B22D315bE2E591";
    const contract = new ethers.Contract(
      contractAddress,
      myContractABI,
      signer
    );
"""

# Merkle templates
baseTemplate = """
    baseTraceMerkleView = {baseTraceMerkleView};
    baseTraceMerkleInitials = {baseTraceMerkleInitials};
    baseTraceMerkleHeight = {baseTraceMerkleHeight};
    baseTraceMerkleRoot = "{baseTraceMerkleRoot}";
    const txn = await contract.verifyMerkle(
      baseTraceMerkleView,
      baseTraceMerkleInitials,
      baseTraceMerkleHeight,
      baseTraceMerkleRoot
    );
""".format(**baseData)


extensionTemplate = """
    extensionTraceMerkleView = {extensionTraceMerkleView};
    extensionTraceMerkleInitials = {extensionTraceMerkleInitials};
    extensionTraceMerkleHeight = {extensionTraceMerkleHeight};
    extensionTraceMerkleRoot = "{extensionTraceMerkleRoot}";
    const txn = await contract.verifyMerkle(
      extensionTraceMerkleView,
      extensionTraceMerkleInitials,
      extensionTraceMerkleHeight,
      extensionTraceMerkleRoot
    );
""".format(**extensionData)


compositionTemplate = """
    compositionTraceMerkleView = {compositionTraceMerkleView};
    compositionTraceMerkleInitials = {compositionTraceMerkleInitials};
    compositionTraceMerkleHeight = {compositionTraceMerkleHeight};
    compositionTraceMerkleRoot = "{compositionTraceMerkleRoot}";
    const txn = await contract.verifyMerkle(
      compositionTraceMerkleView,
      compositionTraceMerkleInitials,
      compositionTraceMerkleHeight,
      compositionTraceMerkleRoot
    );
""".format(**compositionData)

# Gps Templates
gpsBodyTemplate = """
    proofParams = {proofParams};
    
    proof = {proof};
    
    cairoAuxInput = {cairoAuxInput};
    
""".format(**gpsData)


with open(args.public_inputs, 'r') as f:
    publicMemoryData =[str(i) for i in list(json.load(f).values())[-3:]]


gpsFooterTemplate = """
    publicMemoryData = {0};
    
""".format(publicMemoryData)

# Footers
merkleFooter = """
    await txn.wait();
    console.log("Mined -- ", txn.hash);
    // web3.eth.sendSignedTransaction((await signedTransaction).rawTransaction);
  } catch (error) {
    console.log("Connection Error! ", error);
  }
}
main();
"""

gpsFooter = """
    cairoVerifierId = 6;
    const txn = await contract.verifyProofAndRegister(
      proofParams,
      proof,
      cairoAuxInput,
      cairoVerifierId,
      publicMemoryData
    );
    await txn.wait();
    console.log("Mined -- ", txn.hash);
    // web3.eth.sendSignedTransaction((await signedTransaction).rawTransaction);
  } catch (error) {
    console.log("Connection Error! ", error);
  }
}
main();
"""


merkleDataList = [baseTemplate, extensionTemplate, compositionTemplate]

# Making output folder if doesn't exist
if not os.path.exists(args.output_folder):
    os.makedir(args.output_folder)

# Merkle Files
for i in range(3):
    file = os.path.join(args.output_folder, f'merkle{i+1}.js')
    with open(file, 'w') as f:
        f.write(merkleHeader + merkleDataList[i] + merkleFooter)

# Gps File
gpsFile = os.path.join(args.output_folder, "gps.js")
with open(gpsFile, 'w') as f:
    f.write(gpsHeader + gpsBodyTemplate + gpsFooterTemplate + gpsFooter)

# FRI Files
for i in range(6):
    frifile = os.path.join(args.output_folder, f'fri{i+1}.js')
    with open(frifile, 'w') as f:
        f.write(fri_header)
        f.write(f'proofItems = []\n')
        for j in range(len(proofItems[i])):
            f.write(f'proofItems[{j}] = "{proofItems[i][j]}";\n')
        f.write(f'queueItems = []\n')
        for j in range(len(queueItems[i])):
            f.write(f'queueItems[{j}] = "{queueItems[i][j]}";\n')
        f.write(f' root ="{root_arr[i]}";\n')
        f.write(f' evalPoint ="{evalpoint_arr[i]}";\n')
        f.write(f' stepSize ="{stepsize_arr[i]}";\n')
        f.write(fri_footer)

###     Saving the data to binary files in 'blobs'
'''
Format:
1st 32 bytes: Number of FRI blobs
2nd 32 bytes: Number of Merkle blobs
3rd 32 bytes: Number of GPS blobs

----------------- Each blobs -----------------
1st 32 bytes: Length of each blob
3nd to (N+1)th 32 bytes: Length of each array item
- Array items
- individual items

-- Next blob --
'''

f = open(os.path.join(args.output_folder, f'blob.bin'), 'wb')
f.write(int(6).to_bytes(32, byteorder='big')) # Number of FRI blobs
f.write(int(3).to_bytes(32, byteorder='big')) # Number of Merkle blobs
f.write(int(1).to_bytes(32, byteorder='big')) # Number of GPS blobs

# FRI blobs
for i in range(6):
    f.write((int(len(proofItems[i]) + len(queueItems[i]) + 5)*32).to_bytes(32, byteorder='big')) # No of items
    f.write(int(len(proofItems[i])).to_bytes(32, byteorder='big')) # Length of proofItems
    f.write(int(len(queueItems[i])).to_bytes(32, byteorder='big')) # Length of queueItems
    for j in range(len(proofItems[i])):
        f.write(int(proofItems[i][j]).to_bytes(32, byteorder='big'))
    for j in range(len(queueItems[i])):
        f.write(int(queueItems[i][j]).to_bytes(32, byteorder='big'))
    f.write(int(evalpoint_arr[i]).to_bytes(32, byteorder='big'))
    f.write(int(stepsize_arr[i]).to_bytes(32, byteorder='big'))
    f.write(int(root_arr[i]).to_bytes(32, byteorder='big'))

# Merkle blobs
MerkelblobFiles = ['merkel1Blob_base.bin', 'merkel2Blob_extension.bin', 'merkel3Blob_composition.bin']
MerkelViews = ['base', 'extension', 'composition']
merkleDataList = [baseData, extensionData, compositionData]
for i in range(3):
    f.write(int((len(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleView')])
                + len(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleInitials')])
                + 4) * 32).to_bytes(32, byteorder='big')) # No of items
    f.write(int(len(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleView')])).to_bytes(32, byteorder='big')) # Length of traceMerkleView
    f.write(int(len(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleInitials')])).to_bytes(32, byteorder='big')) # Length of traceMerkleInitials
    for j in range(len(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleView')])):
        f.write(int(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleView')][j]).to_bytes(32, byteorder='big'))
    for j in range(len(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleInitials')])):
        f.write(int(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleInitials')][j]).to_bytes(32, byteorder='big'))
    f.write(int(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleHeight')]).to_bytes(32, byteorder='big'))
    f.write(int(merkleDataList[i][str(MerkelViews[i] + 'TraceMerkleRoot')]).to_bytes(32, byteorder='big'))

# GPS blobs
f.write(int((len(gpsData['proofParams']) + len(gpsData['proof']) + len(gpsData['cairoAuxInput']) + len(publicMemoryData) + 5) * 32).to_bytes(32, byteorder='big')) # No of items
f.write(int(len(gpsData['proofParams'])).to_bytes(32, byteorder='big')) # Length of proofParams
f.write(int(len(gpsData['proof'])).to_bytes(32, byteorder='big')) # Length of proof
f.write(int(len(gpsData['cairoAuxInput'])).to_bytes(32, byteorder='big')) # Length of cairoAuxInput
f.write(int(len(publicMemoryData)).to_bytes(32, byteorder='big')) # Length of publicMemoryData
for j in range(len(gpsData['proofParams'])):
    f.write(int(gpsData['proofParams'][j]).to_bytes(32, byteorder='big'))
for j in range(len(gpsData['proof'])):
    f.write(int(gpsData['proof'][j]).to_bytes(32, byteorder='big'))
for j in range(len(gpsData['cairoAuxInput'])):
    f.write(int(gpsData['cairoAuxInput'][j]).to_bytes(32, byteorder='big'))
for j in range(len(publicMemoryData)):
    f.write(int(publicMemoryData[j]).to_bytes(32, byteorder='big'))
f.write(int(6).to_bytes(32, byteorder='big')) # cairoVerifierId
