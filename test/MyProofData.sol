// SPDX-License-Identifier: Apache-2.0.
pragma solidity >=0.6.12;

contract MyProofData {
    function getProofParams() public view returns (uint256[] memory) {
        return proofParams;
    }

    function getProof() public view returns (uint256[] memory) {
        return proof;
    }

    function getTaskMetadata() public view returns (uint256[] memory) {
        return taskMetadata;
    }

    function getCairoAuxInput() public view returns (uint256[] memory) {
        return cairoAuxInput;
    }

    uint256 public cairoVerifierId = 6;

    uint256[] public proofParams = [0];

    uint256[] public proof = [0];

    uint256[] public taskMetadata = [0];

    uint256[] public cairoAuxInput = [0];

    uint256[] public program = [0];
}
