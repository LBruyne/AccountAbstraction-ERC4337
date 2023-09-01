// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./library/UserOperation.sol";
import "./library/PostOpMode.sol";
import "./StakeManager.sol";

contract EntryPoint is StakeManager {
    uint256 public constant SIG_VALIDATION_FAILED = 1;
    uint256 public constant NONCE_VALIDATION_FAILED = 2;
    uint256 public constant VALIDATION_SUCCESS = 0;

    // event OperationHandled(address indexed wallet, uint256 gasUsed);

    function handleOps(UserOperation[] calldata ops) public {
        uint256 opslen = ops.length;
        // Validate and Execute all operations
        uint256 collected = 0;
        for (uint i = 0; i < opslen; i++) {
            uint256 gasUsed = handleOp(i, ops[i]);
            collected += gasUsed;
        }

        // Compensate the executor
        payable(msg.sender).transfer(collected);
    }

    function handleOp(
        uint256 opIndex,
        UserOperation calldata userOp
    ) public returns (uint256) {
        require(msg.sender == address(this), "Can only be called by handleOps");

        uint256 preGas = gasleft();
        uint256 gasUsed = 0;
        address paymaster = address(bytes20(userOp.paymasterAndData[:20]));

        // Calculate required payment
        // When using a Paymaster, the verificationGasLimit is used also to as a limit for the postOp call. The security model might call postOp eventually twice
        uint256 mul = (paymaster != address(0)) ? (1 + 2) : 1;
        uint256 requiredGas = userOp.callGasLimit +
            userOp.verificationGasLimit *
            mul +
            userOp.preVerificationGas;
        uint256 gasPrice = (userOp.maxFeePerGas == userOp.maxPriorityFeePerGas)
            ? userOp.maxFeePerGas
            : min(
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas + block.basefee
            );
        uint256 requiredPayment = requiredGas * gasPrice;
        // uint256 requiredPayment = userOp.gas * tx.gasprice;

        ///////////////////////
        // Validate operation
        ///////////////////////

        uint256 initialGas = gasleft();

        // Validate all numeric values in userOp are well below 128 bit, so they can safely be added and multiplied without causing overflow.
        // uint256 maxGasValues = mUserOp.preVerificationGas |
        //     mUserOp.verificationGasLimit |
        //     mUserOp.callGasLimit |
        //     userOp.maxFeePerGas |
        //     userOp.maxPriorityFeePerGas;
        // require(maxGasValues <= type(uint120).max, "AA94 gas values overflow");

        // If there is no paymaster, the sender should pay for the operation himself
        uint256 missingAccountFunds = 0;
        if (paymaster == address(0)) {
            uint256 bal = balanceOf(userOp.sender);
            missingAccountFunds = bal > requiredPayment
                ? 0
                : requiredPayment - bal;
        }

        // Validate the target account
        {
            (bool valid, bytes memory data) = userOp.sender.call(
                abi.encodeWithSignature(
                    "validateOp((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes), uint256)",
                    userOp,
                    missingAccountFunds
                )
            );
            require(valid, "Operation validation failed 1");
            uint256 result = abi.decode(data, (uint256));
            require(
                result == VALIDATION_SUCCESS,
                "Operation validation failed 2"
            );
        }
        // If there is no paymaster, the sender should pay for the operation himself
        if (paymaster == address(0)) {
            DepositInfo storage senderInfo = deposits[userOp.sender];
            uint256 deposit = senderInfo.deposit;
            require(requiredPayment <= deposit, "Insufficient sender deposit");
            senderInfo.deposit = uint112(deposit - requiredPayment);
        }
        gasUsed = initialGas - gasleft();
        require(
            gasUsed <= userOp.verificationGasLimit,
            "Verification gas limit exceeded"
        );

        // Validate the paymaster
        if (paymaster != address(0)) {
            uint256 gasToUse = userOp.verificationGasLimit - gasUsed;
            // Check paymaster deposits
            {
                DepositInfo storage paymasterInfo = deposits[paymaster];
                uint256 deposit = paymasterInfo.deposit;
                require(
                    deposit >= requiredPayment,
                    "Insufficient paymaster deposit"
                );
                paymasterInfo.deposit = uint112(deposit - requiredPayment);
            }
            // Check signature
            (bool success, bytes memory data1) = paymaster.call{gas: gasToUse}(
                abi.encodeWithSignature(
                    "validatePaymasterOp((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes))",
                    userOp
                )
            );
            require(success == true, "Paymaster validation failed 1");
            // context is used in postOp
            (bytes memory context, uint256 result) = abi.decode(
                data1,
                (bytes, uint256)
            );
            require(
                result == VALIDATION_SUCCESS,
                "Paymaster validation failed 2"
            );
        }

        ///////////////////////
        // Execute operation
        ///////////////////////

        initialGas = gasleft();

        // Execute the operation
        (bool success, ) = address(userOp.sender).call{
            gas: userOp.callGasLimit
        }(userOp.callData);
        require(success, "Operation execution failed");

        uint256 actualGas = preGas - gasleft() + userOp.preVerificationGas;
        return actualGas;
    }

    /*
     * In the Specification of ERC-4337, it describes:
     * It must guarantee the execution of postOp, by making the main execution inside an inner call context, and if the inner call context reverts attempting to call postOp again in an outer call context.
     * Must be declared "external" to open a call context, but it can only be called by handleOps.
     * @param userOp
     * @param context
     * @param preOpExecGasCost
     */
    // function innerCall(
    //     UserOperation calldata userOp,
    //     bytes calldata context,
    //     uint256 preOpExecGasCost
    // ) external returns (uint256 actualGasCost) {

    //     uint256 preGas = gasleft();
    //     require(msg.sender == address(this), "Can only be called by handleOps");

    //     PostOpMode mode;

    //     (bool success, ) = address(userOp.sender).call{
    //         gas: userOp.callGasLimit
    //     }(userOp.callData);
    //     if(success) {
    //         mode = PostOpMode.opReverted;
    //     } else {
    //         mode = PostOpMode.opSucceeded;
    //     }

    //     unchecked {
    //         return
    //             _handlePostOp(
    //                 mode,
    //                 context,
    //                 preGas - gasleft() + preOpExecGasCost
    //             );
    //     }
    // }

    // function _handlePostOp(
    //     PostOpMode mode,
    //     UserOperation memory userOp,
    //     bytes memory context,
    //     uint256 preGasCost
    // ) internal returns (uint256 actualGasCost) {
    //     uint256 preGas = gasleft();
    //     unchecked {
    //         address refundAddress;

    //         address paymaster = userOp.
    //         if (paymaster == address(0)) {
    //             refundAddress = userOp.sender;
    //         } else {
    //             refundAddress = paymaster;
    //             if (context.length > 0) {
    //                 actualGasCost = actualGas * gasPrice;
    //                 if (mode != IPaymaster.PostOpMode.postOpReverted) {
    //                     IPaymaster(paymaster).postOp{
    //                         gas: mUserOp.verificationGasLimit
    //                     }(mode, context, actualGasCost);
    //                 } else {
    //                     // solhint-disable-next-line no-empty-blocks
    //                     try
    //                         IPaymaster(paymaster).postOp{
    //                             gas: mUserOp.verificationGasLimit
    //                         }(mode, context, actualGasCost)
    //                     {} catch Error(string memory reason) {
    //                         revert FailedOp(opIndex, paymaster, reason);
    //                     } catch {
    //                         revert FailedOp(
    //                             opIndex,
    //                             paymaster,
    //                             "AA50 postOp revert"
    //                         );
    //                     }
    //                 }
    //             }
    //         }

    //         actualGas += preGas - gasleft();
    //         actualGasCost = actualGas * gasPrice;
    //         if (opInfo.prefund < actualGasCost) {
    //             revert FailedOp(
    //                 opIndex,
    //                 paymaster,
    //                 "AA51 prefund below actualGasCost"
    //             );
    //         }

    //         {
    //             uint256 refund = opInfo.prefund - actualGasCost;
    //             if (paymaster == address(0)) {
    //                 refundDeposit(payable(refundAddress), refund);
    //             } else {
    //                 internalIncrementDeposit(refundAddress, refund);
    //             }
    //         }

    //         emit UserOperationEvent(
    //             opInfo.userOpHash,
    //             mUserOp.sender,
    //             mUserOp.paymaster,
    //             mUserOp.nonce,
    //             mode == IPaymaster.PostOpMode.opSucceeded,
    //             actualGasCost,
    //             actualGas
    //         );
    //     } // unchecked
    // }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
