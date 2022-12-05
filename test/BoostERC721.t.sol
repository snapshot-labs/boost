// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";
import "forge-std/console2.sol";

contract BoostERC721Test is BoostTest {
    function testBoostERC721() public {
        token.mint(owner, 2 * depositAmount);
        vm.prank(owner);
        token.approve(address(boost), 2 * depositAmount);
        vm.prank(owner);
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );

        vm.prank(owner);
        snapStart("CreateBoostERC721");
        boost.createBoost(
            strategyURI,
            IERC20(address(token)),
            depositAmount,
            guard,
            block.timestamp,
            block.timestamp + 60,
            owner
        );
        snapEnd();
        console2.log(boost.tokenURI(1));
    }
}
