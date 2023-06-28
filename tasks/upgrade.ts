import { task, types } from 'hardhat/config';
import { utils } from 'ethers';
import { HardhatEthersHelpers } from 'hardhat/types';

/**
 * Upgrades a proxy
 */
task('upgrade', 'Upgrades a proxy')
  .addParam('proxyAdminAddress', 'Address of the proxy admin', '', types.string)
  .addParam('implementationAddress', 'Address of the implementation', '', types.string)
  .addParam('proxyAddress', 'Address of the proxy to upgrade its implementation', '', types.string)
  .setAction(async function (
    taskArgs: {
      proxyAdminAddress: string;
      implementationAddress: string;
      proxyAddress: string;
    },
    { ethers }
  ) {
    const { proxyAdminAddress, implementationAddress, proxyAddress } = taskArgs;

    let [deployer] = await ethers.getSigners();

    const deployerAddress = await deployer.getAddress();

    if (!deployerAddress) {
      throw new Error('No deployer address found');
    }

    await upgradeProxy({
      proxyAdminAddress,
      implementationAddress,
      proxyAddress,
      ethers,
    });
  });

export async function upgradeProxy({
  proxyAdminAddress,
  proxyAddress,
  implementationAddress,
  ethers,
}: {
  proxyAdminAddress: string;
  proxyAddress: string;
  implementationAddress: string;
  ethers: HardhatEthersHelpers;
}) {
  if (!proxyAdminAddress || utils.isAddress(proxyAdminAddress) === false) {
    throw new Error('A proxy admin address must be specified');
  }

  if (!implementationAddress || utils.isAddress(implementationAddress) === false) {
    throw new Error('An implementation address must be specified');
  }

  if (!proxyAddress || utils.isAddress(proxyAddress) === false) {
    throw new Error('A proxy address must be specified');
  }

  const proxyAdmin = await ethers.getContractAt('ProxyAdmin', proxyAdminAddress);

  const proxyAdminOwner = await proxyAdmin.owner();
  const deployer = (await ethers.getSigners())[0].address;

  if (proxyAdminOwner.toLowerCase() !== deployer.toLowerCase()) {
    throw new Error(`ProxyAdmin owner is not the deployer. ProxyAdmin owner: ${proxyAdminOwner}`);
  }

  console.log('Upgrading proxy');

  await proxyAdmin.upgrade(proxyAddress, implementationAddress);

  console.log('Upgraded proxy');

  return {
    proxyAdmin,
  };
}
