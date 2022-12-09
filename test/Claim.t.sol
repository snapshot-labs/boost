// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Boost.t.sol";

contract BoostClaimTest is BoostTest {
    address public constant claimer = address(0x1111);
    address public constant claimer2 = address(0x2222);
    address public constant claimer3 = address(0x3333);
    address public constant claimer4 = address(0x4444);
    address public constant claimer5 = address(0x5555);

    function testClaimSingleRecipient() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        vm.expectEmit(true, false, false, true);
        emit Claim(claim);
        snapStart("ClaimSingle");
        boost.claim(claim, _generateClaimSignature(claim));
        snapEnd();

        // Checking balances are correct after claim
        assertEq(token.balanceOf(address(boost)), depositAmount - 1);
        assertEq(token.balanceOf(claimer), 1);
    }

    function testClaimMultipleSeparately() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        IBoost.ClaimConfig memory claim2 = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("2")
        });
        IBoost.ClaimConfig memory claim3 = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer2,
            amount: 1,
            ref: keccak256("3")
        });
        boost.claim(claim, _generateClaimSignature(claim));
        boost.claim(claim2, _generateClaimSignature(claim2));
        boost.claim(claim3, _generateClaimSignature(claim3));

        // Checking balances are correct after claim
        assertEq(token.balanceOf(address(boost)), depositAmount - 3);
        assertEq(token.balanceOf(claimer), 2);
        assertEq(token.balanceOf(claimer2), 1);
        assertEq(token.balanceOf(claimer3), 0);
    }

    function testClaimMultiple() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        IBoost.ClaimConfig memory claim2 = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer2,
            amount: 1,
            ref: keccak256("2")
        });
        IBoost.ClaimConfig memory claim3 = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer3,
            amount: 1,
            ref: keccak256("3")
        });
        IBoost.ClaimConfig memory claim4 = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer4,
            amount: 1,
            ref: keccak256("4")
        });
        IBoost.ClaimConfig memory claim5 = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer5,
            amount: 1,
            ref: keccak256("5")
        });

        // Generating Claim array
        IBoost.ClaimConfig[] memory claims = new IBoost.ClaimConfig[](5);
        claims[0] = claim;
        claims[1] = claim2;
        claims[2] = claim3;
        claims[3] = claim4;
        claims[4] = claim5;

        // Generating signature array from the claims
        bytes[] memory signatures = new bytes[](5);
        signatures[0] = _generateClaimSignature(claim);
        signatures[1] = _generateClaimSignature(claim2);
        signatures[2] = _generateClaimSignature(claim3);
        signatures[3] = _generateClaimSignature(claim4);
        signatures[4] = _generateClaimSignature(claim5);

        snapStart("ClaimMultiple");
        boost.claimMultiple(claims, signatures);
        snapEnd();

        // Checking balances are correct after claims made
        assertEq(token.balanceOf(address(boost)), depositAmount - 5);
        assertEq(token.balanceOf(claimer), 1);
        assertEq(token.balanceOf(claimer2), 1);
        assertEq(token.balanceOf(claimer3), 1);
        assertEq(token.balanceOf(claimer4), 1);
        assertEq(token.balanceOf(claimer5), 1);
    }

    function testClaimReusedSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        boost.claim(claim, sig);

        vm.expectRevert(IBoost.RecipientAlreadyClaimed.selector);
        // Reusing signature
        boost.claim(claim, sig);
    }

    function testClaimInvalidSignature() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        // Creating signature with different claim data
        bytes memory sig = _generateClaimSignature(
            IBoost.ClaimConfig({ boostId: boostId, recipient: claimer, amount: 2, ref: keccak256("1") })
        );
        vm.expectRevert(IBoost.InvalidSignature.selector);
        boost.claim(claim, sig);
    }

    function testClaimBoostEnded() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        // skipped ahead to after boost has ended
        vm.warp(block.timestamp + 60);
        vm.expectRevert(IBoost.BoostEnded.selector);
        boost.claim(claim, sig);
    }

    function testClaimBoostNotStarted() public {
        _mintAndApprove(owner, depositAmount, depositAmount);

        // Start timestamp is in future
        uint256 boostId = _createBoost(
            strategyURI,
            address(token),
            depositAmount,
            owner,
            guard,
            block.timestamp + 60,
            block.timestamp + 120,
            0
        );

        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(abi.encodeWithSelector(IBoost.BoostNotStarted.selector, block.timestamp + 60));
        boost.claim(claim, sig);
    }

    function testClaimBoostDoesntExist() public {
        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: 1,
            recipient: claimer,
            amount: 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        // If the boost does not exist, then the balance of the boost will be zero
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claim(claim, sig);
    }

    function testClaimExceedsBalance() public {
        _mintAndApprove(owner, depositAmount, depositAmount);
        uint256 boostId = _createBoost();

        // Claim larger than boost balance
        IBoost.ClaimConfig memory claim = IBoost.ClaimConfig({
            boostId: boostId,
            recipient: claimer,
            amount: depositAmount + 1,
            ref: keccak256("1")
        });
        bytes memory sig = _generateClaimSignature(claim);
        vm.expectRevert(IBoost.InsufficientBoostBalance.selector);
        boost.claim(claim, sig);
    }
}
