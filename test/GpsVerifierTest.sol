// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.12; // test

import "../contracts/verifier/CpuConstraintPoly.sol";
import "../contracts/periodic_columns/PoseidonPoseidonFullRoundKey0Column.sol";
import "../contracts/periodic_columns/PoseidonPoseidonFullRoundKey1Column.sol";
import "../contracts/periodic_columns/PoseidonPoseidonFullRoundKey2Column.sol";
import "../contracts/periodic_columns/PoseidonPoseidonPartialRoundKey0Column.sol";
import "../contracts/periodic_columns/PoseidonPoseidonPartialRoundKey1Column.sol";
import "../contracts/periodic_columns/EcdsaPointsXColumn.sol";
import "../contracts/periodic_columns/EcdsaPointsYColumn.sol";
import "../contracts/periodic_columns/PedersenHashPointsXColumn.sol";
import "../contracts/periodic_columns/PedersenHashPointsYColumn.sol";
import "../contracts/gps/CairoBootloaderProgram.sol";
import "../contracts/verifier/FriStatementVerifier.sol";
import "../contracts/verifier/CpuFrilessVerifier.sol";
import "../contracts/MemoryPageFactRegistry.sol";
import "../contracts/verifier/FriStatementContract.sol";
import "../contracts/verifier/VerifierChannel.sol";
import "../contracts/CpuOods.sol";
import "../contracts/gps/GpsStatementVerifier.sol";
import "./ProofData.sol";
import "./AutoGenProofData.sol";

