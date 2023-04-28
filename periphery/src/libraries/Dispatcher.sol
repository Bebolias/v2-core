// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Constants.sol";
import "./Commands.sol";
import "./V2DatedIRS.sol";
import "./V2Core.sol";
import "./Payments.sol";

/**
 * @title This library decodes and executes commands
 * @notice This library is called by the ExecutionModule to efficiently decode and execute a singular command
 */
library Dispatcher {
    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param inputs The inputs to execute the command with
    /// @return success True on success of the command, false on failure
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);
        success = true;

        if (command == Commands.V2_DATED_IRS_INSTRUMENT_SWAP) {
            // equivalent: abi.decode(inputs, (uint128, uint128, uint32, int256))

            uint128 accountId;
            uint128 marketId;
            uint32 maturityTimestamp;
            int256 baseAmount;

            assembly {
                accountId := calldataload(inputs.offset)
                marketId := calldataload(add(inputs.offset, 0x20))
                maturityTimestamp := calldataload(add(inputs.offset, 0x40))
                baseAmount := calldataload(add(inputs.offset, 0x60))
            }

            V2DatedIRS.swap(accountId, marketId, maturityTimestamp, baseAmount);
        } else if (command == Commands.V2_DATED_IRS_INSTRUMENT_SETTLE) {
            // equivalent: abi.decode(inputs, (uint128, uint128, uint32))
            uint128 accountId;
            uint128 marketId;
            uint32 maturityTimestamp;
            assembly {
                accountId := calldataload(inputs.offset)
                marketId := calldataload(add(inputs.offset, 0x20))
                maturityTimestamp := calldataload(add(inputs.offset, 0x40))
            }
            V2DatedIRS.settle(accountId, marketId, maturityTimestamp);
        } else if (command == Commands.V2_CORE_DEPOSIT) {
            // equivalent: abi.decode(inputs, (uint128, address, uint256))
            uint128 accountId;
            address collateralType;
            uint256 tokenAmount;
            assembly {
                accountId := calldataload(inputs.offset)
                collateralType := calldataload(add(inputs.offset, 0x20))
                tokenAmount := calldataload(add(inputs.offset, 0x40))
            }
            V2Core.deposit(accountId, collateralType, tokenAmount);
        } else if (command == Commands.V2_CORE_WITHDRAW) {
            // equivalent: abi.decode(inputs, (uint128, address, uint256))
            uint128 accountId;
            address collateralType;
            uint256 tokenAmount;
            assembly {
                accountId := calldataload(inputs.offset)
                collateralType := calldataload(add(inputs.offset, 0x20))
                tokenAmount := calldataload(add(inputs.offset, 0x40))
            }
            V2Core.withdraw(accountId, collateralType, tokenAmount);
        } else if (command == Commands.TRANSFER) {
            // equivalent:  abi.decode(inputs, (address, address, uint256))
            address token;
            address recipient;
            uint256 value;
            assembly {
                token := calldataload(inputs.offset)
                recipient := calldataload(add(inputs.offset, 0x20))
                value := calldataload(add(inputs.offset, 0x40))
            }
            // todo: check why we need to do map(recipient)
            // ref: https://github.com/Uniswap/universal-router/
            // blob/3ccbe972fe6f7dc1347d6974e45ea331321de714/contracts/base/Dispatcher.sol#L113
            Payments.pay(token, map(recipient), value);
        } else if (command == Commands.WRAP_ETH) {
            // equivalent: abi.decode(inputs, (address, uint256))
            address recipient;
            uint256 amountMin;
            assembly {
                recipient := calldataload(inputs.offset)
                amountMin := calldataload(add(inputs.offset, 0x20))
            }
            Payments.wrapETH(map(recipient), amountMin);
        } else if (command == Commands.UNWRAP_ETH) {
            // equivalent: abi.decode(inputs, (address, uint256))
            address recipient;
            uint256 amountMin;
            assembly {
                recipient := calldataload(inputs.offset)
                amountMin := calldataload(add(inputs.offset, 0x20))
            }
            Payments.unwrapWETH9(map(recipient), amountMin);
        } else {
            // placeholder area for commands ...
            revert InvalidCommandType(command);
        }
    }

    /// @notice Calculates the recipient address for a command
    /// @param recipient The recipient or recipient-flag for the command
    /// @return output The resultant recipient for the command
    function map(address recipient) internal view returns (address) {
        if (recipient == Constants.MSG_SENDER) {
            // todo: check the purpose of the locked flow:
            // https://github.com/Uniswap/universal-router/
            // blob/a88bc6e15af738b61d7bee8feb7df8d2a6e26347/contracts/base/LockAndMsgSender.sol#L26
            return msg.sender;
        } else if (recipient == Constants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }
}
