import { ethers } from 'hardhat'
import { toBN } from '@lyrafinance/protocol/dist/scripts/util/web3utils'
import {
  lyraEvm,
  TestSystem,
  lyraConstants,
  lyraDefaultParams
} from '@lyrafinance/protocol'
import { 
  DeployOverrides, 
  TestSystemContractsType
} from '@lyrafinance/protocol/dist/test/utils/deployTestSystem'
import { BigNumber } from 'ethers'


// testing system parameters
const overrides: DeployOverrides = {
  pricingParams: {
    ...lyraDefaultParams.PRICING_PARAMS,
    standardSize: toBN('1'),
    spotPriceFeeCoefficient: toBN('0'),
  },
}
const spotPrice = toBN('1000')
const boardParameter = {
  expiresIn: lyraConstants.DAY_SEC * 3,
  baseIV: '0.9',
  skews: ['0.9', '0.8', '0.7'],
  strikePrices: ['900', '1000', '1100'],
}
const initialBalance = toBN('1500000') // 1.5m

// deployer wallet / provider
const privateKey = '0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0'
const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
const deployer = new ethers.Wallet(privateKey, provider)
provider.getGasPrice = async () => { return ethers.BigNumber.from('0') }
provider.estimateGas = async () => { return ethers.BigNumber.from(15000000) }

// constants
const ERC_20_ARTIFACT = '@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20'
const ERC_721_ARTIFACT = '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol:ERC721Enumerable'
const AMOUNT_OF_CONTRACTS = 100000
const QUOTE_ASSET_NAME = 'USDC'
const BASE_ASSET_NAME = 'ETH'
const STRADDLE_ARTIFACT = 'Straddle'
const STRIKE_ID = 2

async function main() {
  // 1. set up test system
  const testSystem = await setUpTestSystem()
  if (!testSystem) {
    return
  }

  // 2. set up vault
  const baseAssetAddress = testSystem.snx.baseAsset.address // ETH
  const quoteAssetAddress = testSystem.snx.quoteAsset.address // USD
  const optionTokenAddress = testSystem.optionToken.address

  // 3. set up straddle
  const Straddle = await ethers.getContractFactory(STRADDLE_ARTIFACT, deployer)
  const straddle = await Straddle.deploy()
  await straddle.connect(deployer).initAdapter(
    testSystem.lyraRegistry.address,
    testSystem.optionMarket.address,
    testSystem.testCurve.address,
    testSystem.basicFeeCounter.address,
  )
  
  // 4. approve collateral
  const quoteAsset = await ethers.getContractAt(ERC_20_ARTIFACT, quoteAssetAddress)
  const amountToApprove = await straddle.connect(deployer).getQuoteAssetAmountFromOptionsAmount(AMOUNT_OF_CONTRACTS, STRIKE_ID)
  await quoteAsset.connect(deployer).approve(straddle.address, amountToApprove)
  
  // 5. add straddle contract as trusted counter on BasicFeeCounter
  await testSystem.basicFeeCounter.connect(deployer).setTrustedCounter(straddle.address, true)
  
  // 6. buy straddle
  await logAssetBalances(deployer.address, 'Deployer', quoteAssetAddress, baseAssetAddress)
  const result = await straddle.connect(deployer).buyStraddle(STRIKE_ID, AMOUNT_OF_CONTRACTS)
  await result.wait()
  console.log('\n==== STRADDLE POSITIONS ====\n')
  const [longCallPositionId, longPutPositionId] = await straddle.connect(deployer).viewPosition(0)
  console.log(longCallPositionId, longPutPositionId)
  console.log('\n==== AFTER STRADDLE BUY ====\n')
  await logAssetBalances(
    deployer.address,
    'Deployer',
    quoteAssetAddress,
    baseAssetAddress,
    optionTokenAddress,
    BigNumber.from(longCallPositionId),
    BigNumber.from(longPutPositionId)
  )
}

async function setUpTestSystem(): Promise<TestSystemContractsType | undefined> {
  try {
    const localTestSystem = await TestSystem.deploy(deployer, false, false, overrides)
    await TestSystem.seed(deployer, localTestSystem, {
      initialBoard: boardParameter,
      initialBasePrice: spotPrice,
      initialPoolDeposit: initialBalance,
    })
    const boardId = (await localTestSystem.optionMarket.getLiveBoards())[0]
    await localTestSystem.optionGreekCache.updateBoardCachedGreeks(ethers.BigNumber.from(boardId))
    await lyraEvm.fastForward(600)

    return localTestSystem
  } catch (error) {
    console.log('Error setting up test system', error)
  }

  return undefined
}

async function logAssetBalances(
  address: string,
  name: string,
  quoteAssetAddress: string,
  baseAssetAddress: string,
  optionTokenAddress?: string,
  longCallPositionId?: BigNumber,
  longPutPositionId?: BigNumber,
): Promise<void> {
  try {
    const baseAsset = await ethers.getContractAt(ERC_20_ARTIFACT, baseAssetAddress)
    const quoteAsset = await ethers.getContractAt(ERC_20_ARTIFACT, quoteAssetAddress)
    const baseAssetBalance = await baseAsset.connect(deployer).balanceOf(address)
    const quoteAssetBalance = await quoteAsset.connect(deployer).balanceOf(address)
    console.log(`${name}: ${address}\n\t${baseAssetBalance.toString()} $${BASE_ASSET_NAME}\n\t${quoteAssetBalance.toString()} $${QUOTE_ASSET_NAME}`)
    if (optionTokenAddress) {
      const optionToken = await ethers.getContractAt(ERC_721_ARTIFACT, optionTokenAddress)
      if (longCallPositionId) {
        const longCallPosition = await optionToken.connect(deployer).ownerOf(longCallPositionId)
        console.log(`\tLong Call Position Owner: ${longCallPosition}`)
      }
      if (longPutPositionId) {
        const longPutPosition = await optionToken.connect(deployer).ownerOf(longPutPositionId)
        console.log(`\tLong Put Position Owner: ${longPutPosition}\n`)
      }
    }
  } catch (error) {
    console.log('Error logging asset balances', error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})