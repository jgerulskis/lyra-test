// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { LyraAdapter } from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import { IStrategyBase } from "../interfaces/IStrategyBase.sol";


/// @title Base strategy contract
/// @notice Includes basic abstract functionality of a strategy
contract StrategyBase is LyraAdapter, IStrategyBase {
    LyraAdapter.OptionType immutable internal _longCall = LyraAdapter.OptionType(0);
    LyraAdapter.OptionType immutable internal _longPut = LyraAdapter.OptionType(1);

    modifier isValidAmount(uint256 _amount) {
        if (_amount == 0) {
            revert InvalidAmount(_amount);
        }
        _;
    }

    constructor() {}

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
    }

    /// @notice Collects quote asset from user
    /// @param _user The user to collect from
    /// @param _amount The amount of quote asset to collect
    function _collectQuoteAsset(address _user, uint256 _amount) internal {       
        if (!quoteAsset.transferFrom(_user, address(this), _amount)) {
            revert FailedTransfer(_user, address(quoteAsset), _amount);
        }
    }

    /// @notice Refunds excess collateral left in contract
    /// @param _user The user to refund
    function _refundExcessQuoteAsset(address _user) internal {
        uint256 _balance = quoteAsset.balanceOf(address(this));
        if (_balance > 0) {
            /// @dev the strategy contract should never hold any remaining quote assets after a trade
            if (!quoteAsset.transfer(_user, _balance)) {
                revert FailedTransfer(_user, address(quoteAsset), _balance);
            }
        }
    }

    /// @notice transfers the option token to a user
    /// @param _user The user to transfer to
    /// @param _optionId The option token id to transfer
    function _transferOptionToken(address _user, uint256 _optionId) internal {
        if (!(optionToken.ownerOf(_optionId) == address(this))) {
            revert FailedTransfer(_user, address(optionToken), 1);
        }

        optionToken.transferFrom(address(this), _user, _optionId);
    }
}