pragma solidity >=0.8.19;

import "../utils/ProtocolBase.sol";
import {Utils} from "../utils/Utils.sol";

import {console2} from "forge-std/Script.sol";

import {UD60x18, ud60x18} from "@prb/math/UD60x18.sol";
import {SD59x18, sd59x18} from "@prb/math/SD59x18.sol";

import {TickMath} from "@voltz-protocol/v2-vamm/utils/vamm-math/TickMath.sol";
import {IRateOracle} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import {Commands} from "@voltz-protocol/periphery/src/libraries/Commands.sol";
import {IWETH9} from "@voltz-protocol/periphery/src/interfaces/external/IWETH9.sol";

import {Merkle} from "murky/Merkle.sol";
import {SetUtil} from "@voltz-protocol/util-contracts/src/helpers/SetUtil.sol";

contract ProtocolConfig is ProtocolBase {
  using SetUtil for SetUtil.Bytes32Set;

  SetUtil.Bytes32Set private addressPassNftInfo;
  Merkle private merkle = new Merkle();

  function run() public {
    // Populate with transactions
  }

  function configure_protocol() public {
    acceptOwnerships();
    enableFeatures();
    configureProtocol({
      imMultiplier: ud60x18(2e18),
      liquidatorRewardParameter: ud60x18(5e16),
      feeCollectorAccountId: 999
    });
    registerDatedIrsProduct(1);
    configureMarket({
      rateOracleAddress: address(aaveV3RateOracle),
      tokenAddress: Utils.getUSDCAddress(chainId),
      productId: 1,
      marketId: 1,
      feeCollectorAccountId: 999,
      liquidationBooster: 1e6,
      cap: 1000e6,
      atomicMakerFee: ud60x18(1e16),
      atomicTakerFee: ud60x18(5e16),
      riskParameter: ud60x18(1e18),
      twapLookbackWindow: 120,
      maturityIndexCachingWindowInSeconds: 3600
    });
    deployPool({
      marketId: 1,
      maturityTimestamp: 1688990400,
      rateOracleAddress: address(aaveV3RateOracle),
      priceImpactPhi: ud60x18(1e17), // 0.1
      priceImpactBeta: ud60x18(125e15), // 0.125
      spread: ud60x18(3e15), // 0.3%
      initTick: -13860, // price = 4%
      observationCardinalityNext: 16,
      makerPositionsPerAccountLimit: 1
    });
    mintOrBurn({
      marketId: 1,
      tokenAddress: Utils.getUSDCAddress(chainId),
      accountId: 123,
      maturityTimestamp: 1688990400,
      marginAmount: 10e6,
      notionalAmount: 100e6,
      tickLower: -14100, // 4.1%
      tickUpper: -13620, // 3.9%
      rateOracleAddress: address(aaveV3RateOracle)
    });
  }

  function acceptOwnerships() public {
    acceptOwnership(address(coreProxy));
    acceptOwnership(address(datedIrsProxy));
    acceptOwnership(address(vammProxy));
    acceptOwnership(address(peripheryProxy));
  }

  function enableFeatures() public {
    setFeatureFlagAllowAll({
      feature: _GLOBAL_FEATURE_FLAG,
      allowAll: true
    });
    setFeatureFlagAllowAll({
      feature: _CREATE_ACCOUNT_FEATURE_FLAG, 
      allowAll: true
    });
    setFeatureFlagAllowAll({
      feature: _NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG, 
      allowAll: true
    });

    addToFeatureFlagAllowlist({
      feature: _REGISTER_PRODUCT_FEATURE_FLAG,
      account: owner
    });
  }

  function configureProtocol(
    UD60x18 imMultiplier,
    UD60x18 liquidatorRewardParameter,
    uint128 feeCollectorAccountId
  ) public {  
    setPeriphery({
      peripheryAddress: address(peripheryProxy)
    });

    configureProtocolRisk(
      ProtocolRiskConfiguration.Data({
        imMultiplier:imMultiplier,
        liquidatorRewardParameter: liquidatorRewardParameter
      })
    );

    periphery_configure(
      Config.Data({
        WETH9: IWETH9(Utils.getWETH9Address(chainId)),
        VOLTZ_V2_CORE_PROXY: address(coreProxy),
        VOLTZ_V2_DATED_IRS_PROXY: address(datedIrsProxy),
        VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(vammProxy)
      })
    );

    configureAccessPass(
      AccessPassConfiguration.Data({
        accessPassNFTAddress: address(accessPassNft)
      })
    );

    // create fee collector account owned by protocol owner
    createAccount({
      requestedAccountId: feeCollectorAccountId, 
      accountOwner: owner
    });
  }

  function registerDatedIrsProduct(uint256 _takerPositionsPerAccountLimit) public {
    // predict product id
    uint128 productId = coreProxy.getLastCreatedProductId() + 1;
    console2.log("Predicted Product Id:", productId);

    registerProduct(address(datedIrsProxy), "Dated IRS Product");

    configureProduct(
      ProductConfiguration.Data({
        productId: productId,
        coreProxy: address(coreProxy),
        poolAddress: address(vammProxy),
        takerPositionsPerAccountLimit: _takerPositionsPerAccountLimit
      })
    );

    setProductAddress({
      productAddress: address(datedIrsProxy)
    });
  }

  function configureMarket(
    address rateOracleAddress,
    address tokenAddress,
    uint128 productId,
    uint128 marketId,
    uint128 feeCollectorAccountId,
    uint256 liquidationBooster,
    uint256 cap,
    UD60x18 atomicMakerFee,
    UD60x18 atomicTakerFee,
    UD60x18 riskParameter,
    uint32 twapLookbackWindow,
    uint256 maturityIndexCachingWindowInSeconds
  ) public {
    configureCollateral(
      CollateralConfiguration.Data({
        depositingEnabled: true,
        liquidationBooster: liquidationBooster,
        tokenAddress: tokenAddress,
        cap: cap
      })
    );

    configureMarket(
      MarketConfiguration.Data({
        marketId: marketId,
        quoteToken: tokenAddress
      })
    );

    setVariableOracle({
      marketId: marketId,
      oracleAddress: rateOracleAddress,
      maturityIndexCachingWindowInSeconds: maturityIndexCachingWindowInSeconds
    });

    configureMarketFee(
      MarketFeeConfiguration.Data({
        productId: productId,
        marketId: marketId,
        feeCollectorAccountId: feeCollectorAccountId,
        atomicMakerFee: atomicMakerFee,
        atomicTakerFee: atomicTakerFee
      })
    );

    configureMarketRisk(
      MarketRiskConfiguration.Data({
        productId: productId, 
        marketId: marketId, 
        riskParameter: riskParameter,
        twapLookbackWindow: twapLookbackWindow
      })
    );
  }

  function deployPool(
    uint128 marketId,
    uint32 maturityTimestamp,
    address rateOracleAddress,
    UD60x18 priceImpactPhi,
    UD60x18 priceImpactBeta,
    UD60x18 spread,
    int24 initTick,
    uint16 observationCardinalityNext,
    uint256 makerPositionsPerAccountLimit
  ) public {
    VammConfiguration.Immutable memory immutableConfig = VammConfiguration.Immutable({
        maturityTimestamp: maturityTimestamp,
        _maxLiquidityPerTick: type(uint128).max,
        _tickSpacing: 60,
        marketId: marketId
    });

    VammConfiguration.Mutable memory mutableConfig = VammConfiguration.Mutable({
        priceImpactPhi: priceImpactPhi,
        priceImpactBeta: priceImpactBeta,
        spread: spread,
        rateOracle: IRateOracle(address(rateOracleAddress)),
        minTick: TickMath.DEFAULT_MIN_TICK,
        maxTick: TickMath.DEFAULT_MAX_TICK
    });

    createVamm({
      marketId: marketId,
      sqrtPriceX96: TickMath.getSqrtRatioAtTick(initTick),
      config: immutableConfig,
      mutableConfig: mutableConfig
    });

    increaseObservationCardinalityNext({
      marketId: marketId,
      maturityTimestamp: maturityTimestamp,
      observationCardinalityNext: observationCardinalityNext
    });

    setMakerPositionsPerAccountLimit(makerPositionsPerAccountLimit);
  }

  /// @notice this should only be used for testnet (for mainnet
  /// it should be done through cannon)
  function addNewRoot(address[] memory accountOwners, string memory baseMetadataURI) public {
    addressPassNftInfo.add(keccak256(abi.encodePacked(address(0), uint256(0))));
    addressPassNftInfo.add(keccak256(abi.encodePacked(address(owner), uint256(1))));
    for (uint256 i = 0; i < accountOwners.length; i += 1) {
      bytes32 leaf = keccak256(abi.encodePacked(accountOwners[i], uint256(1)));
      if (!addressPassNftInfo.contains(leaf)) {
        addressPassNftInfo.add(leaf);
      }
    }
    
    addNewRoot(
      AccessPassNFT.RootInfo({
        merkleRoot: merkle.getRoot(addressPassNftInfo.values()),
        baseMetadataURI: baseMetadataURI
      })
    );
  }

  function mintOrBurn(
    uint128 marketId,
    address tokenAddress,
    uint128 accountId,
    uint32 maturityTimestamp,
    uint256 marginAmount,
    int256 notionalAmount,  // positive means mint, negative means burn
    int24 tickLower,
    int24 tickUpper,
    address rateOracleAddress
  ) public {
    IRateOracle rateOracle = IRateOracle(rateOracleAddress);

    uint256 liquidationBooster = coreProxy.getCollateralConfiguration(tokenAddress).liquidationBooster;
    uint256 accountLiquidationBoosterBalance = coreProxy.getAccountLiquidationBoosterBalance(accountId, tokenAddress);

    int256 baseAmount = sd59x18(notionalAmount).div(rateOracle.getCurrentIndex().intoSD59x18()).unwrap();

    erc20_approve(
      IERC20(tokenAddress), 
      address(peripheryProxy), 
      marginAmount + liquidationBooster - accountLiquidationBoosterBalance
    );

    bytes memory commands;
    bytes[] memory inputs;
    if (Utils.existsAccountNft(accountNftProxy, accountId)) {
      commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );
      inputs = new bytes[](3);
    } else {
      commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_VAMM_EXCHANGE_LP))
      );

      inputs = new bytes[](4);
      inputs[0] = abi.encode(accountId);
    }
    inputs[inputs.length-3] = abi.encode(tokenAddress, marginAmount + liquidationBooster - accountLiquidationBoosterBalance);
    inputs[inputs.length-2] = abi.encode(accountId, tokenAddress, marginAmount);
    inputs[inputs.length-1] = abi.encode(
      accountId,
      marketId,
      maturityTimestamp,
      tickLower,
      tickUpper,
      Utils.getLiquidityForBase(tickLower, tickUpper, baseAmount)    
    );

    periphery_execute(commands, inputs, block.timestamp + 100);  
  }

  function swap(
    uint128 marketId,
    address tokenAddress,
    uint128 accountId,
    uint32 maturityTimestamp,
    uint256 marginAmount,
    int256 notionalAmount,  // positive means VT, negative means FT
    address rateOracleAddress
  ) public {
    IRateOracle rateOracle = IRateOracle(rateOracleAddress);

    uint256 liquidationBooster = coreProxy.getCollateralConfiguration(tokenAddress).liquidationBooster;
    uint256 accountLiquidationBoosterBalance = coreProxy.getAccountLiquidationBoosterBalance(accountId, tokenAddress);

    int256 baseAmount = sd59x18(notionalAmount).div(rateOracle.getCurrentIndex().intoSD59x18()).unwrap();

    erc20_approve(
      IERC20(tokenAddress), 
      address(peripheryProxy), 
      marginAmount + liquidationBooster - accountLiquidationBoosterBalance
    );

    bytes memory commands;
    bytes[] memory inputs;
    if (Utils.existsAccountNft(accountNftProxy, accountId)) {
      commands = abi.encodePacked(
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );
      inputs = new bytes[](3);
    } else {
      commands = abi.encodePacked(
        bytes1(uint8(Commands.V2_CORE_CREATE_ACCOUNT)),
        bytes1(uint8(Commands.TRANSFER_FROM)),
        bytes1(uint8(Commands.V2_CORE_DEPOSIT)),
        bytes1(uint8(Commands.V2_DATED_IRS_INSTRUMENT_SWAP))
      );

      inputs = new bytes[](4);
      inputs[0] = abi.encode(accountId);
    }
    inputs[inputs.length-3] = abi.encode(tokenAddress, marginAmount + liquidationBooster - accountLiquidationBoosterBalance);
    inputs[inputs.length-2] = abi.encode(accountId, tokenAddress, marginAmount);
    inputs[inputs.length-1] = abi.encode(
      accountId,
      marketId,
      maturityTimestamp,
      baseAmount,
      0
    );

    periphery_execute(commands, inputs, block.timestamp + 100);  
  }
}