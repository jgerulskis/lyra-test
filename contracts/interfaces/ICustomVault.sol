// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


interface ICustomVault {
    error NoStrategySet();

    event StrategyUpdated(address strategy);

    function buyStraddle(uint256 _strikeId, uint256 _amountSUSD) external;

    function getStrategyAddress() external view returns (address);
}