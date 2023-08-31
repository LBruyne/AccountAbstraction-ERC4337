// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./library/UserOperation.sol";
import "./StakeManager.sol";

contract EntryPoint is StakeManager {
    uint256 public constant SIG_VALIDATION_FAILED = 1;
    uint256 public constant NONCE_VALIDATION_FAILED = 2;
    uint256 public constant VALIDATION_SUCCESS = 0;

    // event OperationHandled(address indexed wallet, uint256 gasUsed);

    function handleOps(UserOperation[] memory ops) public {
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
        UserOperation memory userOp
    ) public returns (uint256) {
        require(msg.sender == address(this), "Can only be called by handleOps");

        uint256 requiredPayment = userOp.gas * tx.gasprice;

        // Process the tip for the executor
        // uint256 tips = (tx.gasprice - userOp.maxPriorityFeePerGas) * userOp.gas;
        // if (tips > 0) {
        //     payable(msg.sender).transfer(tips);
        // }

        ///////////////////////
        // Validate operation
        ///////////////////////

        uint256 initialGas = gasleft();
        uint256 gasUsed = 0;
        address paymaster = address(bytes20(userOp.paymasterAndData[:20]));

        // Validate all numeric values in userOp are well below 128 bit, so they can safely be added and multiplied without causing overflow.
        // uint256 maxGasValues = mUserOp.preVerificationGas |
        //     mUserOp.verificationGasLimit |
        //     mUserOp.callGasLimit |
        //     userOp.maxFeePerGas |
        //     userOp.maxPriorityFeePerGas;
        // require(maxGasValues <= type(uint120).max, "AA94 gas values overflow");

        // Validate the target account
        uint256 missingAccountFunds = 0;
        paymaster = mUserOp.paymaster;
        if (paymaster == address(0)) {
            uint256 bal = balanceOf(sender);
            missingAccountFunds = bal > requiredPrefund
                ? 0
                : requiredPrefund - bal;
        }

        try
            IAccount(sender).validateUserOp{gas: mUserOp.verificationGasLimit}(
                op,
                opInfo.userOpHash,
                aggregator,
                missingAccountFunds
            )
        returns (uint256 _deadline) {
            deadline = _deadline;
        } catch Error(string memory revertReason) {
            revert FailedOp(opIndex, address(0), revertReason);
        } catch {
            revert FailedOp(opIndex, address(0), "AA23 reverted (or OOG)");
        }
        if (paymaster == address(0)) {
            DepositInfo storage senderInfo = deposits[sender];
            uint256 deposit = senderInfo.deposit;
            if (requiredPrefund > deposit) {
                revert FailedOp(opIndex, address(0), "AA21 didn't pay prefund");
            }
            senderInfo.deposit = uint112(deposit - requiredPrefund);
        }
        gasUsedByValidateAccountPrepayment = preGas - gasleft();
        (bool valid, ) = userOp.sender.call(
            abi.encodeWithSignature(
                "validateOp((address,bytes,uint256,uint256,bytes,uint256,uint256,address,bytes), uint256)",
                userOp,
                requiredPayment
            )
        );
        require(valid, "Operation validation or payment failed");

        // Validate the paymaster
        if (paymaster != address(0)) {
            require(
                gasUsed <= userOp.verificationGasLimit,
                "verification gas limit exceeded"
            );
            uint256 gasToUse = userOp.verificationGasLimit - gasUsed;
            // Check paymaster deposits
            DepositInfo storage paymasterInfo = deposits[paymaster];
            uint256 deposit = paymasterInfo.deposit;
            require(
                deposit >= requiredPayment,
                "Insufficient paymaster deposit"
            );
            paymasterInfo.deposit = uint112(deposit - requiredPayment);
            // Check signature
            (bool success, bytes memory data) = paymaster.call{gas: gasToUse}(
                abi.encodeWithSignature(
                    "validatePaymasterOp((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes))",
                    userOp
                )
            );
            require(success == true, "Paymaster validation failed 1");
            (bytes memory context, uint256 result) = abi.decode(
                data,
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

        (bool success, ) = userOp.sender.call(
            abi.encodeWithSignature(
                "executeOp((address,bytes,uint256,uint256,bytes,uint256,uint256,address,bytes))",
                userOp
            )
        );
        require(success, "Operation execution failed");

        gasUsed = initialGas - gasleft();
        return gasUsed * tx.gasprice;
    }
}
