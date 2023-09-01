// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./library/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AbstractedAccountWallet {

    using ECDSA for bytes32;

    uint256 public constant SIG_VALIDATION_FAILED = 1;
    uint256 public constant NONCE_VALIDATION_FAILED = 2;
    uint256 public constant VALIDATION_SUCCESS = 0;

    address public owner;
    uint256 public nonce;
    address public entryPoint;

    // Events for logging important actions
    event ExecutedOperation(address indexed sender, uint256 value, bytes data);

    constructor(address _entryPoint) {
        owner = msg.sender;
        nonce = 0;
        entryPoint = _entryPoint;
    }

    // Modifier to check if the caller is the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(
            msg.sender == entryPoint,
            "Only EntryPoint can call this function"
        );
        _;
    }

    // Function to validate a user-defined operation
    function validateOp(
        UserOperation calldata op,
        uint256 requiredPayment
    ) public returns (uint256) {
        // Send requiredPayment to EntryPoint
        if (requiredPayment != 0) {
            payable(entryPoint).transfer(requiredPayment);
        }

        // Check nonce
        require(op.nonce == nonce++, "Invalid nonce");

        // Check signature
        if (
            owner !=
            getHash(op).toEthSignedMessageHash().recover(
                // op.signature[32:]
                op.signature
            )
        ) {
            return SIG_VALIDATION_FAILED;
        } else {
            // return uint256(bytes32(op.signature[0:32]));
            return VALIDATION_SUCCESS;
        }
    }

    // Function to execute a user-defined operation
    // function executeOp(
    //     UserOperation memory op
    // ) public onlyOwner onlyEntryPoint {
    //     require(op.nonce == nonce, "Invalid nonce");
    //     nonce++;

    //     // address recoveredAddress = recoverSigner(op);
    //     // require(recoveredAddress == owner, "Invalid signature");

    //     (bool success, bytes memory returnData) = op.sender.call{
    //         value: op.value,
    //         gas: op.gas
    //     }(op.data);
    //     require(success, "Operation failed");

    //     emit ExecutedOperation(op.sender, op.value, returnData);
    // }

    function getHash(
        UserOperation memory userOp
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    bytes32(block.chainid),
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.callGasLimit,
                    userOp.verificationGasLimit,
                    userOp.preVerificationGas,
                    userOp.maxFeePerGas,
                    userOp.maxPriorityFeePerGas,
                    keccak256(userOp.paymasterAndData),
                    entryPoint
                    // uint256(bytes32(userOp.signature[0:32]))
                )
            );
    }
}
