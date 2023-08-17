// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


interface IStraddle {
    struct Position {
        uint256 callPositionId;
        uint256 putPositionId;
        uint256 callCost;
        uint256 putCost;
    }

    function buyStraddle(address _buyer, uint256 _strikeId, uint256 _amountSUSD) external;

    function viewPosition(uint256 _index) external view returns (Position memory);
}