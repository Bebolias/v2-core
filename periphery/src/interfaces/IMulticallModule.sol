//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Module that enables calling multiple router proxies and methods of the voltz v2 ecosystem in a single transaction
 */
interface IMulticallModule {
    function multiCall(address[] calldata targets, bytes[] calldata data) external payable returns (bytes[] memory);
}

// https://github.com/Uniswap/v3-periphery/blob/6cce88e63e176af1ddb6cc56e029110289622317/contracts/base/Multicall.sol#L14
