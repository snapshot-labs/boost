[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/snapshot-labs/boost/master/LICENSE)

# Boost

Programmable token distribution.

**[Documentation](https://docs.boost.limo)**

### Deployment

To deploy the protocol to an EVM chain, first set the following environment variables:

```sh
# The address of the account that will be set as the owner of the protocol.
PROTOCOL_OWNER=
# The name of the chain you want to deploy on. The addresses of the deployed contracts will be stored at /deployments/[network].json.
NETWORK=
# An RPC URL for the chain.
RPC_URL=
# Private Key for the deployer address.
PRIVATE_KEY=
# An API key for a block explorer on the chain.
(Optional).
ETHERSCAN_API_KEY=
```

Following this, a [Foundry Script](https://book.getfoundry.sh/tutorials/solidity-scripting) can be run to deploy the
entire protocol. Example usage to deploy from a Ledger Hardware Wallet and verify on a block explorer:

```sh
forge script script/Deployer.s.sol:Deployer --rpc-url $RPC_URL --optimize --broadcast --verify -vvvv
```

The script uses the [CREATE3 Factory](https://github.com/lifinance/create3-factory) for the deployments which ensures
that the addresses of the contracts are the same on all chains even if the constructor arguments for the contract are
different.
