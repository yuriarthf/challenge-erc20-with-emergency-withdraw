## General Info:

-   **Contract Address**: `0xe0994c81afbDdC01acd3805c589A8c284f021039`
-   **Network**: Rinkeby

## Summary

This is a solution for a challenge proposed by Illuvium. The main objective was to create an ERC-20 based contract with the functionality of transferring funds to an emergency address defined by the Token holder via an EIP-512 signature. In order to do so, `emergencyWithdrawWithSig` method must be called with the following parameters:

-   **\_exp** : The expiration timestamp of the EIP-712 signature;
-   **v** : `parseInt(signature.substring(128, 130), 16)`;
-   **r** : `"0x" + signature.substring(0, 64)`
-   **s** : `"0x" + signature.substring(64, 128)`

The `signature` represents the signed Typed Data composed by the `keccak256` hash of the concatenation of `0x1901`, the `Domain Separator` and the `hashStruct` signed by the signer's private key.

OBS: Some ERC-20 function were overriden to accomodate the case where `sender` and `recipient` addresses were blacklisted.

### Set Up and Testing

-   Run `yarn install` to install the project's dependencies.
-   Run `truffle compile --all` to recompile all contracts or just `truffle compile` to re-compile updated contracts.
-   Run `ganache-cli` to start simulating a local blockchain where the tests should run.
-   Modify `privateKeyString` inside `test/testERC20Enhanced.test.js` with the private key of the first accounts emulated by ganache-cli.
-   Run `truffle test` to run the tests (Currently, there's a problem with the `emergencyWithdrawWithSig` test case, should be fixed soon)

### Deployment

-   Start a project in Infura in the Rinkeby network.
-   Set environmental variables:
    -   `PROJECT_ID` equal to the PROJECT ID provided by Infura.
    -   `MNEMONIC` equal to the seed phrase of your HD-wallet.
-   Run `truffle migrate --network rinkeby` to migrate the contract to the Rinkeby network.

**OBS**: In order to deploy to different networks a field (`NETWORK_NAME`) with the same format as `module.exports.networks.rinkeby` must be added in the `truffle-config.js` file and `truffle migrate --network NETWORK_NAME` should be run.
