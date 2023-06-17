import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-preprocessor';
import 'hardhat-abi-exporter';

import { config as dotenvConfig } from 'dotenv';

import { readFileSync } from 'fs';
import { HardhatUserConfig } from 'hardhat/config';
import { HttpNetworkUserConfig } from 'hardhat/types';
import { utils } from 'ethers';

import './tasks/accounts';

const remappings = readFileSync('remappings.txt', 'utf8')
  .split('\n')
  .filter(Boolean)
  .map((line) => line.trim().split('='));

// Load environment variables.
dotenvConfig();

const { INFURA_KEY, MNEMONIC, PK, PRIVATE_KEY, REPORT_GAS, MOCHA_CONF, NODE_URL } = process.env;

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
      initialBaseFeePerGas: 0,
      chainId: 100,
      forking: {
        url: 'https://rpc.gnosischain.com/',
        enabled: true,
      },
      accounts: [
        {
          privateKey: PRIVATE_KEY!,
          balance: utils.parseEther('10000').toString(),
        },
      ],
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
    gnosis: {
      chainId: 100,
      url: 'https://rpc.gnosischain.com/',
      accounts: [process.env.GNOSIS_PRIVATE_KEY!],
    },
    gnosisFork: {
      chainId: 100,
      url: 'http://localhost:100',
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  solidity: {
    version: '0.8.13',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (!line.match(/^\s*import /i)) {
          return line;
        }

        const remapping = remappings.find(([find]) => line.match('"' + find));
        if (!remapping) {
          return line;
        }

        const [find, replace] = remapping;
        return line.replace('"' + find, '"' + replace);
      },
    }),
  },
  etherscan: {
    apiKey: {},
  },
  abiExporter: {
    format: 'json',
    flat: true,
    filter(abiElement, index, abi, fullyQualifiedName) {
      const contractName = fullyQualifiedName.split(':')[1];
      return ['ERC20', 'LSDAI'].includes(contractName);
    },
  },
};

export default config;
