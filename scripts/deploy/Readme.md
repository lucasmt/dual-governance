# Dual Governance deploy scripts

### Running locally with Anvil

Start Anvil, provide RPC URL (Infura as an example)
```
anvil --fork-url https://<mainnet or holesky>.infura.io/v3/<YOUR_API_KEY> --block-time 300
```

### Running the deploy script

1. Import your private key to Cast wallet ([see the docs](https://book.getfoundry.sh/reference/cast/cast-wallet-import)), for example (we will use the account name `Deployer1` here and further for the simplicity):

    ```
    cast wallet import Deployer1 --interactive
    ```

2. Set up the required env variables in the .env file

    ```
    CHAIN=<"mainnet" OR "holesky" OR "holesky-mocks">
    ETHERSCAN_MAINNET_KEY=...
    DEPLOY_CONFIG_FILE_PATH=... (for example: "deploy-config/deploy-config.json")
    ```

3. Create a deploy config JSON file with all the required values (at the location specified in DEPLOY_CONFIG_FILE_PATH):
    ```
    {
        "EMERGENCY_ACTIVATION_COMMITTEE": <address>,
        "EMERGENCY_EXECUTION_COMMITTEE": <address>,
        "TIEBREAKER_SUB_COMMITTEE_1_MEMBERS": [addr1,addr2,addr3],
        "TIEBREAKER_SUB_COMMITTEE_2_MEMBERS": [addr1,addr2,addr3],
        "TIEBREAKER_SUB_COMMITTEES_QUORUMS": [3,2],
        "TIEBREAKER_SUB_COMMITTEES_COUNT": 2,
        "RESEAL_COMMITTEE": <address>
    }
    ```

    When using `CHAIN="holesky-mocks"` you will need to provide in addition already deployed mock contracts addresses in the same JSON config file (at DEPLOY_CONFIG_FILE_PATH):
    
    ```
    {
        ...
        "HOLESKY_MOCK_ST_ETH": ...,
        "HOLESKY_MOCK_WST_ETH": ...,
        "HOLESKY_MOCK_WITHDRAWAL_QUEUE": ...,
        "HOLESKY_MOCK_DAO_VOTING": ...,
        ...
    }
    ```

4. Run the deployment script

    With the local fork (Anvil):
    ```
    forge script scripts/deploy/DeployConfigurable.s.sol:DeployConfigurable --fork-url http://localhost:8545 --broadcast --account Deployer1 --sender <DEPLOYER1_ADDRESS>
    ```

    On a testnet (with Etherscan verification):
    ```
    forge script scripts/deploy/DeployConfigurable.s.sol:DeployConfigurable --fork-url https://holesky.infura.io/v3/<YOUR_API_KEY> --broadcast --account Deployer1 --sender <DEPLOYER1_ADDRESS> --verify
    ```

5. [Testnet and mainnet deployment only] Run Etherscan verification for Escrow contract

    The Escrow contract is deployed internally by DualGovernance contract, so it can't be verified automatically during the initial deployment and requires manual verification afterward. To run Etherscan verification:

    a. Search the deployed DualGovernance contract events for `EscrowMasterCopyDeployed` event with a single argument - ESCROW_MASTER_COPY address.

    b. Run Etherscan verification (for example on a Holesky testnet)

    ```
    forge verify-contract --chain holesky --verifier-url https://api-holesky.etherscan.io/api --watch --constructor-args $(cast abi-encode "Escrow(address,address,address,address,uint256,uint32)" <ST_ETH_ADDRESS> <WST_ETH_ADDRESS> <WITHDRAWAL_QUEUE_ADDRESS> <DUAL_GOVERNANCE_ADDRESS> <MIN_WITHDRAWALS_BATCH_SIZE> <MAX_MIN_ASSETS_LOCK_DURATION>) <ESCROW_MASTER_COPY> contracts/Escrow.sol:Escrow
    ```

### Running the verification script

1. Set up the required env variables in the .env file

    ```
    CHAIN=<"mainnet" OR "holesky" OR "holesky-mocks">
    DEPLOYED_ADDRESSES_FILE_PATH=... (for example: "deploy-config/deployed-addrs.json")
    ```

2. Create a deployed addresses list JSON file with all the required values (at the location specified in DEPLOYED_ADDRESSES_FILE_PATH):

    ```
    {
        "ADMIN_EXECUTOR": "...",
        "TIMELOCK": "...",
        "EMERGENCY_GOVERNANCE": "...",
        "RESEAL_MANAGER": "...",
        "DUAL_GOVERNANCE": "...",
        "TIEBREAKER_CORE_COMMITTEE": "...",
        "TIEBREAKER_SUB_COMMITTEES": ["...", "..."]
    }
    ```

3. Run the script (with the local Anvil as an example)

    ```
    forge script scripts/deploy/Verify.s.sol:Verify --fork-url http://localhost:8545 --broadcast
    ```
