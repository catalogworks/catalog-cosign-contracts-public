// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4);
}

contract MockERC1155Rejector is IERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert("ERC1155 tokens not accepted");
    }
}
