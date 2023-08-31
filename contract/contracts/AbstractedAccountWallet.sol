// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./library/UserOperation.sol";

contract AbstractedAccountWallet {

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
        require(msg.sender == entryPoint, "Only EntryPoint can call this function");
        _;
    }

    // Function to validate a user-defined operation
    function validateOp(UserOperation memory op, uint256 requiredPayment) public {
        require(op.nonce == nonce, "Invalid nonce");

        address recoveredAddress = recoverSigner(op);
        require(recoveredAddress == owner, "Invalid signature");

        // Send requiredPayment to EntryPoint
        payable(entryPoint).transfer(requiredPayment);
    }

    // Function to execute a user-defined operation
    function executeOp(UserOperation memory op) public onlyOwner onlyEntryPoint {
        require(op.nonce == nonce, "Invalid nonce");
        nonce++;

        address recoveredAddress = recoverSigner(op);
        require(recoveredAddress == owner, "Invalid signature");

        (bool success, bytes memory returnData) = op.sender.call{value: op.value, gas: op.gas}(op.data);
        require(success, "Operation failed");

        emit ExecutedOperation(op.sender, op.value, returnData);
    }

    // Function to recover the signer of an operation
    function recoverSigner(UserOperation memory op) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encode(op.sender, op.data, op.value, op.gas, op.nonce));
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(op.signature);

        return ecrecover(messageHash, v, r, s);
    }

    // Function to split a signature into its components
    function splitSignature(bytes memory sig) internal pure returns (uint8, bytes32, bytes32) {
        require(sig.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }

        return (v, r, s);
    }
}
