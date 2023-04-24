import "oz/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("TEST", "test", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
