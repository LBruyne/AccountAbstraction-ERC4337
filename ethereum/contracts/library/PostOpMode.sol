// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

enum PostOpMode {
    opSucceeded, // user op succeeded
    opReverted, // user op reverted. still has to pay for gas.
    postOpReverted // user op succeeded, but caused postOp to revert. Now its a 2nd call, after user's op was deliberately reverted.
}
