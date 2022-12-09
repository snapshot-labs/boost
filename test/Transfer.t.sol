// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";
import "forge-std/console2.sol";

contract BoostERC721Test is BoostTest {
    address public constant exchange = address(0x1111);
    address public constant owner2 = address(0x2222);

    function testTransferFrom() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        vm.prank(owner);
        boost.approve(exchange, boostId);
        assertEq(boost.ownerOf(boostId), owner); // sanity check
        vm.prank(exchange);
        boost.safeTransferFrom(owner, owner2, boostId);

        // Checking that the ownership has been transferred
        assertEq(boost.ownerOf(boostId), owner2);
    }

    function testTransfer() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        vm.prank(owner);
        // No approval needed as the current owner is performing the transfer
        snapStart("Transfer");
        boost.safeTransferFrom(owner, owner2, boostId);
        snapEnd();
        assertEq(boost.ownerOf(boostId), owner2);
    }

    function testBoostTransferNoApproval() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        // exchange was not approved to transfer the token
        vm.prank(exchange);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        boost.safeTransferFrom(owner, owner2, boostId);
    }
}