contract StarkNetVerifierTest {
    uint256 numSecurityBits = 96;
    uint256 minProofOfWorkBits = 30;
    CpuConstraintPoly public cpuConstraintPoly;
    PedersenHashPointsXColumn pedersenPointsX;
    PedersenHashPointsYColumn pedersenPointsY;
    EcdsaPointsXColumn ecdsaPointsX;
    EcdsaPointsYColumn ecdsaPointsY;
    PoseidonPoseidonFullRoundKey0Column poseidonPoseidonFullRoundKey0Column;
    PoseidonPoseidonFullRoundKey1Column poseidonPoseidonFullRoundKey1Column;
    PoseidonPoseidonFullRoundKey2Column poseidonPoseidonFullRoundKey2Column;
    PoseidonPoseidonPartialRoundKey0Column poseidonPoseidonPartialRoundKey0Column;
    PoseidonPoseidonPartialRoundKey1Column poseidonPoseidonPartialRoundKey1Column;
    address[] public auxPolynomials;
    MemoryPageFactRegistry public memoryPageFactRegistry;
    MerkleStatementContract public merkleStatementContract;
    FriStatementContract public friStatementContract;
    FriStatementVerifier public friStatementVerifier;
    CpuOods cpuOods;
    CpuFrilessVerifier public cpuFrilessVerifier;

    CairoBootloaderProgram public bootloaderProgram;
    address[] public cairoVerifierContracts;
    uint256 hashedSupportedCairoVerifiers;
    uint256 simpleBootloaderProgramHash;
    GpsStatementVerifier public gpsStatementVerifier;

    uint256[] public publicMemoryData;

    function setUp() public {
        // TODO: find out what the MemoryPageFactRegistry does
        memoryPageFactRegistry = new MemoryPageFactRegistry();
        merkleStatementContract = new MerkleStatementContract();
        friStatementContract = new FriStatementContract();
        cpuOods = new CpuOods();
        // TODO: find the coefficients for this polynomial
        cpuConstraintPoly = new CpuConstraintPoly();
        pedersenPointsX = new PedersenHashPointsXColumn();
        pedersenPointsY = new PedersenHashPointsYColumn();
        ecdsaPointsX = new EcdsaPointsXColumn();
        ecdsaPointsY = new EcdsaPointsYColumn();
        poseidonPoseidonFullRoundKey0Column = new PoseidonPoseidonFullRoundKey0Column();
        poseidonPoseidonFullRoundKey1Column = new PoseidonPoseidonFullRoundKey1Column();
        poseidonPoseidonFullRoundKey2Column = new PoseidonPoseidonFullRoundKey2Column();
        poseidonPoseidonPartialRoundKey0Column = new PoseidonPoseidonPartialRoundKey0Column();
        poseidonPoseidonPartialRoundKey1Column = new PoseidonPoseidonPartialRoundKey1Column();
        auxPolynomials = [
            address(cpuConstraintPoly),
            address(pedersenPointsX),
            address(pedersenPointsY),
            address(ecdsaPointsX),
            address(ecdsaPointsY),
            address(poseidonPoseidonFullRoundKey0Column),
            address(poseidonPoseidonFullRoundKey1Column),
            address(poseidonPoseidonFullRoundKey2Column),
            address(poseidonPoseidonPartialRoundKey0Column),
            address(poseidonPoseidonPartialRoundKey1Column)
        ];
        cpuFrilessVerifier = new CpuFrilessVerifier(
            auxPolynomials,
            address(cpuOods),
            address(memoryPageFactRegistry),
            address(merkleStatementContract),
            address(friStatementContract),
            numSecurityBits,
            minProofOfWorkBits
        );

        bootloaderProgram = new CairoBootloaderProgram();
        // TODO: what are these? Maybe ask Starkware for the pre-images
        hashedSupportedCairoVerifiers = 3178097804922730583543126053422762895998573737925004508949311089390705597156;
        // hashedSupportedCairoVerifiers = 37341341331504021525228390428349719127283617351070997452015539964478373189;
        simpleBootloaderProgramHash = 2962621603719000361370283216422448934312521782617806945663080079725495842070;
        // TODO: in reality these addresses map to different verifiers
        // For the sake of simplicity have the same amount of verifiers
        // as the on-chain contract but have them be all the same address
        cairoVerifierContracts = [
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier),
            address(cpuFrilessVerifier)
        ];
        gpsStatementVerifier = new GpsStatementVerifier(
            address(bootloaderProgram),
            address(memoryPageFactRegistry),
            cairoVerifierContracts,
            hashedSupportedCairoVerifiers,
            simpleBootloaderProgramHash
        );
    }

    function testVerify() public {
        // ProofData proofData = new ProofData();
        AutoGenProofData proofData = new AutoGenProofData();

        // register merkle statements
        // 1. base trace
        merkleStatementContract.verifyMerkle(
            proofData.getBaseTraceMerkleView(),
            proofData.getBaseTraceMerkleInitials(),
            proofData.baseTraceMerkleHeight(),
            proofData.baseTraceMerkleRoot()
        );
        // 2. extension trace
        merkleStatementContract.verifyMerkle(
            proofData.getExtensionTraceMerkleView(),
            proofData.getExtensionTraceMerkleInitials(),
            proofData.extensionTraceMerkleHeight(),
            proofData.extensionTraceMerkleRoot()
        );
        // 2. composition trace
        merkleStatementContract.verifyMerkle(
            proofData.getCompositionTraceMerkleView(),
            proofData.getCompositionTraceMerkleInitials(),
            proofData.compositionTraceMerkleHeight(),
            proofData.compositionTraceMerkleRoot()
        );

        // register fri layer statements
        FriDataLayer[] memory friDataLayers = proofData.getFriDataLayers();
        for (uint i = 0; i < friDataLayers.length; i++) {
            FriDataLayer friDataLayer = friDataLayers[i];
            friStatementContract.verifyFRI(
                friDataLayer.getProof(),
                friDataLayer.getQueue(),
                friDataLayer.evalPoint(),
                friDataLayer.stepSize(),
                friDataLayer.root()
            );
        }

        uint256 publicInputNonce = 2;
        uint256 publicInputHashLow = 0xaea8ed2e203f7d1a8f3e4ca5155d8a33;
        uint256 publicInputHashHigh = 0xf3b0189f6aaff24aee6f0562526781bf;

        publicMemoryData = [
            publicInputNonce,
            publicInputHashLow,
            publicInputHashHigh
        ];

        gpsStatementVerifier.verifyProofAndRegister(
            proofData.getProofParams(),
            proofData.getProof(),
            proofData.getCairoAuxInput(),
            proofData.cairoVerifierId(),
            publicMemoryData
        );
    }
}
