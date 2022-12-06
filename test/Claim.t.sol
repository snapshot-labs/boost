// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostClaimTest is BoostTest {
    address public constant claimer = address(0x1111);
    address public constant claimer2 = address(0x2222);
    address public constant claimer3 = address(0x3333);

    function testClaimSingleRecipient() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();
        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        vm.expectEmit(true, false, false, true);
        emit TokensClaimed(claim);
        snapStart("ClaimSingle");
        boost.claimTokens(claim, _generateClaimSignature(claim));
        snapEnd();

        // Checking balances are correct after claim
        assertEq(token.balanceOf(address(boost)), depositAmount - 1);
        assertEq(token.balanceOf(claimer), 1);
    }

    function testClaimMultipleRecipients() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        IBoost.Claim memory claim2 = IBoost.Claim({
            boostId: boostId,
            recipient: claimer2,
            amount: 1,
            ref: keccak256("2")
        });
        // Same address as first claim
        IBoost.Claim memory claim3 = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("3")
        });
        boost.claimTokens(claim, _generateClaimSignature(claim));
        boost.claimTokens(claim2, _generateClaimSignature(claim2));
        boost.claimTokens(claim3, _generateClaimSignature(claim3));

        // Checking balances are correct after claim
        assertEq(token.balanceOf(address(boost)), depositAmount - 3);
        assertEq(token.balanceOf(claimer), 2);
        assertEq(token.balanceOf(claimer2), 1);
        assertEq(token.balanceOf(claimer3), 0);
    }

    function testClaimReusedSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        boost.claimTokens(claim, sig);

        vm.expectRevert(IBoost.RecipientAlreadyClaimed.selector);
        // Reusing signature
        boost.claimTokens(claim, sig);
    }

    function testClaimInvalidSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        // Creating signature with different claim amount
        bytes memory sig = _generateClaimSignature(
            IBoost.Claim({ boostId: boostId, recipient: claimer, amount: 2, ref: keccak256("1") })
        );
        vm.expectRevert(IBoost.InvalidSignature.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostEnded() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        // skipped ahead to after boost has ended
        vm.warp(block.timestamp + 60);
        vm.expectRevert(IBoost.BoostEnded.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostNotStarted() public {
        _mintAndApprove(owner, depositAmount, depositAmount);

        // Start timestamp is in future
        uint256 boostId = _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            guard,
            block.timestamp + 60,
            block.timestamp + 120,
            owner,
            0
        );

        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(abi.encodeWithSelector(IBoost.BoostNotStarted.selector, block.timestamp + 60));
        boost.claimTokens(claim, sig);
    }

    function testClaimBoostDoesntExist() public {
        IBoost.Claim memory claim = IBoost.Claim({ boostId: 1, recipient: claimer, amount: 1, ref: keccak256("1") });
        bytes memory sig = _generateClaimSignature(claim);
        // If the boost does not exist, then the balance of the boost will be zero
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claimTokens(claim, sig);
    }

    function testClaimExceedsBalance() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        // Claim larger than boost balance
        IBoost.Claim memory claim = IBoost.Claim({
            boostId: boostId,
            recipient: claimer,
            amount: depositAmount + 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claimTokens(claim, sig);
    }
}
