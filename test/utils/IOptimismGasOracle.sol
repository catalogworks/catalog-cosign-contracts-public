// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOptimismGasOracle {
    function getL1Fee(bytes calldata _data) external view returns (uint256);
}
