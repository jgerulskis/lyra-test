// deployLyraExample.ts
import { TestSystem, lyraDefaultParams, lyraUtils, } from '@lyrafinance/protocol';
import { toBN } from '@lyrafinance/protocol/dist/scripts/util/web3utils';
import { DeployOverrides } from '@lyrafinance/protocol/dist/test/utils/deployTestSystem';
import { ethers } from 'hardhat';

async function main() {
  const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
  const privateKey = '0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0';

  provider.getGasPrice = async () => { return ethers.BigNumber.from('0') }
  provider.estimateGas = async () => { return ethers.BigNumber.from(15000000) }
  
  const deployer = new ethers.Wallet(privateKey, provider);
  console.log(`Using deployer with address ${deployer.address}`);

  const exportAddresses = true;
  const enableTracer = false;
  const overrides: DeployOverrides = {
    minCollateralParams: {
      ...lyraDefaultParams.MIN_COLLATERAL_PARAMS,
      minStaticBaseCollateral: lyraUtils.toBN('0.001'),
    },
  };

  const localTestSystem = await TestSystem.deploy(deployer, enableTracer, exportAddresses, overrides);
  await TestSystem.seed(deployer, localTestSystem);

  const boardIds = await localTestSystem.optionMarket.getLiveBoards();
  const boardId = boardIds[Math.floor(Math.random() * boardIds.length)];
  const strikeIds = await localTestSystem.optionMarket.getBoardStrikes(boardId);
  const strikeId = strikeIds[Math.floor(Math.random() * strikeIds.length)];
  
  await localTestSystem.optionMarket.openPosition({
    strikeId: strikeId,
    positionId: 0,
    amount: toBN('1'),
    setCollateralTo: toBN('0'),
    iterations: 3,
    optionType: TestSystem.OptionType.LONG_CALL,
    minTotalCost: toBN('0'),
    maxTotalCost: toBN('500'),
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});