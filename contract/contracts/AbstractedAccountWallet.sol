// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract AbstractedAccountWallet {
    address public owner;

    // Events for logging important actions
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event Transferred(address indexed to, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    // Modifier to check if the caller is the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    // Function to deposit Ether into the contract
    function deposit() public payable {
        emit Deposited(msg.sender, msg.value);
    }

    // Function to withdraw Ether from the contract
    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(owner).transfer(amount);
        emit Withdrawn(owner, amount);
    }

    // Function to transfer Ether to another address
    function transfer(address to, uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(to).transfer(amount);
        emit Transferred(to, amount);
    }
}
