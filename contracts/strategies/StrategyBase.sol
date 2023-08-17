// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { LyraAdapter } from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";

import { CustomVault } from "../vaults/CustomVault.sol";
import { IStrategyBase } from "../interfaces/IStrategyBase.sol";


/// @title Base strategy contract
/// @notice Includes basic abstract functionality of a strategy
contract StrategyBase is LyraAdapter, ReentrancyGuard, IStrategyBase {
    LyraAdapter.OptionType immutable internal _longCall = LyraAdapter.OptionType(0);
    LyraAdapter.OptionType immutable internal _longPut = LyraAdapter.OptionType(1);
    /// @dev The minimum amount of collateral that can be used for a strategy
    uint256 public immutable MIN_COLLATERAL = 0.0001 ether;
    CustomVault internal immutable vault;

    constructor(CustomVault _vault) {
        vault = _vault;
    }

    /// @notice Initializes the adapter
    /// @param _lyraRegistry The address of the LyraRegistry
    /// @param _optionMarket The address of the OptionMarket
    /// @param _curveSwap The address of the CurveSwap
    /// @param _feeCounter The address of the FeeCounter
    function initAdapter(
        address _lyraRegistry,
        address _optionMarket,
        address _curveSwap,
        address _feeCounter
    ) external onlyOwner {
        setLyraAddresses(_lyraRegistry, _optionMarket, _curveSwap, _feeCounter);

        quoteAsset.approve(address(vault), type(uint).max);
        baseAsset.approve(address(vault), type(uint).max);
    }

    /// @notice Collects collateral from user
    /// @param _user The user to collect collateral from
    /// @param _amount The amount of collateral to collect
    function collectCollateral(address _user, uint256 _amount) internal {
        if (_amount < MIN_COLLATERAL) {
            revert InsufficientCollateral();
        }
        
        if (!vault.quoteAsset().transferFrom(_user, address(this), _amount)) {
            revert FailedTransfer(_user, _amount);
        }
    }

    /// @notice Refunds excess collateral left in contract
    /// @param _user The user to refund
    function _refundExcessQuoteAsset(address _user) internal nonReentrant {
        uint256 _balance = vault.quoteAsset().balanceOf(address(this));
        if (_balance > 0) {
            /// @dev the strategy contract should never hold any remaining collateral after a trade
            if (!vault.quoteAsset().transfer(_user, _balance)) {
                revert FailedTransfer(_user, _balance);
            }
        }
    }

    /// @notice creates a dynamic array from a uint
    /// @param val The uint to convert
    /// @return dynamicArray The dynamic array
    function _toDynamic(uint val) internal pure returns (uint[] memory dynamicArray) {
        dynamicArray = new uint[](1);
        dynamicArray[0] = val;
    }

    /// @notice Gets the minimum amount of collateral needed for a put
    /// @param _strikeId The strike id of the put
    /// @param _putAmount Desired amount of puts
    /// @return collateral The minimum amount of collateral needed
    function _getMinCollateral(uint256 _strikeId, uint256 _putAmount) internal view returns (uint256) {
        Strike memory strike = _getStrikes(_toDynamic(_strikeId))[0];
        ExchangeRateParams memory exchangeParams = _getExchangeParams();

        return _getMinCollateral(
            _longPut,
            strike.strikePrice,
            strike.expiry,
            exchangeParams.spotPrice,
            _putAmount
        );
    }
}