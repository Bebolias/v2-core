//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./utils/contracts/proxy/UUPSProxyWithOwner.sol";

/**
 * Voltz V2 Core Proxy Contract
 */
contract CoreProxy is UUPSProxyWithOwner {
    // solhint-disable-next-line no-empty-blocks
    constructor(address firstImplementation, address initialOwner)
        UUPSProxyWithOwner(firstImplementation, initialOwner)
    {}
}
