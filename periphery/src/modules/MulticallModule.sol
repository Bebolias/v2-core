//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../interfaces/IMulticallModule.sol";

/**
 * @title Module that enables calling multiple proxies in the voltz v2 ecosystem in a single transaction
 * @dev See IMulticallModule.
 * @dev Implementation adapted from https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol
 */
contract MulticallModule is IMulticallModule {
    function multiCall(address[] calldata targets, bytes[] calldata data)
        public
        payable
        override
        returns (bytes[] memory results)
    {
        // todo: use a custom error
        require(targets.length == data.length, "target length != data length");

        results = new bytes[](data.length);

        for (uint256 i; i < targets.length; i++) {
            // todo: double check if call is the right method in this instance
            (bool success, bytes memory result) = targets[i].call(data[i]);

            if (!success) {
                // Next 6 lines from https://ethereum.stackexchange.com/a/83577
                // solhint-disable-next-line reason-string
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }

        return results;
    }
}
