// SPDX-License-Identifier: Apache-2.0.
pragma solidity >=0.6.12;

contract PublicInputGen {
    function getData(
        address yourAddress,
        uint256 nonce
    ) public pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(uint256(uint160(yourAddress)), nonce));
    }
}
