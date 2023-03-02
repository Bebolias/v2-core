//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../utils/contracts/proxy/UUPSProxyWithOwner.sol";

/**
 * Voltz V2 Core Proxy Contract
 *
 * todo: can we do smth like this? https://usecannon.com/packages/synthetix to interact with this protocol
 */
contract CoreProxy is UUPSProxyWithOwner {
    // solhint-disable-next-line no-empty-blocks
    constructor(address firstImplementation, address initialOwner) UUPSProxyWithOwner(firstImplementation, initialOwner) { }
}
