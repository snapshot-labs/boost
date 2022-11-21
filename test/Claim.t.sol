// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./Boost.t.sol";

contract BoostClaimTest is BoostTest {
    address public constant claimer = address(0x1111);
    address public constant claimer2 = address(0x2222);
    address public constant claimer3 = address(0x3333);
    address public constant claimer4 = address(0x4444);
    address public constant claimer5 = address(0x5555);

    function testClaimSingleRecipient() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        vm.expectEmit(true, false, false, true);
        emit TokensClaimed(claim);
        boost.claimTokens(claim, _generateClaimSignature(claim));
        assertEq(token.balanceOf(address(boost)), depositAmount - 1);
        assertEq(token.balanceOf(claimer), 1);
    }

    function testClaimMultipleSeparate() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        IBoost.Claim memory claim2 = IBoost.Claim({ boostId: boostId, recipient: claimer2, amount: 1 });
        IBoost.Claim memory claim3 = IBoost.Claim({ boostId: boostId, recipient: claimer3, amount: 1 });
        IBoost.Claim memory claim4 = IBoost.Claim({ boostId: boostId, recipient: claimer4, amount: 1 });
        IBoost.Claim memory claim5 = IBoost.Claim({ boostId: boostId, recipient: claimer5, amount: 1 });
        boost.claimTokens(claim, _generateClaimSignature(claim));
        boost.claimTokens(claim2, _generateClaimSignature(claim2));
        boost.claimTokens(claim3, _generateClaimSignature(claim3));
        boost.claimTokens(claim4, _generateClaimSignature(claim4));
        boost.claimTokens(claim5, _generateClaimSignature(claim5));
        assertEq(token.balanceOf(address(boost)), depositAmount - 5);
        assertEq(token.balanceOf(claimer), 1);
        assertEq(token.balanceOf(claimer2), 1);
        assertEq(token.balanceOf(claimer3), 1);
        assertEq(token.balanceOf(claimer4), 1);
        assertEq(token.balanceOf(claimer5), 1);
    }

    function testClaimReusedSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        boost.claimTokens(claim, sig);
        vm.expectRevert(IBoost.RecipientAlreadyClaimed.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimInvalidSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 2 }));
        vm.expectRevert(IBoost.InvalidSignature.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostEnded() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.warp(block.timestamp + 60);
        vm.expectRevert(IBoost.BoostEnded.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostNotStarted() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = boost.nextBoostId();
        IBoost.BoostConfig memory boostConfig = IBoost.BoostConfig({
            strategyURI: strategyURI,
            token: address(token),
            balance: depositAmount,
            guard: guard,
            start: block.timestamp + 60,
            end: block.timestamp + 120,
            owner: owner
        });
        vm.prank(owner);
        boost.createBoost(boostConfig);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(abi.encodeWithSelector(IBoost.BoostNotStarted.selector, block.timestamp + 60));
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostDoesntExist() public {
        IBoost.Claim memory claim = IBoost.Claim({ boostId: 1, recipient: claimer, amount: 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimExceedsBalance() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: depositAmount + 1 });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimMultipleCombined() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        IBoost.Claim memory claim2 = IBoost.Claim({ boostId: boostId, recipient: claimer2, amount: 1 });
        IBoost.Claim memory claim3 = IBoost.Claim({ boostId: boostId, recipient: claimer3, amount: 1 });
        IBoost.Claim memory claim4 = IBoost.Claim({ boostId: boostId, recipient: claimer4, amount: 1 });
        IBoost.Claim memory claim5 = IBoost.Claim({ boostId: boostId, recipient: claimer5, amount: 1 });
        address[] memory recipients = new address[](5);
        recipients[0] = claimer;
        recipients[1] = claimer2;
        recipients[2] = claimer3;
        recipients[3] = claimer4;
        recipients[4] = claimer5;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        bytes[] memory signatures = new bytes[](5);
        signatures[0] = _generateClaimSignature(claim);
        signatures[1] = _generateClaimSignature(claim2);
        signatures[2] = _generateClaimSignature(claim3);
        signatures[3] = _generateClaimSignature(claim4);
        signatures[4] = _generateClaimSignature(claim5);
        boost.claimMultiple(boostId, recipients, amounts, signatures);
    }

    function testClaimMultipleCombined2() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost(depositAmount);
        IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
        IBoost.Claim memory claim2 = IBoost.Claim({ boostId: boostId, recipient: claimer2, amount: 1 });
        IBoost.Claim memory claim3 = IBoost.Claim({ boostId: boostId, recipient: claimer3, amount: 1 });
        IBoost.Claim memory claim4 = IBoost.Claim({ boostId: boostId, recipient: claimer4, amount: 1 });
        IBoost.Claim memory claim5 = IBoost.Claim({ boostId: boostId, recipient: claimer5, amount: 1 });
        address[] memory recipients = new address[](5);
        recipients[0] = claimer;
        recipients[1] = claimer2;
        recipients[2] = claimer3;
        recipients[3] = claimer4;
        recipients[4] = claimer5;

        uint256 amount = 1;

        bytes[] memory signatures = new bytes[](5);
        signatures[0] = _generateClaimSignature(claim);
        signatures[1] = _generateClaimSignature(claim2);
        signatures[2] = _generateClaimSignature(claim3);
        signatures[3] = _generateClaimSignature(claim4);
        signatures[4] = _generateClaimSignature(claim5);
        boost.claimMultiple2(boostId, recipients, amount, signatures);
    }

    // function testClaimMultipleOne() public {
    //     _mintAndApprove(owner, depositAmount, depositAmount);
    //     uint256 boostId = _createBoost(depositAmount);
    //     IBoost.Claim memory claim = IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 1 });
    //     address[] memory recipients = new address[](1);
    //     recipients[0] = claimer;

    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = 1;

    //     bytes[] memory signatures = new bytes[](1);
    //     signatures[0] = _generateClaimSignature(claim);

    //     boost.claimMultiple(boostId, recipients, amounts, signatures);
    // }
}
