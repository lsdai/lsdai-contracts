import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-preprocessor';
import 'hardhat-abi-exporter';
import { config as dotenvConfig } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/config';
import { HttpNetworkUserConfig } from 'hardhat/types';
import { utils } from 'ethers';

import './tasks/accounts';
import './tasks/deploy';
import './tasks/upgrade';

// Load environment variables.
dotenvConfig();

const { MNEMONIC, PK, PRIVATE_KEY, ETHER_SCAN_API_KEY } = process.env;

const DEFAULT_MNEMONIC = 'candy maple cake sugar pudding cream honey rich smooth crumble sweet treat';

const sharedNetworkConfig: HttpNetworkUserConfig = {};
if (PK) {
  sharedNetworkConfig.accounts = [PK];
} else {
  sharedNetworkConfig.accounts = {
    mnemonic: MNEMONIC || DEFAULT_MNEMONIC,
  };
}

const config: HardhatUserConfig = {
  paths: {
    artifacts: 'build/artifacts',
    cache: 'build/cache',
    sources: 'contracts',
  },
  networks: {
    hardhat: {
      chainId: 1,
      forking: {
        url: 'https://eth.llamarpc.com/',
        enabled: true,
      },
      accounts: [
        {
          privateKey: PRIVATE_KEY!,
          balance: utils.parseEther('10000').toString(),
        },
      ],
    },
    ethereum: {
      ...sharedNetworkConfig,
      url: 'https://rpc.mevblocker.io',
      chainId: 1,
    },
    arbitrum: {
      chainId: 42161,
      url: 'https://arb1.arbitrum.io/rpc',
      accounts: [process.env.PRIVATE_KEY!],
    },
    arbitrumTestnet: {
      chainId: 421613,
      url: 'https://goerli-rollup.arbitrum.io/rpc',
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  etherscan: {
    apiKey: {
      mainnet: ETHER_SCAN_API_KEY!,
    },
  },
  abiExporter: {
    format: 'json',
    flat: true,
    filter(abiElement, index, abi, fullyQualifiedName) {
      const contractName = fullyQualifiedName.split(':')[1];
      return ['LSDai'].includes(contractName);
    },
  },
};

export default config;
