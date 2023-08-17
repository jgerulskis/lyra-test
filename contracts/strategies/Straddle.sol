// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


import { LyraAdapter } from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";
import { IOptionMarket } from "@lyrafinance/protocol/contracts/interfaces/IOptionMarket.sol";

import { StrategyBase } from "./StrategyBase.sol";
import { IStraddle } from "../interfaces/IStraddle.sol";
import { DecimalMath } from "../libraries/DecimalMath.sol";

import "hardhat/console.sol";


/// @title Straddle Stategy
/// @notice This strategy buys equivalent sUSD amounts of call and put options.
/// It accounts for the actual price of the put / call by interacting with GWAV price oracle. It
/// does not blindly assume that calls and puts are priced 1:1
contract Straddle is StrategyBase, IStraddle {
    using DecimalMath for uint;
    
    /// @dev TODO: use positions to track, reduce, increase, or close straddle positions
    mapping(address => Position[]) private positions;

    constructor() StrategyBase() {}

    /// @notice Buys a straddle by buying equivalent amount of call and put options
    /// @param _strikeId The strike id
    /// @param _amount of contracts to buy for call and put
    function buyStraddle(
        uint256 _strikeId,
        uint256 _amount
    ) external isValidAmount(_amount) {
        uint256 quoteAssetAmount = this.getQuoteAssetAmountFromOptionsAmount(_amount, _strikeId);
        _collectQuoteAsset(msg.sender, quoteAssetAmount);

        TradeInputParameters memory longCallTradeParams = _createTradeParams(_strikeId, _amount, _longCall);
        TradeInputParameters memory longPutTradeParams = _createTradeParams(_strikeId, _amount, _longPut);

        TradeResult memory longCallResult = _openPosition(longCallTradeParams);
        TradeResult memory longPutResult = _openPosition(longPutTradeParams);

        positions[msg.sender].push(Position({
            callPositionId: longCallResult.positionId,
            putPositionId: longPutResult.positionId,
            callCost: longCallResult.totalCost,
            putCost: longPutResult.totalCost
        }));

        _transferBothOptionTokens(msg.sender, longCallResult.positionId, longPutResult.positionId);
        _refundExcessQuoteAsset(msg.sender);
    }

    /// @notice View a position, any user can have multiple open
    /// @param _index The index of the position for the msg.sender
    function viewPosition(uint256 _index) external view returns (Position memory) {
        return positions[msg.sender][_index];
    }

    /// @notice View all positions for a user
    /// @param _user The user to view positions for
    function viewAllPositions(address _user) external view returns (Position[] memory) {
        return positions[_user];
    }

    /// @notice Gets the quote asset amount required to buy a straddle
    /// @param _amount The amount of contracts to buy for call and put
    /// @param _strikeId The strike id
    function getQuoteAssetAmountFromOptionsAmount(
        uint256 _amount,
        uint256 _strikeId
    ) external view isValidAmount(_amount) returns (uint256) {
        (uint256 callPrice, uint256 putPrice) = _optionPriceGWAV(_strikeId, 1);
        uint256 totalAmount = _amount * callPrice / 1 ether + _amount * putPrice / 1 ether;
        /// @dev add 10% buffer for option fees
        return totalAmount.multiplyByPercentage(110);
    }

    /// @notice create trade params for a long call or long put
    /// @param _strikeId The strike id
    /// @param _amount The amount of contracts to buy
    /// @param _optionType The option type
    /// @return TradeInputParameters to open a position with
    function _createTradeParams(
        uint256 _strikeId,
        uint256 _amount,
        LyraAdapter.OptionType _optionType
    ) internal pure returns (TradeInputParameters memory) {
        return TradeInputParameters({
            strikeId: _strikeId,
            positionId: 0,
            iterations: 1,
            optionType: _optionType,
            amount: _amount,
            setCollateralTo: 0,
            minTotalCost: 0,
            maxTotalCost: type(uint256).max,
            rewardRecipient: address(0)
        });
    }

    /// @notice transfer option tokens from opened position
    /// @param _user The user to transfer to
    /// @param _callOptionId The call option id
    /// @param _putOptionId The put option id
    function _transferBothOptionTokens(
        address _user,
        uint256 _callOptionId,
        uint256 _putOptionId
    ) internal {
        _transferOptionToken(_user, _callOptionId);
        _transferOptionToken(_user, _putOptionId);
    }
}