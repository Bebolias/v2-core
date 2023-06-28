pragma solidity >=0.8.19;

import "forge-std/Script.sol";

import {CoreProxy, AccountNftProxy} from "../src/Core.sol";
import {DatedIrsProxy} from "../src/DatedIrs.sol";
import {PeripheryProxy} from "../src/Periphery.sol";
import {VammProxy} from "../src/Vamm.sol";
import {IAaveV3LendingPool} from "@voltz-protocol/products-dated-irs/src/interfaces/external/IAaveV3LendingPool.sol";
import {AaveRateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveRateOracle.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";

import {ud60x18} from "@prb/math/UD60x18.sol";
import {sd59x18} from "@prb/math/SD59x18.sol";

import {AccessPassConfiguration} from "@voltz-protocol/core/src/storage/AccessPassConfiguration.sol";
import {CollateralConfiguration} from "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import {ProtocolRiskConfiguration} from "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import {MarketFeeConfiguration} from "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";
import {MarketRiskConfiguration} from "@voltz-protocol/core/src/storage/MarketRiskConfiguration.sol";

import {ProductConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import {MarketConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";
import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";

import {TickMath} from "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {FullMath} from "@voltz-protocol/v2-vamm/utils/vamm-math/FullMath.sol";
import {VAMMBase} from "@voltz-protocol/v2-vamm/utils/vamm-math/VAMMBase.sol";
import {VammConfiguration, IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import {SafeCastU256, SafeCastI256} from "@voltz-protocol/util-contracts/src/helpers/SafeCast.sol";

import {AccessPassNFT} from "@voltz-protocol/access-pass-nft/src/AccessPassNFT.sol";
import {Merkle} from "murky/Merkle.sol";
import {SetUtil} from "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";

contract Testnet is Script {
  CoreProxy coreProxy = CoreProxy(payable(vm.envAddress("TESTNET_SCRIPT_CORE_PROXY")));
  DatedIrsProxy datedIrsProxy = DatedIrsProxy(payable(vm.envAddress("TESTNET_SCRIPT_DATED_IRS_PROXY")));
  PeripheryProxy peripheryProxy = PeripheryProxy(payable(vm.envAddress("TESTNET_SCRIPT_PERIPHERY_PROXY")));
  VammProxy vammProxy = VammProxy(payable(vm.envAddress("TESTNET_SCRIPT_VAMM_PROXY")));
  AccessPassNFT accessPassNft = AccessPassNFT(payable(vm.envAddress("TESTNET_SCRIPT_ACCESS_PASS_NFT")));

  address owner = coreProxy.owner();

  bytes32 private constant _GLOBAL_FEATURE_FLAG = "global";
  bytes32 private constant _CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
  bytes32 private constant _NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG = "notifyAccountTransfer";

  using SafeCastU256 for uint256;
  using SafeCastI256 for int256;

  using SetUtil for SetUtil.Bytes32Set;
  SetUtil.Bytes32Set addressPassNftInfo;
  Merkle merkle = new Merkle();

  function configureProtocol(bool deployAccessPassNft) public {
    vm.startBroadcast(owner);

    console2.log(owner);
  
    coreProxy.setFeatureFlagAllowAll(_GLOBAL_FEATURE_FLAG, true);
    coreProxy.setFeatureFlagAllowAll(_CREATE_ACCOUNT_FEATURE_FLAG, true);
    coreProxy.setFeatureFlagAllowAll(_NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG, true);

    coreProxy.addToFeatureFlagAllowlist(bytes32("registerProduct"), owner);

    coreProxy.setPeriphery(address(peripheryProxy));

    coreProxy.configureProtocolRisk(
      ProtocolRiskConfiguration.Data({
        imMultiplier: ud60x18(2e18),
        liquidatorRewardParameter: ud60x18(5e16)
      })
    );

    (address accountNftProxyAddress, ) = coreProxy.getAssociatedSystem(bytes32("accountNFT"));
    peripheryProxy.configure(
      Config.Data({
        WETH9: IWETH9(address(0)),  // todo: deploy weth9 mock
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy),
        VOLTZ_V2_ACCOUNT_NFT_PROXY: accountNftProxyAddress
      })
    );

    if (deployAccessPassNft) {
      accessPassNft = new AccessPassNFT("name", "symbol");
      console2.log("Deployed Access Pass NFT:", address(accessPassNft));

      coreProxy.configureAccessPass(
        AccessPassConfiguration.Data({
          accessPassNFTAddress: address(accessPassNft)
        })
      );
    }
  }

  function configureProduct() public {
    vm.startBroadcast(owner);

    uint128 productId = coreProxy.registerProduct(address(datedIrsProxy), "Dated IRS Product");
    console2.log("Product Id:", productId);

    datedIrsProxy.configureProduct(
      ProductConfiguration.Data({
        productId: productId,
        coreProxy: address(coreProxy),
        poolAddress: address(vammProxy)
      })
    );

    vammProxy.setProductAddress(address(datedIrsProxy));
  }

  function configureAaveMarket(
    address aaveLendingPoolAddress,
    address tokenAddress,
    uint128 productId,
    uint128 marketId,
    uint128 feeCollectorAccountId
  ) public {
    addNewRoot(owner);

    vm.startBroadcast(owner);

    coreProxy.configureCollateral(
      CollateralConfiguration.Data({
        depositingEnabled: true,
        liquidationBooster: 1e6,
        tokenAddress: tokenAddress,
        cap: 1000e6
      })
    );

    datedIrsProxy.configureMarket(
      MarketConfiguration.Data({
        marketId: marketId,
        quoteToken: tokenAddress
      })
    );

    IAaveV3LendingPool aaveLendingPool = IAaveV3LendingPool(aaveLendingPoolAddress);
    AaveRateOracle aaveRateOracle = new AaveRateOracle(aaveLendingPool, tokenAddress);
    console2.log("Aave Rate Oracle", address(aaveRateOracle));

    datedIrsProxy.setVariableOracle(
      marketId,
      address(aaveRateOracle)
    );

    accessPassNft.redeem(
      msg.sender,
      1,
      merkle.getProof(addressPassNftInfo.values(), 1),
      merkle.getRoot(addressPassNftInfo.values())
    );
    coreProxy.createAccount(feeCollectorAccountId, owner);

    coreProxy.configureMarketFee(
      MarketFeeConfiguration.Data({
        productId: productId,
        marketId: marketId,
        feeCollectorAccountId: feeCollectorAccountId,
        atomicMakerFee: ud60x18(1e16),
        atomicTakerFee: ud60x18(5e16)
      })
    );

    coreProxy.configureMarketRisk(
      MarketRiskConfiguration.Data({
        productId: productId, 
        marketId: marketId, 
        riskParameter: sd59x18(1e18), 
        twapLookbackWindow: 120
      })
    );
  }

  function deployPool(
    uint128 marketId,
    uint32 maturityTimestamp,
    address aaveRateOracleAddress
  ) public {
    vm.startBroadcast(owner);

    AaveRateOracle aaveRateOracle = AaveRateOracle(aaveRateOracleAddress);

    VammConfiguration.Immutable memory immutableConfig = VammConfiguration.Immutable({
        maturityTimestamp: maturityTimestamp,
        _maxLiquidityPerTick: type(uint128).max,
        _tickSpacing: 60,
        marketId: marketId
    });

    VammConfiguration.Mutable memory mutableConfig = VammConfiguration.Mutable({
        priceImpactPhi: ud60x18(1e17), // 0.1
        priceImpactBeta: ud60x18(125e15), // 0.125
        spread: ud60x18(3e15), // 0.3%
        rateOracle: IRateOracle(address(aaveRateOracle))
    });

    vammProxy.createVamm(
      marketId,
      TickMath.getSqrtRatioAtTick(-13860), // price = 4%
      immutableConfig,
      mutableConfig
    );

    vammProxy.increaseObservationCardinalityNext(marketId, maturityTimestamp, 16);
  }

  function addNewRoot(address[] memory accountOwners) public {
    vm.startBroadcast(owner);

    addressPassNftInfo.add(keccak256(abi.encodePacked(address(0), uint256(0))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(address(owner), uint256(1))));
    for (uint256 i = 0; i < accountOwners.length; i += 1) {
      bytes32 leaf = keccak256(abi.encodePacked(accountOwners[i], uint256(1)));
      if (!addressPassNftInfo.contains(leaf)) {
        addressPassNftInfo.add(leaf);
      }
    }
    
    accessPassNft.addNewRoot(
      AccessPassNFT.RootInfo({
        merkleRoot: merkle.getRoot(addressPassNftInfo.values()),
        baseMetadataURI: "ipfs://"
      })
    );

    accessPassNft.redeem(
      owner,
      1,
      merkle.getProof(addressPassNftInfo.values(), 1),
      merkle.getRoot(addressPassNftInfo.values())
    );

    vm.stopBroadcast();
  }

  function addNewRoot(address accountOwner) private {
    address[] memory accountOwners = new address[](1);
    accountOwners[0] = accountOwner;
    addNewRoot(accountOwners);
  }

  function mintNewAccount(
    uint128 marketId,
    address tokenAddress,
    uint128 accountId,
    uint32 maturityTimestamp,
    uint256 depositAmount,
    int256 leverage,  // positive means VT, negative means FT
    address aaveRateOracleAddress
  ) public {
    addNewRoot(msg.sender);

    vm.startBroadcast();

    AaveRateOracle aaveRateOracle = AaveRateOracle(aaveRateOracleAddress);
    uint256 liquidationBooster = coreProxy.getCollateralConfiguration(tokenAddress).liquidationBooster;
    int256 baseAmount = sd59x18(int256(depositAmount) * leverage).div(aaveRateOracle.getCurrentIndex().intoSD59x18()).unwrap();

    IERC20 token = IERC20(tokenAddress);
    token.approve(address(peripheryProxy), depositAmount + liquidationBooster);

    accessPassNft.redeem(
      msg.sender,
      1,
      merkle.getProof(addressPassNftInfo.values(), 1),
      merkle.getRoot(addressPassNftInfo.values())
    );

    bytes memory commands = abi.encodePacked(
      bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
      bytes1(uint8(Commands.TRANSFER_FROM)),
      bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
    );

    bytes[] memory inputs = new bytes[](4);
    inputs[0] = abi.encode(accountId);
    inputs[1] = abi.encode(address(token), depositAmount + liquidationBooster);
    inputs[2] = abi.encode(accountId, address(token), depositAmount);
    inputs[3] = abi.encode(
      accountId,  // accountId
      marketId,
      maturityTimestamp,
      -14100, // 4.1%
      -13620, // 3.9% 
      getLiquidityForBase(-14100, -13620, baseAmount)    
    );

    peripheryProxy.execute(commands, inputs, block.timestamp + 100);  
  }

  function mintExistingAccount(
    uint128 marketId,
    address tokenAddress,
    uint128 accountId,
    uint32 maturityTimestamp,
    uint256 depositAmount,
    int256 leverage,  // positive means VT, negative means FT
    address aaveRateOracleAddress
  ) public {
    vm.startBroadcast();

    AaveRateOracle aaveRateOracle = AaveRateOracle(aaveRateOracleAddress);
    uint256 liquidationBooster = coreProxy.getCollateralConfiguration(tokenAddress).liquidationBooster;
    int256 baseAmount = sd59x18(int256(depositAmount) * leverage).div(aaveRateOracle.getCurrentIndex().intoSD59x18()).unwrap();

    IERC20 token = IERC20(tokenAddress);
    token.approve(address(peripheryProxy), depositAmount + liquidationBooster);

    bytes memory commands = abi.encodePacked(
      bytes1(uint8(Commands.TRANSFER_FROM)),
      bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
    );

    bytes[] memory inputs = new bytes[](3);
    inputs[0] = abi.encode(address(token), depositAmount + liquidationBooster);
    inputs[1] = abi.encode(accountId, address(token), depositAmount);
    inputs[2] = abi.encode(
      accountId,  // accountId
      marketId,
      maturityTimestamp,
      -14100, // 4.1%
      -13620, // 3.9% 
      getLiquidityForBase(-14100, -13620, baseAmount)    
    );

    peripheryProxy.execute(commands, inputs, block.timestamp + 100);  
  }

  function swapNewAccount(
    uint128 marketId,
    address tokenAddress,
    uint128 accountId,
    uint32 maturityTimestamp,
    uint256 depositAmount,
    int256 leverage,  // positive means VT, negative means FT
    address aaveRateOracleAddress
  ) public {
    addNewRoot(msg.sender);

    vm.startBroadcast();

    AaveRateOracle aaveRateOracle = AaveRateOracle(aaveRateOracleAddress);
    uint256 liquidationBooster = coreProxy.getCollateralConfiguration(tokenAddress).liquidationBooster;
    int256 baseAmount = sd59x18(int256(depositAmount) * leverage).div(aaveRateOracle.getCurrentIndex().intoSD59x18()).unwrap();

    IERC20 token = IERC20(tokenAddress);
    token.approve(address(peripheryProxy), depositAmount + liquidationBooster);

    accessPassNft.redeem(
      msg.sender,
      1,
      merkle.getProof(addressPassNftInfo.values(), 1),
      merkle.getRoot(addressPassNftInfo.values())
    );

    bytes memory commands = abi.encodePacked(
      bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
      bytes1(uint8(Commands.TRANSFER_FROM)),
      bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
    );
    bytes[] memory inputs = new bytes[](4);
    inputs[0] = abi.encode(accountId);
    inputs[1] = abi.encode(address(token), depositAmount + liquidationBooster);
    inputs[2] = abi.encode(accountId, address(token), depositAmount);
    inputs[3] = abi.encode(
      accountId,
      marketId,
      maturityTimestamp,
      baseAmount,
      (baseAmount > 0) ? TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK + 1) : TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK - 1)
    );

    peripheryProxy.execute(commands, inputs, block.timestamp + 100); 
  }

  function swapExistingAccount(
    uint128 marketId,
    address tokenAddress,
    uint128 accountId,
    uint32 maturityTimestamp,
    uint256 depositAmount,
    int256 leverage,  // positive means VT, negative means FT
    address aaveRateOracleAddress
  ) public {
    vm.startBroadcast();

    AaveRateOracle aaveRateOracle = AaveRateOracle(aaveRateOracleAddress);
    uint256 liquidationBooster = coreProxy.getCollateralConfiguration(tokenAddress).liquidationBooster;
    int256 baseAmount = sd59x18(int256(depositAmount) * leverage).div(aaveRateOracle.getCurrentIndex().intoSD59x18()).unwrap();

    IERC20 token = IERC20(tokenAddress);
    token.approve(address(peripheryProxy), depositAmount + liquidationBooster);

    bytes memory commands = abi.encodePacked(
      bytes1(uint8(Commands.TRANSFER_FROM)),
      bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
      bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
    );
    bytes[] memory inputs = new bytes[](3);
    inputs[0] = abi.encode(address(token), depositAmount + liquidationBooster);
    inputs[1] = abi.encode(accountId, address(token), depositAmount);
    inputs[2] = abi.encode(
      accountId,
      marketId,
      maturityTimestamp,
      baseAmount,
      (baseAmount > 0) ? TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK + 1) : TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK - 1)
    );

    peripheryProxy.execute(commands, inputs, block.timestamp + 100); 
  }

  function getLiquidityForBase(
    int24 tickLower,
    int24 tickUpper,
    int256 baseAmount
  ) private pure returns (int128 liquidity) {
    // get sqrt ratios
    uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
    uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

    if (sqrtRatioAX96 > sqrtRatioBX96)
        (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
    uint256 absLiquidity = FullMath
            .mulDiv(uint256(baseAmount > 0 ? baseAmount : -baseAmount), VAMMBase.Q96, sqrtRatioBX96 - sqrtRatioAX96);

    return baseAmount > 0 ? absLiquidity.toInt().to128() : -(absLiquidity.toInt().to128());
  } 
}