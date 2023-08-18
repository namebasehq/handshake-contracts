<br>
<img src="https://user-images.githubusercontent.com/136583/182129623-3bab6cb3-ef97-41bb-bfd1-39500e2bc3f5.png" width="70">

<br>

# Handshake SLDs
Handshake is a decentralized naming system. The contracts in this repo define a new protocol for second-level domains (SLDs) anchored to the HNS root zone. These domains are based on the ERC-721 NFT standard and deployed on a secure and scalable EVM L2 blockchain (Optimism). 

<br>

# Development

**Install Foundry**
```
https://book.getfoundry.sh/getting-started/installation
```

**Install NPM Requirements**
```sh
npm install
```

**Build Contracts**
```sh
forge build
```

**Run Tests**
```sh
forge test
```

**Check Remappings**
```sh
forge remappings
```

**Run Prettier**
```sh
npm run prettier
```

<br>
<br>

# Deployment

Before deploying the smart contracts, ensure you've set up the necessary environment variables in an `.env` file.

## Environment Variables

Your `.env` file should contain the following:

```env
DEPLOYER_PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

**Note**: Ensure your `.env` file is ignored in `.gitignore` to prevent accidentally sharing sensitive information.

Before running the deployment script, source the `.env` file:

```sh
source .env
```

## Deployment Constants

Before running the deployment script, you need to update certain constants in the `script/Deploy.s.sol` file to match your specific requirements.

**`ORACLE_ADDRESS`**

This is the address of the Chainlink Oracle. Update it based on the desired network. For instance, the given default is for Optimism. You can refer to the [Chainlink documentation](https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism) for different network addresses.

```solidity
address private constant ORACLE_ADDRESS = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
```

**`CONTRACT_OWNER`**

This address will be the owner of the contracts, possessing the ability to run administrative functions.

```solidity
address private constant CONTRACT_OWNER = 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA;
```

**`PROXY_OWNER`**

This is the proxy owner for `TldClaimManager` and `SldRegistrationManager`. This address must differ from the `CONTRACT_OWNER` as the proxy owner can only run admin functions on the proxy contract and not the implementation contract.

```solidity
address private constant PROXY_OWNER = 0xfF778cbb3f5192a3e848aA7D7dB2DeB2a4944821;
```

Make sure to replace the default addresses with your desired addresses before running the deployment script.


## Deployment Command

With the environment variables set up, deploy your smart contracts using:
```sh
forge script script/Deploy.s.sol:DeployScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL  --etherscan-api-key $ETHERSCAN_API_KEY --verify --retries 10 --delay 10 --optimizer-runs 10000 --broadcast -vv
```

#### Additional Notes:

- The `--verify` flag verifies the contract on Etherscan post-deployment.
- `--retries 10` attempts the deployment 10 times in case of failures.
- `--delay 10` introduces a delay of 10 seconds between retries.
- The `--optimizer-runs 10000` instructs the Solidity compiler to optimize the bytecode under the assumption that the contract will be executed approximately 10,000 times.
- `--broadcast` broadcasts the transaction.
- `-vv` provides verbose output for debugging purposes.


## Contract Addresses

| Component                 | Address Link                                                                                             |
|---------------------------|---------------------------------------------------------------------------------------------------------|
| labelValidator            | [Link](https://optimistic.etherscan.io/address/0x0b26062CB10DA260CC1659C2a4b2fDe6023f4B18)            |
| priceOracle               | [Link](https://optimistic.etherscan.io/address/0x178767FDEA4D43C8B7086C4B92a2569db930655C)            |
| globalRules               | [Link](https://optimistic.etherscan.io/address/0xe2E4d33f5E2cd7c9b74cedfcbF8Bd6C3A239e2c9)            |
| commitIntent              | [Link](https://optimistic.etherscan.io/address/0x84EE3763E5F2faB55E8d7197632Aa234159C2f5f)            |
| tld                       | [Link](https://optimistic.etherscan.io/address/0x01eBCf32e4b5da0167eaacEA1050B2be63122B6f)            |
| sld                       | [Link](https://optimistic.etherscan.io/address/0x7963bfA8F8f914b9776ac6259a8C39965d26f42F)            |
| metadata                  | [Link](https://optimistic.etherscan.io/address/0x93Cea80D190eB1401b15e3dbBE3d0392D32e3FCf)            |
| tldClaimManager           | [Link](https://optimistic.etherscan.io/address/0x9209397263427413817Afc6957A434cF62C02c68)            |
| sldRegistrationManager    | [Link](https://optimistic.etherscan.io/address/0xfda87cc032cd641ac192027353e5b25261dfe6b3)            |
| defaultRegistrationStrategy | [Link](https://optimistic.etherscan.io/address/0x0F1143972197B63053709794f718e60599Ce4730)         |
| resolver                  | [Link](https://optimistic.etherscan.io/address/0xDDa56f06D80f3D8E3E35159701A63753f39c3BCB)            |



