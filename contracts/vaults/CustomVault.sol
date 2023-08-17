//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ICustomVault } from "../interfaces/ICustomVault.sol";
import { IStraddle } from "../interfaces/IStraddle.sol";


/// @notice CustomVault allows modular implementation of IStraddle
/// At the moment this is not really necesarry, but it would be useful down the road
contract CustomVault is Ownable, ICustomVault {
    /// @dev in this implementation, the vault will front the premium asset for the buyer and hold half their sUSD collateral
    IERC20 public immutable quoteAsset;
    IERC20 public immutable baseAsset;
    IStraddle public strategy;

    constructor(address _quoteAssetAddress, address _baseAssetAddress) {
        quoteAsset = IERC20(_quoteAssetAddress);
        baseAsset = IERC20(_baseAssetAddress);
    }

    /// @notice set strategy contract. This function can only be called by owner.
    /// @param _strategy new strategy contract address
    function setStrategy(address _strategy) external onlyOwner {
        strategy = IStraddle(_strategy);
        emit StrategyUpdated(_strategy);
    }

    /// @notice execute a straddle buy with current strategy
    /// @param _strikeId strike id of the straddle
    /// @param _amountSUSD amount of straddle to buy, half calls and half puts
    function buyStraddle(uint256 _strikeId, uint256 _amountSUSD) external {
        if (strategy == IStraddle(address(0))) {
        revert NoStrategySet();
        }

        strategy.buyStraddle(msg.sender, _strikeId, _amountSUSD);
    }

    /// @return address of the strategy contract
    function getStrategyAddress() external view returns (address) {
        return address(strategy);
    }
}
