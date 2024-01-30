// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/Boost.sol";

interface ICREATE3Factory {
    function deploy(bytes32 salt, bytes memory bytecode) external returns (address deployedAddress);
}

contract Deployer is Script {
    using stdJson for string;

    string internal deployments;
    string internal deploymentsPath;

    string constant boostName = "boost";
    string constant boostSymbol = "BOOST";
    string constant boostVersion = "0.1.0";
    uint256 constant ethFee = 10000000000000000; //  0.01 ETH
    uint256 constant tokenFee = 0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory network = vm.envString("NETWORK");
        address owner = vm.envAddress("PROTOCOL_OWNER");

        deploymentsPath = string.concat(string.concat("./deployments/", network), ".json");

        vm.startBroadcast(deployerPrivateKey);

        // Using the CREATE3 factory maintained by lififinance: https://github.com/lifinance/create3-factory
        address deployed = ICREATE3Factory(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1).deploy(
            bytes32(uint256(0)),
            abi.encodePacked(
                type(Boost).creationCode, abi.encode(owner, boostName, boostSymbol, boostVersion, ethFee, tokenFee)
            )
        );

        deployments = deployments.serialize("Boost", deployed);

        deployments.write(deploymentsPath);

        vm.stopBroadcast();
    }
}
