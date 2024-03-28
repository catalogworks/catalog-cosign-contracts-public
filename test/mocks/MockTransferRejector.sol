// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockTransferRejector {
    receive() external payable {
        revert("I don't accept ETH");
    }
}
