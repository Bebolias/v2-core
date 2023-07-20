pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/modules/ExecutionModule.sol";
import "../../src/interfaces/external/IWETH9.sol";
import "../../src/modules/ConfigurationModule.sol";
import "../utils/MockWeth.sol";

contract ExtendedExecutionModule is ExecutionModule, ConfigurationModule {
    function setOwner(address account) external {
        OwnableStorage.Data storage ownable = OwnableStorage.load();
        ownable.owner = account;
    }
}

contract ExecutionModuleTest is Test {
    ExtendedExecutionModule public exec;
    address public core = address(111);
    address public instrument = address(112);
    address public exchange = address(113);
    address public accountNFT = address(114);

    address public erc20Token = address(116);

    MockWeth public mockWeth = new MockWeth("MockWeth", "Mock WETH");

    function setUp() public {
        exec = new ExtendedExecutionModule();
        exec.setOwner(address(this));
        exec.configure(Config.Data({
            WETH9: IWETH9(mockWeth),
            VOLTZ_V2_CORE_PROXY: core,
            VOLTZ_V2_DATED_IRS_PROXY: instrument,
            VOLTZ_V2_DATED_IRS_VAMM_PROXY: exchange
        }));
    }

    function testExecCommand_Swap() public {
        // Setup
        IProductIRSModule.TakerOrderParams memory params = IProductIRSModule.TakerOrderParams({
            accountId: 1,
            marketId: 101,
            maturityTimestamp: 1678786786,
            baseAmount: 100,
            priceLimit: 0
        }); 

        int256 executedBaseAmount = 100;
        int256 executedQuoteAmount = -100;
        uint256 fee = 25;
        uint256 im = 55;
        uint256 highestUnrealizedLoss = 10;
        
        int24 currentTick = 1200;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(params.accountId, params.marketId, params.maturityTimestamp, params.baseAmount, params.priceLimit);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (params.accountId)
            ),
            abi.encode(address(this))
        );

        vm.mockCall(
            instrument,
            abi.encodeCall(IProductIRSModule(instrument).initiateTakerOrder, params),
            abi.encode(executedBaseAmount, executedQuoteAmount, fee, im, highestUnrealizedLoss)
        );

        vm.mockCall(
            exchange,
            abi.encodeCall(
                IVammModule(exchange).getVammTick,
                (params.marketId, params.maturityTimestamp)
            ),
            abi.encode(currentTick)
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (params.accountId)
            )
        );

        vm.expectCall(
            instrument,
            abi.encodeCall(IProductIRSModule(instrument).initiateTakerOrder, params)
        );

        vm.expectCall(
            exchange,
            abi.encodeCall(
                IVammModule(exchange).getVammTick,
                (params.marketId, params.maturityTimestamp)
            )
        );

        // Action
        (
            int256 executedBaseAmountOutput,
            int256 executedQuoteAmountOutput,
            uint256 feeOutput,
            uint256 imOutput,
            uint256 highestUnrealizedLossOutput,
            int24 currentTickOutput
        ) = abi.decode(exec.execute(commands, inputs, block.timestamp + 1)[0], (int256, int256, uint256, uint256, uint256, int24));

        // Expect output
        assertEq(executedBaseAmountOutput, executedBaseAmount);
        assertEq(executedQuoteAmountOutput, executedQuoteAmount);
        assertEq(feeOutput, fee);
        assertEq(imOutput, im);
        assertEq(highestUnrealizedLossOutput, highestUnrealizedLoss);
        assertEq(currentTickOutput, currentTick);
    }

    function testExecCommand_Swap_RevertWhen_NotOwner() public {
        // Setup
        IProductIRSModule.TakerOrderParams memory params  = IProductIRSModule.TakerOrderParams({
            accountId: 1,
            marketId: 101,
            maturityTimestamp: 1678786786,
            baseAmount: 100,
            priceLimit: 0
        }); 

        int256 executedBaseAmount = 100;
        int256 executedQuoteAmount = -100;
        uint256 fee = 25;
        uint256 im = 55;
        uint256 highestUnrealizedLoss = 10;
        
        int24 currentTick = 1200;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(params.accountId, params.marketId, params.maturityTimestamp, params.baseAmount, params.priceLimit);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (params.accountId)
            ),
            abi.encode(address(1))
        );

        vm.mockCall(
            instrument,
            abi.encodeCall(IProductIRSModule(instrument).initiateTakerOrder, params),
            abi.encode(executedBaseAmount, executedQuoteAmount, fee, im, highestUnrealizedLoss)
        );

        vm.mockCall(
            exchange,
            abi.encodeCall(
                IVammModule(exchange).getVammTick,
                (params.marketId, params.maturityTimestamp)
            ),
            abi.encode(currentTick)
        );

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(AccessControl.NotOwner.selector, address(this), 1, address(1)));
        
        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_Settle() public {
        // Setup
        uint128 accountId = 1;
        uint128 marketId = 101;
        uint32 maturityTimestamp = 1678786786;

        bytes[] memory inputs = new bytes[](1);
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)));

        inputs[0] = abi.encode(accountId, marketId, maturityTimestamp);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(this))
        );

        vm.mockCall(
            instrument,
            abi.encodeCall(
                IProductIRSModule(instrument).settle,
                (accountId, marketId, maturityTimestamp)
            ),
            abi.encode()
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            )
        );

        vm.expectCall(
            instrument,
            abi.encodeCall(
                IProductIRSModule(instrument).settle,
                (accountId, marketId, maturityTimestamp)
            )
        );

        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_Settle_RevertWhen_NotOwner() public {
        // Setup
        uint128 accountId = 1;
        uint128 marketId = 101;
        uint32 maturityTimestamp = 1678786786;

        bytes[] memory inputs = new bytes[](1);
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SETTLE)));

        inputs[0] = abi.encode(accountId, marketId, maturityTimestamp);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(1))
        );

        vm.mockCall(
            instrument,
            abi.encodeCall(
                IProductIRSModule(instrument).settle,
                (accountId, marketId, maturityTimestamp)
            ),
            abi.encode()
        );

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(AccessControl.NotOwner.selector, address(this), 1, address(1)));
        
        exec.execute(commands, inputs, block.timestamp+1);
    }

    function testExecCommand_Mint() public {
        // Setup 
        uint128 accountId = 1;
        uint128 marketId = 101;
        uint32 maturityTimestamp = 1678786786;
        int24 tickLower = 0;
        int24 tickUpper = 60;
        int128 liquidityDelta = 1000;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(this))
        );

        vm.mockCall(
            exchange,
            abi.encodeCall(
                IPoolModule(exchange).initiateDatedMakerOrder,
                (accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta)
            ),
            abi.encode(1, 2, 3)
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            )
        );

        vm.expectCall(
            exchange,
            abi.encodeCall(
                IPoolModule(exchange).initiateDatedMakerOrder,
                (accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta)
            )
        );

        // Action
        (uint256 fee, uint256 im, uint256 highestUnrealizedLoss) = 
            abi.decode(exec.execute(commands, inputs, block.timestamp + 1)[0], (uint256, uint256, uint256));

        // Expect values
        assertEq(fee, 1);
        assertEq(im, 2);
        assertEq(highestUnrealizedLoss, 3);
    }

    function testExecCommand_Mint_RevertWhen_NotOwner() public {
        // Setup 
        uint128 accountId = 1;
        uint128 marketId = 101;
        uint32 maturityTimestamp = 1678786786;
        int24 tickLower = 0;
        int24 tickUpper = 60;
        int128 liquidityDelta = 1000;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(1))
        );

        vm.mockCall(
            exchange,
            abi.encodeCall(
                IPoolModule(exchange).initiateDatedMakerOrder,
                (accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta)
            ),
            abi.encode(1, 2, 3)
        );

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(AccessControl.NotOwner.selector, address(this), 1, address(1)));
        
        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecMultipleCommands() public {
        // Setup 
        IProductIRSModule.TakerOrderParams memory params = IProductIRSModule.TakerOrderParams({
            accountId: 1,
            marketId: 101,
            maturityTimestamp: 1678786786,
            baseAmount: 100,
            priceLimit: 0
        }); 

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP)),
            bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
        );
    
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(params.accountId, params.marketId, params.maturityTimestamp, 0, 60, 1000);
        inputs[1] = abi.encode(params.accountId, params.marketId, params.maturityTimestamp, params.baseAmount, params.priceLimit);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (params.accountId)
            ),
            abi.encode(address(this))
        );

        vm.mockCall(
            exchange,
            abi.encodeCall(
                IPoolModule(exchange).initiateDatedMakerOrder,
                (params.accountId, params.marketId, params.maturityTimestamp, 0, 60, 1000)
            ),
            abi.encode(1, 2, 3)
        );

        vm.mockCall(
            instrument,
            abi.encodeCall(
                IProductIRSModule(instrument).initiateTakerOrder,
                params
            ),
            abi.encode(11, 12, 13, 14, 15)
        );

        vm.mockCall(
            exchange,
            abi.encodeWithSelector(
                IVammModule.getVammTick.selector,
                params.marketId, params.maturityTimestamp
            ),
            abi.encode(16)
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (params.accountId)
            )
        );

        vm.expectCall(
            exchange,
            abi.encodeCall(
                IPoolModule(exchange).initiateDatedMakerOrder,
                (params.accountId, params.marketId, params.maturityTimestamp, 0, 60, 1000)
            )
        );

        vm.expectCall(
            instrument,
            abi.encodeCall(
                IProductIRSModule(instrument).initiateTakerOrder,
                params
            )
        );

        vm.expectCall(
            exchange,
            abi.encodeWithSelector(
                IVammModule.getVammTick.selector,
                params.marketId, params.maturityTimestamp
            )
        );

        // Action
        bytes[] memory output = exec.execute(commands, inputs, block.timestamp + 1);

        // Expect values
        assertEq(output.length, 2);

        (uint256 fee1, uint256 im1, uint256 highestUnrealizedLossMaker1) = abi.decode(output[0], (uint256, uint256, uint256));
        
        (
            int256 executedBaseAmount2,
            int256 executedQuoteAmount2,
            uint256 fee2,
            uint256 im2,
            uint256 highestUnrealizedLoss2,
            int24 currentTick2
        ) = abi.decode(output[1], (int256, int256, uint256, uint256, uint256, int24));

        assertEq(fee1, 1);
        assertEq(im1, 2);
        assertEq(highestUnrealizedLossMaker1, 3);

        assertEq(executedBaseAmount2, 11);
        assertEq(executedQuoteAmount2, 12);
        assertEq(fee2, 13);
        assertEq(im2, 14);
        assertEq(highestUnrealizedLoss2, 15);
        assertEq(currentTick2, 16);
    }

    function testExecCommand_Withdraw() public {
        // Setup 
        uint256 amount = 100000;

        uint128 accountId = 1;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_WITHDRAW)));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(accountId, address(erc20Token), amount);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(this))
        );

        vm.mockCall(
            core,
            abi.encodeCall(
                ICollateralModule(core).withdraw,
                (accountId, address(erc20Token), amount)
            ),
            abi.encode()
        );

        vm.mockCall(
            erc20Token,
            abi.encodeCall(
                IERC20(erc20Token).transfer,
                (address(this), amount)
            ),
            abi.encode()
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            )
        );
    
        vm.expectCall(
            core, 
            abi.encodeCall(
                ICollateralModule(core).withdraw,
                (accountId, address(erc20Token), amount)
            )
        );

        vm.expectCall(
            erc20Token,
            abi.encodeCall(
                IERC20(erc20Token).transfer,
                (address(this), amount)
            )
        );

        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_Withdraw_RevertWhen_WithdrawReverts() public {
        // Setup 
        uint256 amount = 100000;

        uint128 accountId = 1;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_WITHDRAW)));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(accountId, address(erc20Token), amount);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(this))
        );

        vm.mockCallRevert(
            core,
            abi.encodeCall(
                ICollateralModule(core).withdraw,
                (accountId, address(erc20Token), amount)
            ),
            abi.encode("error")
        );

        vm.mockCall(
            erc20Token,
            abi.encodeCall(
                IERC20(erc20Token).transfer,
                (address(this), amount)
            ),
            abi.encode()
        );

        // Expect revert
        vm.expectRevert(abi.encode("error"));

        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_Withdraw_RevertWhen_NotOwner() public {
        // Setup 
        uint256 amount = 100000;

        uint128 accountId = 1;

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_WITHDRAW)));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(accountId, address(erc20Token), amount);

        vm.mockCall(
            core,
            abi.encodeCall(
                IAccountModule(core).getAccountOwner,
                (accountId)
            ),
            abi.encode(address(1))
        );

        vm.mockCall(
            core,
            abi.encodeCall(
                ICollateralModule(core).withdraw,
                (accountId, address(erc20Token), amount)
            ),
            abi.encode()
        );

        vm.mockCall(
            erc20Token,
            abi.encodeCall(
                IERC20(erc20Token).transfer,
                (address(this), amount)
            ),
            abi.encode()
        );

        vm.expectRevert(abi.encodeWithSelector(AccessControl.NotOwner.selector, address(this), 1, address(1)));
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_Deposit() public {
        // Setup
        uint256 amount = 100000;
        uint128 accountId = 1;
        
        CollateralConfiguration.Data memory collateralConfiguration = CollateralConfiguration.Data({
                    depositingEnabled: true,
                    liquidationBooster: 10e6,
                    tokenAddress: address(erc20Token),
                    cap: 20e6
                });
        
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_DEPOSIT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(accountId, address(erc20Token), amount);

        // Make sure that deposit does not ask for ownership
        vm.mockCallRevert(
            core,
            abi.encodeCall(IAccountModule(core).getAccountOwner, (accountId)),
            abi.encode()
        );

        vm.mockCall(
            core,
            abi.encodeCall(
                ICollateralConfigurationModule(core).getCollateralConfiguration,
                (address(erc20Token))
            ),
            abi.encode(collateralConfiguration)
        );

        vm.mockCall(
            core,
            abi.encodeCall(
                ICollateralModule(core).deposit,
                (accountId, address(erc20Token), amount)
            ),
            abi.encode()
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(
                ICollateralConfigurationModule(core).getCollateralConfiguration,
                (address(erc20Token))
            )
        );

        vm.expectCall(
            core,
            abi.encodeCall(
                ICollateralModule(core).deposit,
                (accountId, address(erc20Token), amount)
            )
        );

        vm.expectCall(
            address(erc20Token),
            abi.encodeCall(
                IERC20(erc20Token).approve,
                (address(core), amount + collateralConfiguration.liquidationBooster)
            )
        );

        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_CreateAccount() public {
        // Setup
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)));
        bytes[] memory inputs = new bytes[](1);

        uint128 accountId = 127637236;

        inputs[0] = abi.encode(accountId);

        vm.mockCall(
            core,
            abi.encodeCall(IAccountModule(core).createAccount, (accountId, address(this))),
            abi.encode()
        );

        // Expect calls
        vm.expectCall(
            core,
            abi.encodeCall(IAccountModule(core).createAccount, (accountId, address(this)))
        );

        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_TransferFrom() public {
        // Setup
        uint256 amount = 100000;
        
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER_FROM)));
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(address(erc20Token), amount);

        vm.mockCall(
            erc20Token,
            abi.encodeCall(
                IERC20(erc20Token).transferFrom,
                (address(this), address(exec), amount)
            ),
            abi.encode()
        );
    

        // Expect calls
        vm.expectCall(
            erc20Token,
            abi.encodeCall(
                IERC20(erc20Token).transferFrom,
                (address(this), address(exec), amount)
            )
        );

        // Action
        exec.execute(commands, inputs, block.timestamp + 1);
    }

    function testExecCommand_WrapETH() public {

        uint256 amount = 10000;
        
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(amount);

        vm.mockCall(
            address(mockWeth),
            amount,
            abi.encodeCall(IWETH9(mockWeth).deposit, ()),
            abi.encode()
        );
    
        vm.deal(address(this), amount);

        uint256 initUserBalance = address(this).balance;
        uint256 initExecBalance = address(exec).balance;

        // Expect calls
        vm.expectCall(
            address(mockWeth),
            amount,
            abi.encodeCall(IWETH9(mockWeth).deposit, ())
        );

        // Action
        exec.execute{value: amount}(commands, inputs, block.timestamp + 1);

        // Check post state
        assertEq(address(this).balance, initUserBalance - amount);
        assertEq(address(exec).balance, initExecBalance + amount);
    }

    function testExecCommand_WrapETH_MoreETH() public {

        uint256 amountToWrap = 10000;
        uint256 amountToTransfer = 20000;
        
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(amountToWrap);

        vm.mockCall(
            address(mockWeth),
            amountToWrap,
            abi.encodeCall(IWETH9(mockWeth).deposit, ()),
            abi.encode()
        );
    
        vm.deal(address(this), amountToTransfer);

        uint256 initUserBalance = address(this).balance;
        uint256 initExecBalance = address(exec).balance;

        // Expect calls
        vm.expectCall(
            address(mockWeth),
            amountToWrap,
            abi.encodeCall(IWETH9(mockWeth).deposit, ())
        );

        // Action
        exec.execute{value: amountToTransfer}(commands, inputs, block.timestamp + 1);

        // Check post state
        assertEq(address(this).balance, initUserBalance - amountToTransfer);
        assertEq(address(exec).balance, initExecBalance + amountToTransfer);
    }

    function testExecCommand_WrapETH_RevertWhen_InsufficientETH() public {

        uint256 amountToWrap = 10000;
        uint256 amountToTransfer = 5000;
        
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(amountToWrap);
    
        vm.deal(address(this), amountToTransfer);

        uint256 initUserBalance = address(this).balance;
        uint256 initExecBalance = address(exec).balance;

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(Payments.InsufficientETH.selector));

        // Action
        exec.execute{value: amountToTransfer}(commands, inputs, block.timestamp + 1);

        // Check post state
        assertEq(address(this).balance, initUserBalance);
        assertEq(address(exec).balance, initExecBalance);
    }

    function test_RevertWhen_UnknownCommand() public {
        
        bytes1 mockCommand = bytes1(uint8(0xFF));
        bytes memory commands = abi.encodePacked(mockCommand);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(1, 2, 3, 4, 5);

        vm.expectRevert(
            abi.encodeWithSelector(
                Dispatcher.InvalidCommandType.selector,
                uint8(mockCommand & Commands.COMMAND_TYPE_MASK)
            )
        );

        exec.execute(commands, inputs, block.timestamp + 1);
    }

}