// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LyraAdapter } from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";
import { IOptionMarket } from "@lyrafinance/protocol/contracts/interfaces/IOptionMarket.sol";

import { StrategyBase } from "./StrategyBase.sol";
import { IStraddle } from "../interfaces/IStraddle.sol";
import { CustomVault } from "../vaults/CustomVault.sol";
import { DecimalMath } from "../libraries/DecimalMath.sol";


/// @title Straddle Stategy
/// @notice This strategy buys equivalent sUSD amounts of call and put options.
/// It accounts for the actual price of the put / call by interacting with GWAV price oracle. It
/// does not blindly assume that calls and puts are priced 1:1
contract Straddle is StrategyBase, IStraddle {
    using DecimalMath for uint;
    
    /// @dev TODO: use positions to track, reduce, increase, or close straddle positions
    mapping(address => Position[]) private positions;

    constructor(CustomVault _vault) StrategyBase(_vault) {}

    /// @notice Buys a straddle by buying equivalent amount of call and put options
    /// @param _buyer The address of the buyer
    /// @param _strikeId The strike id
    /// @param _amountSUSD The amount of collateral to use to buy the straddle
    function buyStraddle(
        address _buyer,
        uint256 _strikeId,
        uint256 _amountSUSD
    ) external {
        collectCollateral(_buyer, _amountSUSD);
        (uint256 callAmount, uint256 putAmount) = _getAmountsForStraddle(_strikeId, _amountSUSD);

        TradeInputParameters memory longCallTradeParams = TradeInputParameters({
            strikeId: _strikeId,
            positionId: 0,
            iterations: 1,
            optionType: _longCall,
            amount: callAmount,
            setCollateralTo: 0,
            minTotalCost: 0,
            maxTotalCost: type(uint).max,
            rewardRecipient: address(0)
        });

        TradeInputParameters memory longPutTradeParams = TradeInputParameters({
            strikeId: _strikeId,
            positionId: 0,
            iterations: 1,
            optionType: _longPut,
            amount: putAmount,
            setCollateralTo: _getMinCollateral(_strikeId, putAmount),
            minTotalCost: 0,
            maxTotalCost: type(uint256).max,
            rewardRecipient: address(this)
        });

        TradeResult memory longCallResult = _openPosition(longCallTradeParams);
        TradeResult memory longPutResult = _openPosition(longPutTradeParams);
        
        positions[_buyer].push(Position({
            callPositionId: longCallResult.positionId,
            putPositionId: longPutResult.positionId,
            callCost: longCallResult.totalCost,
            putCost: longPutResult.totalCost
        }));

        _refundExcessQuoteAsset(_buyer);
    }

    /// @notice View a position, any user can have multiple open
    /// @param _index The index of the position for the msg.sender
    function viewPosition(uint256 _index) external view returns (Position memory) {
        return positions[msg.sender][_index];
    }

    /// @notice gets the amount of collateral for call / put of a straddle
    /// @param _strikeId The strike id
    /// @param _amountSUSD The amount of collateral to use to buy the straddle
    /// @return amount The amount of collateral for call and buy given the amount of sUSD
    function _getAmountsForStraddle(uint256 _strikeId, uint256 _amountSUSD) private view returns (uint256, uint256) {
        /// @dev TODO: accounts for fees
        ExchangeRateParams memory exchangeRateParams = _getExchangeParams();
        uint256 conversion = exchangeRateParams.spotPrice.multiplyDecimal(exchangeRateParams.baseQuoteFeeRate);
        uint256 convertedAmount = _amountSUSD.multiplyDecimal(conversion) / 10000;
        (uint callPrice, uint putPrice) = _optionPriceGWAV(_strikeId, 1);

        return (convertedAmount.multiplyDecimal(callPrice), convertedAmount.multiplyDecimal(putPrice));
    }
}