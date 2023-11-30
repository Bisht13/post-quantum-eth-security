/*
  Copyright 2019-2022 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../CpuPublicInputOffsetsBase.sol";

contract CpuPublicInputOffsets is CpuPublicInputOffsetsBase {
    // The following constants are offsets of data expected in the public input.
    uint256 internal constant OFFSET_ECDSA_BEGIN_ADDR = 14;
    uint256 internal constant OFFSET_ECDSA_STOP_PTR = 15;
    uint256 internal constant OFFSET_BITWISE_BEGIN_ADDR = 16;
    uint256 internal constant OFFSET_BITWISE_STOP_ADDR = 17;
    uint256 internal constant OFFSET_EC_OP_BEGIN_ADDR = 18;
    uint256 internal constant OFFSET_EC_OP_STOP_ADDR = 19;
    uint256 internal constant OFFSET_POSEIDON_BEGIN_ADDR = 20;
    uint256 internal constant OFFSET_POSEIDON_STOP_PTR = 21;
    uint256 internal constant OFFSET_PUBLIC_MEMORY_PADDING_ADDR = 22;
    uint256 internal constant OFFSET_PUBLIC_MEMORY_PADDING_VALUE = 23;
    uint256 internal constant OFFSET_N_PUBLIC_MEMORY_PAGES = 24;
    uint256 internal constant OFFSET_PUBLIC_MEMORY = 25;
}
