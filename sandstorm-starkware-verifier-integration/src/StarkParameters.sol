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
// ---------- The following code was auto-generated. PLEASE DO NOT EDIT. ----------
// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "./PrimeFieldElement0.sol";

contract StarkParameters is PrimeFieldElement0 {
    uint256 internal constant N_COEFFICIENTS = 195;
    uint256 internal constant N_INTERACTION_ELEMENTS = 6;
    uint256 internal constant MASK_SIZE = 269;
    uint256 internal constant N_ROWS_IN_MASK = 191;
    uint256 internal constant N_COLUMNS_IN_MASK = 10;
    uint256 internal constant N_COLUMNS_IN_TRACE0 = 9;
    uint256 internal constant N_COLUMNS_IN_TRACE1 = 1;
    uint256 internal constant CONSTRAINTS_DEGREE_BOUND = 2;
    uint256 internal constant N_OODS_VALUES =
        MASK_SIZE + CONSTRAINTS_DEGREE_BOUND;
    uint256 internal constant N_OODS_COEFFICIENTS = N_OODS_VALUES;

    // ---------- // Air specific constants. ----------
    uint256 internal constant PUBLIC_MEMORY_STEP = 8;
    uint256 internal constant DILUTED_SPACING = 4;
    uint256 internal constant DILUTED_N_BITS = 16;
    uint256 internal constant PEDERSEN_BUILTIN_RATIO = 32;
    uint256 internal constant PEDERSEN_BUILTIN_REPETITIONS = 1;
    uint256 internal constant RC_BUILTIN_RATIO = 16;
    uint256 internal constant RC_N_PARTS = 8;
    uint256 internal constant ECDSA_BUILTIN_RATIO = 2048;
    uint256 internal constant ECDSA_BUILTIN_REPETITIONS = 1;
    uint256 internal constant BITWISE__RATIO = 64;
    uint256 internal constant EC_OP_BUILTIN_RATIO = 1024;
    uint256 internal constant EC_OP_SCALAR_HEIGHT = 256;
    uint256 internal constant EC_OP_N_BITS = 252;
    uint256 internal constant POSEIDON__RATIO = 32;
    uint256 internal constant POSEIDON__M = 3;
    uint256 internal constant POSEIDON__ROUNDS_FULL = 8;
    uint256 internal constant POSEIDON__ROUNDS_PARTIAL = 83;
    uint256 internal constant LAYOUT_CODE = 8319381555716711796;
    uint256 internal constant LOG_CPU_COMPONENT_HEIGHT = 4;
}
// ---------- End of auto-generated code. ----------
