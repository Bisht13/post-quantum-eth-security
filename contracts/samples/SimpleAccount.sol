// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../core/BaseAccount.sol";
import "./callback/TokenCallbackHandler.sol";

interface IMerkleStatementContract {
    function verifyMerkle(
        uint256[] memory merkleView,
        uint256[] memory initialMerkleQueue,
        uint256 height,
        uint256 expectedRoot
    ) external;
}

interface IFriStatementContract {
    function verifyFRI(
        uint256[] memory proof,
        uint256[] memory friQueue,
        uint256 evaluationPoint,
        uint256 friStepSize,
        uint256 expectedRoot
    ) external;
}

interface IGpsStatementVerifier {
    function verifyProofAndRegister(
        uint256[] calldata proofParams,
        uint256[] calldata proof,
        uint256[] calldata cairoAuxInput,
        uint256 cairoVerifierId,
        uint256[] calldata publicMemoryData
    ) external;
}

/**
 * minimal account.
 *  this is sample minimal account.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract SimpleAccount is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable
{
    struct Merkle {
        uint256[] View;
        uint256[] Initials;
        uint256 height;
        uint256 root;
    }

    struct Fri {
        uint256[] proofItems;
        uint256[] queueItems;
        uint256 evalPoint;
        uint256 stepSize;
        uint256 root;
    }

    struct GPS {
        uint256[] proofParams;
        uint256[] proof;
        uint256[] cairoAuxInput;
        uint256[] publicMemoryData;
        uint256 cairoVerifierId;
    }

    using ECDSA for bytes32;

    address public owner;

    IEntryPoint private immutable _entryPoint;

    event SimpleAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    // address merkleStatementContractAddress;
    // address friStatementContractAddress;
    // address gpsStatementVerifierAddress;

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
        // merkleStatementContractAddress = 0x88dB8a45622716071D822c6a3Cec5fe06Eff1c09;
        // friStatementContractAddress = 0x757c47a259FC8d3d4fDB53db53972C1B207976C1;
        // gpsStatementVerifierAddress = 0x7FE523743a8f002e9D64a1ccaFCDfcfA16fEb6b3;
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            msg.sender == owner || msg.sender == address(this),
            "only owner"
        );
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        require(
            dest.length == func.length &&
                (value.length == 0 || value.length == func.length),
            "wrong array lengths"
        );
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit SimpleAccountInitialized(_entryPoint, owner);
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner,
            "account: not Owner or EntryPoint"
        );
    }

    /// implement template method of BaseAccount
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                userOp.sender,
                userOp.nonce,
                userOp.initCode,
                userOp.paymasterAndData
            )
        );

        uint256 txnId = uint256(uint256(userOp.nonce) % 10);
        if (txnId == 0 || txnId == 1 || txnId == 2) {
            Merkle memory merkle = giveMerkle(userOp.signature);
            // Update this address with your own
            IMerkleStatementContract(0xe23195D7359297Be8d89F37a06240D63E527B623)
                .verifyMerkle(
                    merkle.View,
                    merkle.Initials,
                    merkle.height,
                    merkle.root
                );
        } else if (
            txnId == 3 ||
            txnId == 4 ||
            txnId == 5 ||
            txnId == 6 ||
            txnId == 7 ||
            txnId == 8
        ) {
            Fri memory fri = giveFRI(userOp.signature);
            // Update this address with your own
            IFriStatementContract(0xA906Cb4c5ed10292f8701cFB57F1ED3a652E35B6)
                .verifyFRI(
                    fri.proofItems,
                    fri.queueItems,
                    fri.evalPoint,
                    fri.stepSize,
                    fri.root
                );
        } else if (txnId == 9) {
            GPS memory gps = giveGPS(userOp.signature);
            uint256[] memory publicInput = new uint256[](3);
            publicInput[0] = uint256(uint160(owner));
            bytes16 first;
            bytes16 second;
            (first, second) = bytes32Break(hash);
            publicInput[1] = uint256(uint128(first));
            publicInput[2] = uint256(uint128(second));
            // Update this address with your own
            IGpsStatementVerifier(0x05525aD1F2238b328b94534a3ADA88ee7f192155)
                .verifyProofAndRegister(
                    gps.proofParams,
                    gps.proof,
                    gps.cairoAuxInput,
                    gps.cairoVerifierId,
                    publicInput
                );
        }
        return 0;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }

    function giveFRI(bytes memory data) public pure returns (Fri memory) {
        // initialize len of proofItems and queueItems
        uint32 noProofItems = uint32(bytesToUint(slice(data, 0, 32)));
        uint32 noQueueItems = uint32(bytesToUint(slice(data, 32, 32)));

        // initialize FRI struct
        uint256[] memory proofItems = new uint256[](noProofItems);
        uint256[] memory queueItems = new uint256[](noQueueItems);

        // populate proofItems
        for (uint256 i = 0; i < noProofItems; i++) {
            proofItems[i] = bytesToUint(slice(data, i * 32 + 64, 32));
        }

        // populate queueItems
        for (uint256 i = 0; i < noQueueItems; i++) {
            queueItems[i] = bytesToUint(
                slice(data, i * 32 + 64 + noProofItems * 32, 32)
            );
        }

        // populate evalPoint
        uint256 evalPoint = bytesToUint(
            slice(data, noProofItems * 32 + noQueueItems * 32 + 64, 32)
        );

        // populate stepSize
        uint256 stepSize = bytesToUint(
            slice(data, noProofItems * 32 + noQueueItems * 32 + 64 + 32, 32)
        );

        // populate root
        uint256 root = bytesToUint(
            slice(data, noProofItems * 32 + noQueueItems * 32 + 64 + 64, 32)
        );

        return Fri(proofItems, queueItems, evalPoint, stepSize, root);
    }

    function giveMerkle(bytes memory data) public pure returns (Merkle memory) {
        uint32 noView = uint32(bytesToUint(slice(data, 0, 32)));
        uint32 noInitials = uint32(bytesToUint(slice(data, 32, 32)));

        uint256[] memory View = new uint256[](noView);
        uint256[] memory initials = new uint256[](noInitials);

        // populate view
        for (uint256 i = 0; i < noView; i++) {
            View[i] = bytesToUint(slice(data, i * 32 + 64, 32));
        }

        // populate initials
        for (uint256 i = 0; i < noInitials; i++) {
            initials[i] = bytesToUint(
                slice(data, i * 32 + 64 + noView * 32, 32)
            );
        }

        // populate height
        uint256 height = bytesToUint(
            slice(data, noView * 32 + noInitials * 32 + 64, 32)
        );

        // populate root
        uint256 root = bytesToUint(
            slice(data, noView * 32 + noInitials * 32 + 64 + 32, 32)
        );

        return Merkle(View, initials, height, root);
    }

    function giveGPS(bytes memory data) public pure returns (GPS memory) {
        uint32 noProofParams = uint32(bytesToUint(slice(data, 0, 32)));
        uint32 noProof = uint32(bytesToUint(slice(data, 32, 32)));
        uint32 noCairoAuxInput = uint32(bytesToUint(slice(data, 64, 32)));
        uint32 noPublicMemoryData = uint32(bytesToUint(slice(data, 96, 32)));
        uint32 currLen = 0;

        uint256[] memory proofParams = new uint256[](noProofParams);
        uint256[] memory proof = new uint256[](noProof);
        uint256[] memory cairoAuxInput = new uint256[](noCairoAuxInput);
        uint256[] memory publicMemoryData = new uint256[](noPublicMemoryData);

        // populate proofParams
        for (uint256 i = 0; i < noProofParams; i++) {
            proofParams[i] = bytesToUint(slice(data, i * 32 + 128, 32));
        }

        currLen = 128 + noProofParams * 32;

        // populate proof
        for (uint256 i = 0; i < noProof; i++) {
            proof[i] = bytesToUint(slice(data, i * 32 + currLen, 32));
        }

        currLen += noProof * 32;

        // populate cairoAuxInput
        for (uint256 i = 0; i < noCairoAuxInput; i++) {
            cairoAuxInput[i] = bytesToUint(slice(data, i * 32 + currLen, 32));
        }

        currLen += noCairoAuxInput * 32;

        // populate publicMemoryData
        for (uint256 i = 0; i < noPublicMemoryData; i++) {
            publicMemoryData[i] = bytesToUint(
                slice(data, i * 32 + currLen, 32)
            );
        }

        currLen += noPublicMemoryData * 32;

        // populate cairoVerifierId
        uint256 cairoVerifierId = bytesToUint(slice(data, currLen, 32));

        return
            GPS(
                proofParams,
                proof,
                cairoAuxInput,
                publicMemoryData,
                cairoVerifierId
            );
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_start + _length <= _bytes.length, "Invalid slice parameters");
        bytes memory result = new bytes(_length);
        for (uint256 i = 0; i < _length; i++) {
            result[i] = _bytes[_start + i];
        }
        return result;
    }

    function bytesToUint(bytes memory data) public pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < data.length; i++) {
            result = result * 256 + uint8(data[i]);
        }
        return result;
    }

    function bytes32Break(bytes32 source) public returns (bytes16, bytes16) {
        bytes16[2] memory y = [bytes16(0), 0];
        assembly {
            mstore(y, source)
            mstore(add(y, 16), source)
        }
        return (y[0], y[1]);
    }
}
