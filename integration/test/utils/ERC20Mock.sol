pragma solidity >=0.8.19;

import "oz/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 public _decimals;
    constructor(uint8 __decimals) ERC20("ERC20Mock", "E20M") {
        _decimals = __decimals;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
