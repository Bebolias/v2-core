//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IExecutionModule.sol";

/**
 * @title Execution Module is responsible for executing encoded commands along with provided inputs
 * @dev See IExecutionModule.
 */
contract ExecutionModule is IExecutionModule {
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    /// @inheritdoc IExecutionModule
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable
        checkDeadline(deadline)
    {
        execute(commands, inputs);
    }
}
