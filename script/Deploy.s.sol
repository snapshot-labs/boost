// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import "../src/Boost.sol";

interface SingletonFactory {
    function deploy(bytes memory _initCode, bytes32 salt) external returns (address payable);
}

contract BoostSingletonDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SingletonFactory singletonFactory = SingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);
        bytes32 salt = bytes32(0);
        singletonFactory.deploy(
            abi.encodePacked(type(Boost).creationCode, abi.encode(vm.envAddress("PROTOCOL_OWNER"), 0, 0)),
            salt
        );

        vm.stopBroadcast();
    }
}
