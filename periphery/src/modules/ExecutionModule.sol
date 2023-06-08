pragma solidity >=0.8.19;

import "../interfaces/IExecutionModule.sol";
import "../libraries/Commands.sol";
import "../libraries/Dispatcher.sol";

/**
 * @title Execution Module is responsible for executing encoded commands along with provided inputs
 * @dev See IExecutionModule.
 */
contract ExecutionModule is IExecutionModule {
    // todo: add initialize method to set the immutables

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    /// @inheritdoc IExecutionModule
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable
        override
        checkDeadline(deadline)
    {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands;) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            success = Dispatcher.dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed(commandIndex);
            }

            unchecked {
                commandIndex++;
            }
        }
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        // todo: add flag allow revert
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }
}
