// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Erc20, CErc20, CEth, Comptroller, PriceFeed, OptionCreateFactory} from "./interface.sol";
import {IOptionHelper} from "./IOptionHelper.sol";
import {IOptionAMMFactory} from "./IOptionAMMFactory.sol";
import "./IPodOption.sol";

contract MyContract {
    event MyLog(string, uint256);
    OptionCreateFactory optionFactory = OptionCreateFactory(0x43fF98EB7Ec681A7DBF7e2b2C3589E79d5ce11E3);
    IOptionAMMFactory factory = IOptionAMMFactory(0x43fF98EB7Ec681A7DBF7e2b2C3589E79d5ce11E3);
    IOptionHelper optionHelper = IOptionHelper(0xCb674dF88EC8103fef28d1995efD400905c6adF6);

    function borrowErc20Example(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _priceFeedAddress,
        address _cTokenAddress,
        uint _underlyingDecimals
    ) public payable returns (uint256) {
        CEth cEth = CEth(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        PriceFeed priceFeed = PriceFeed(_priceFeedAddress);
        CErc20 cToken = CErc20(_cTokenAddress);

        // Supply ETH as collateral, get cETH in return
        cEth.mint{ value: msg.value, gas: 250000 }();

        address[] memory cTokens = new address[](1);
        cTokens[0] = _cEtherAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(address(this));
        if (error != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "account underwater");
        require(liquidity > 0, "account has excess collateral");

        uint256 underlyingPrice = priceFeed.getUnderlyingPrice(_cTokenAddress);
        uint256 maxBorrowUnderlying = liquidity / underlyingPrice;

        emit MyLog("Maximum underlying Borrow (borrow far less!)", maxBorrowUnderlying);

        // Borrow underlying
        uint256 numUnderlyingToBorrow = 10;

        // Borrow, check the underlying balance for this contract's address
        cToken.borrow(numUnderlyingToBorrow * 10**_underlyingDecimals);

        uint256 borrows = cToken.borrowBalanceCurrent(address(this));
        emit MyLog("Current underlying borrow amount", borrows);

        return borrows;
    }


    function createAnOption(
        string memory name,
        string memory symbol

    ) public returns (address) {

        // Parameters example
        name = "WETH:USDC 12000 8Dec 2021";
        symbol = "PodPut WETH:USDC";

        address underlyingAsset = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //WETH

        address strikeAsset = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //usdc

        uint256 strikePrice = 1200000000; // Using 6 decimals, equal to strikeAsset decimals
        uint256 expiration = 1609401600; // timestamp in seconds: 31 Dec 2020 08AM
        uint256 exerciseWindowSize = 86400; // 24H in seconds
        bool isAave = false; // if the collateral token is not aTokens

        address optionAddress = optionFactory.createOption(
            name, 
            symbol, 
            IPodOption.OptionType.PUT, 
            IPodOption.ExerciseType.EUROPEAN, 
            underlyingAsset, 
            strikeAsset, 
            strikePrice, 
            expiration, 
            exerciseWindowSize, 
            isAave
        );

        return optionAddress;

    }

    function createPool(address optionAddress, address stableAsset, uint initialImpliedVolatility) public {
        factory.createPool(optionAddress, stableAsset, initialImpliedVolatility);
    }
  
    function addLiquidity(IPodOption option, uint optionAmount, uint tokenAmount) public {
        optionHelper.mintAndAddLiquidity(option, optionAmount, tokenAmount);
    }


    
}
