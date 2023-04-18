//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title Module that enables calling multiple router proxies and methods of the voltz v2 ecosystem in a single transaction
 */
interface IMulticallModule {
    // todo: natspec
    function multiCall(address[] calldata targets, bytes[] calldata data) external payable returns (bytes[] memory);
}
