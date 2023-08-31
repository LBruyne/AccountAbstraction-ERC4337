// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract StakeManager {

    event Deposited(address indexed wallet, uint256 amount);
    event Withdrawn(address indexed destination, uint256 amount);

    /**
     * @param deposit the account's deposit
     * @param staked true if this account is staked as a paymaster
     * @param stake actual amount of ether staked for this paymaster.
     * @param unstakeDelaySec minimum delay to withdraw the stake. must be above the global unstakeDelaySec
     * @param withdrawTime - first block timestamp where 'withdrawStake' will be callable, or zero if already locked
     * @dev sizes were chosen so that (deposit,staked) fit into one cell (used during handleOps)
     *    and the rest fit into a 2nd cell.
     *    112 bit allows for 2^15 eth
     *    64 bit for full timestamp
     *    32 bit allow 150 years for unstake delay
     */
    struct DepositInfo {
        uint112 deposit;
        bool staked;
        uint112 stake;
        uint32 unstakeDelaySec;
        uint64 withdrawTime;
    }

    // API struct used by getStakeInfo and simulateValidation
    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    // maps paymaster to their deposits and stakes
    mapping(address => DepositInfo) public deposits;

    function getDepositInfo(
        address account
    ) public view returns (DepositInfo memory info) {
        return deposits[account];
    }

    // internal method to return just the stake info
    function getStakeInfo(
        address addr
    ) internal view returns (StakeInfo memory info) {
        DepositInfo storage depositInfo = deposits[addr];
        info.stake = depositInfo.stake;
        info.unstakeDelaySec = depositInfo.unstakeDelaySec;
    }

    // return the deposit (for gas payment) of the account
    function balanceOf(address account) public view returns (uint256) {
        return deposits[account].deposit;
    }

    receive() external payable {
        depositTo(msg.sender);
    }

    function internalIncrementDeposit(
        address account,
        uint256 amount
    ) internal {
        DepositInfo storage info = deposits[account];
        uint256 newAmount = info.deposit + amount;
        require(newAmount <= type(uint112).max, "deposit overflow");
        info.deposit = uint112(newAmount);
    }

    /**
     * add to the deposit of the given account
     */
    function depositTo(address account) public payable {
        internalIncrementDeposit(account, msg.value);
        // DepositInfo storage info = deposits[account];
        // emit Deposited(
        //     msg.sender,
        //     address(this),
        //     account,
        //     msg.value,
        //     info.deposit
        // );
        emit Deposited(account, msg.value);
    }

    /**
     * withdraw from the deposit.
     * @param withdrawAddress the address to send withdrawn value.
     * @param withdrawAmount the amount to withdraw.
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external {
        DepositInfo storage info = deposits[msg.sender];
        require(withdrawAmount <= info.deposit, "Withdraw amount too large");
        info.deposit = uint112(info.deposit - withdrawAmount);
        // emit Withdrawn(msg.sender, withdrawAddress, withdrawAmount);
        emit Withdrawn(withdrawAddress, withdrawAmount);
        (bool success, ) = withdrawAddress.call{value: withdrawAmount}("");
        require(success, "failed to withdraw");
    }

    function refundDeposit(
        address payable refundAddress,
        uint256 refundAmount
    ) internal {
        (bool success, ) = refundAddress.call{value: refundAmount, gas: 4500}(
            ""
        );

        if (success) {
            // emit RefundDeposit(msg.sender, refundAddress, refundAmount);
        } else {
            internalIncrementDeposit(refundAddress, refundAmount);
        }
    }
}