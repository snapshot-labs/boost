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

        // Owner address of the boost contract
        address owner = 0xc83A9e69012312513328992d454290be85e95101;

        // Eth fee in WEI for creating a new boost
        // 0.01 ETH
        uint256 ethFee = 10000000000000000;

        // Percentage taken as a fee from the boost deposit
        uint256 tokenFee = 0;

        bytes32 salt = bytes32(uint256(2));
        singletonFactory.deploy(abi.encodePacked(type(Boost).creationCode, abi.encode(owner, ethFee, tokenFee)), salt);

        vm.stopBroadcast();
    }
}
