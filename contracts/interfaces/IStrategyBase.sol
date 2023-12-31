// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


/// @notice Interface for all strategies
interface IStrategyBase {
    error FailedTransfer(address to, address asset, uint256 amount);
    error InvalidAmount(uint256 amount);

    event Initialized(address indexed _optionMarket, address indexed _curveSwap, address indexed _feeCounter);

    function initAdapter(address _lyraRegistry, address _optionMarket, address _curveSwap, address _feeCounter) external;
}