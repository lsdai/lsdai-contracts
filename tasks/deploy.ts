import { task, types } from 'hardhat/config';
import { BigNumberish, utils } from 'ethers';
import { HardhatEthersHelpers } from 'hardhat/types';
import { cancelPrompt } from './utils';

const DEFAULT_INITIALIZE_ARGS: LSDaiInitializeArgs = {
  depositCap: utils.parseEther((0.0001).toString()),
  interestFee: 250,
  withdrawalFee: 1,
  feeRecipient: '0x000000000000000000000000000000000000dead',
};

/**
 * Deploys contracts
 * - Deploys LSDai instance
 * - Deploys ProxyAdmin instance
 * - Deploys TransparentUpgradeableProxy instance for LSDai
 * - Does not initialize LSDai instance
 */
task('deploy', 'Deploy contracts')
  .addParam('feeRecipient', 'Address of the fee recipient', '', types.string)
  .setAction(async function (
    taskArgs: {
      feeRecipient: string;
    },
    { ethers }
  ) {
    const { feeRecipient } = taskArgs;

    if (!feeRecipient || utils.isAddress(feeRecipient) === false) {
      throw new Error('A fee recipient must be specified');
    }

    let [deployer] = await ethers.getSigners();

    const deployerAddress = await deployer.getAddress();

    if (!deployerAddress) {
      throw new Error('No deployer address found');
    }

    console.log('Deployer address:', deployerAddress);
    console.log('Fee recipient address:', feeRecipient);

    // give user 10 seconds to cancel the transaction
    await cancelPrompt(10);

    const { lsdai } = await deployLSDaiImplementation({
      ethers,
      initializeArgs: {
        depositCap: utils.parseEther((0).toString()), // 0 deposit cap, no limit
        interestFee: 250,
        withdrawalFee: 1,
        feeRecipient,
      },
    });

    await printLSDaiInfo(lsdai.address, ethers);
  });

/**
 * Deploys contracts
 * - Deploys LSDai instance
 * - Deploys ProxyAdmin instance
 * - Deploys TransparentUpgradeableProxy instance for LSDai
 * - Does not initialize LSDai instance
 */
task('deploy:proxy', 'Deploy contracts')
  .addParam('proxyAdminOwner', 'Address of the proxy admin owner', '', types.string)
  .addParam('feeRecipient', 'Address of the fee recipient', '', types.string)
  .setAction(async function (
    taskArgs: {
      proxyAdminOwner: string;
      feeRecipient: string;
    },
    { ethers }
  ) {
    const { proxyAdminOwner, feeRecipient } = taskArgs;
    if (!proxyAdminOwner || utils.isAddress(proxyAdminOwner) === false) {
      throw new Error('A proxy admin owner must be specified');
    }
    if (!feeRecipient || utils.isAddress(feeRecipient) === false) {
      throw new Error('A fee recipient must be specified');
    }

    let [deployer] = await ethers.getSigners();

    const deployerAddress = await deployer.getAddress();

    if (!deployerAddress) {
      throw new Error('No deployer address found');
    }

    // give user 10 seconds to cancel the transaction
    await cancelPrompt(10);

    // Deploy the LSDai implementation with dummy initialize args
    const { lsdai } = await deployLSDaiImplementation({ ethers, initializeArgs: DEFAULT_INITIALIZE_ARGS });

    const { proxy: lsdaiProxy, proxyAdmin } = await deployProxy({
      implementationAddress: lsdai.address,
      proxyAdminOwner,
      ethers,
    });

    await printLSDaiInfo(lsdaiProxy.address, ethers);
  });

async function printLSDaiInfo(lsDaiAdress: string, ethers: HardhatEthersHelpers) {
  const lsDai = await ethers.getContractAt('LSDai', lsDaiAdress);

  const [lsDaiName, lsDaiSymbol, lsDaiDecimals, lsDaiTotalSupply, lsDaiOwner, lsDaiDepositCap] = await Promise.all([
    lsDai.name(),
    lsDai.symbol(),
    lsDai.decimals(),
    lsDai.totalSupply(),
    lsDai.owner(),
    lsDai.depositCap(),
  ]);

  console.log('LSDai name:', lsDaiName);
  console.log('LSDai symbol:', lsDaiSymbol);
  console.log('LSDai decimals:', lsDaiDecimals.toString());
  console.log('LSDai total supply:', lsDaiTotalSupply.toString());
  console.log('LSDai owner:', lsDaiOwner);
  console.log('LSDai deposit cap:', utils.formatUnits(lsDaiDepositCap.toString(), 18));
}

async function deployProxy({
  implementationAddress,
  proxyAdminOwner,
  ethers,
}: {
  implementationAddress: string;
  proxyAdminOwner: string;
  ethers: HardhatEthersHelpers;
}) {
  // ProxyAdmin
  const ProxyAdmin = await ethers.getContractFactory('ProxyAdmin');
  const proxyAdmin = await ProxyAdmin.deploy();

  console.log(`ProxyAdmin deployed to: ${proxyAdmin.address}`);

  console.log('Transferring ownership of ProxyAdmin to', proxyAdminOwner);
  proxyAdmin.transferOwnership(proxyAdminOwner);
  console.log('Transferred ownership of ProxyAdmin to', proxyAdminOwner);

  console.log('Deploying TransparentUpgradeableProxy for LSDai');
  const TransparentUpgradeableProxy = await ethers.getContractFactory('TransparentUpgradeableProxy');
  const proxy = await TransparentUpgradeableProxy.deploy(
    implementationAddress,
    proxyAdmin.address,
    (await ethers.getContractFactory('LSDai')).interface.encodeFunctionData('initialize')
  );

  console.log(`TransparentUpgradeableProxy deployed to: ${proxy.address}`);

  return {
    proxyAdmin,
    proxy,
  };
}

type LSDaiInitializeArgs = {
  depositCap: BigNumberish;
  interestFee: BigNumberish;
  withdrawalFee: BigNumberish;
  feeRecipient: string;
};

/**
 * Deploys LSDai implementation
 * @param ethers ethers helper
 * @param initializeArgs LSDai initialize args
 */
async function deployLSDaiImplementation({
  ethers,
  initializeArgs,
}: {
  ethers: HardhatEthersHelpers;
  initializeArgs: LSDaiInitializeArgs;
}) {
  const LSDai = await ethers.getContractFactory('LSDai');

  console.log(LSDai);
  console.log('Deploying LSDai implementation');
  const lsdai = await LSDai.deploy();
  console.log(`LSDai implementation deployed to: ${lsdai.address}`);

  const { depositCap, interestFee, withdrawalFee, feeRecipient } = initializeArgs;

  await lsdai.initialize(depositCap, interestFee, withdrawalFee, feeRecipient); // 0x0 reverts
  console.log('Initialized LSDai implementation');
  return { lsdai };
}
