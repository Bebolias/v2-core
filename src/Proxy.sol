// inspiration: https://github.com/Synthetixio/synthetix-v3/blob/main/protocol/synthetix/contracts/Proxy.sol
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

// https://www.npmjs.com/package/@synthetixio/core-contracts?activeTab=explore
// import "@synthetixio/core-contracts/contracts/proxy/UUPSProxyWithOwner.sol"; // todo: figure out how to fix this error

contract Proxy {
    // solhint-disable-next-line no-empty-blocks
    constructor(address firstImplementation, address initialOwner) 
    // UUPSProxyWithOwner(firstImplementation, initialOwner);
    {}
}
