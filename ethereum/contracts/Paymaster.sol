// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "./library/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Paymaster {

    using ECDSA for bytes32;

    uint256 public constant SIG_VALIDATION_FAILED = 1;
    uint256 public constant NONCE_VALIDATION_FAILED = 2;
    uint256 public constant VALIDATION_SUCCESS = 0;

    address public owner;
    address public verifyingSigner;
    address public supportedEntryPoint;

    constructor(
        address _verifyingSigner,
        address _owner,
        address _supportedEntryPoint
    ) {
        verifyingSigner = _verifyingSigner;
        owner = _owner;
        supportedEntryPoint = _supportedEntryPoint;
    }

    /**
     * Suppose that the user wants to execute an operation on the supported entry point. 
     * paymasterAndData[:20] : address(this)
     * paymasterAndData[20:] : signature
     * @param userOp The user operation to validate
     */
    function validatePaymasterOp(UserOperation calldata userOp) public view returns (bytes memory, uint256) {
        // uint256 sigTime = uint256(bytes32(userOp.paymasterAndData[20:52]));

        if (
            verifyingSigner !=
            getHash(userOp).toEthSignedMessageHash().recover(
                userOp.paymasterAndData[20:]
            ) 
            // getHash(userOp, sigTime).toEthSignedMessageHash().recover(
            //     userOp.paymasterAndData[52:]
            // )
        ) {
            return ("", SIG_VALIDATION_FAILED);
        } else {
            return ("", VALIDATION_SUCCESS);
        }
    }

    function getHash(UserOperation memory userOp)
    public view returns (bytes32) {
        return keccak256(
                abi.encode(
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.callGasLimit,
                    userOp.verificationGasLimit,
                    userOp.preVerificationGas,
                    userOp.maxFeePerGas,
                    userOp.maxPriorityFeePerGas,
                    block.chainid,
                    address(this)
                )
            );
    }
}