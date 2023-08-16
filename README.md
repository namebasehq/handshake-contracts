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

## Deployment

Before deploying the smart contracts, ensure you've set up the necessary environment variables in an `.env` file.

### Environment Variables in `.env` file

Your `.env` file should contain the following:

- DEPLOYER_PRIVATE_KEY=your_private_key
- RPC_URL=your_rpc_url
- ETHERSCAN_API_KEY=your_etherscan_api_key

**Note**: Ensure your `.env` file is ignored in `.gitignore` to prevent accidentally sharing sensitive information.

Before running the deployment script, source the `.env` file:

source .env

### Updating Deployment Constants

Before running the deployment script, you need to update certain constants in the `script/Deploy.s.sol` file to match your specific requirements.

### Constants to Update:

1. **ORACLE_ADDRESS**: This is the address of the Chainlink Oracle. Update it based on the desired network. For instance, the given default is for Optimism. You can refer to the [Chainlink documentation](https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism) for different network addresses.

address private constant ORACLE_ADDRESS = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;

2. **CONTRACT_OWNER**: This address will be the owner of the contracts, possessing the ability to run administrative functions.

address private constant CONTRACT_OWNER = 0xa90D04E5FaC9ba49520749711a12c3E5d0D9D6dA;

3. **PROXY_OWNER**: This is the proxy owner for `TldClaimManager` and `SldRegistrationManager`. This address must differ from the `CONTRACT_OWNER` as the proxy owner can only run admin functions on the proxy contract and not the implementation contract.

address private constant PROXY_OWNER = 0xfF778cbb3f5192a3e848aA7D7dB2DeB2a4944821;

Make sure to replace the default addresses with your desired addresses before running the deployment script.


### Deployment Command

With the environment variables set up, deploy your smart contracts using:
```bash
forge script script/Deploy.s.sol:DeployScript --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL  --etherscan-api-key $ETHERSCAN_API_KEY --verify --retries 10 --delay 10 --optimizer-runs 10000 --broadcast -vv
```

#### Additional Notes:

- The `--verify` flag verifies the contract on Etherscan post-deployment.
- `--retries 10` attempts the deployment 10 times in case of failures.
- `--delay 10` introduces a delay of 10 seconds between retries.
- The `--optimizer-runs 10000` instructs the Solidity compiler to optimize the bytecode under the assumption that the contract will be executed approximately 10,000 times.
- `--broadcast` broadcasts the transaction.
- `-vv` provides verbose output for debugging purposes.


