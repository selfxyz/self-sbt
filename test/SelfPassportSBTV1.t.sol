// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";
import { IIdentityVerificationHubV1 } from "@selfxyz/contracts/contracts/interfaces/IIdentityVerificationHubV1.sol";
import { IERC5192 } from "../src/interfaces/IERC5192.sol";

import { SelfPassportSBTV1 } from "../src/SelfPassportSBTV1.sol";

contract SelfPassportSBTV1Test is Test {
    // Test data
    uint256 internal constant SCOPE_VALUE = 12_345;
    uint64 internal constant INVALID_TOKEN_ID = 999;
    uint256 internal constant TEST_NULLIFIER = 54_321;

    // Test variables
    SelfPassportSBTV1 internal sbtContract;
    address internal identityHub;
    address internal user;
    address internal relayer;

    uint256[] internal attestationIds;

    function setUp() public {
        // Create addresses using Foundry best practices
        identityHub = makeAddr("identityHub");
        user = makeAddr("user");
        relayer = makeAddr("relayer");

        // Setup attestation IDs
        attestationIds = new uint256[](2);
        attestationIds[0] = 1;
        attestationIds[1] = 2;

        // Deploy contract
        sbtContract = new SelfPassportSBTV1(identityHub, SCOPE_VALUE, attestationIds);
    }

    function test_SetUp() external view {
        assertEq(sbtContract.name(), "SelfPassportSBTV1");
        assertEq(sbtContract.symbol(), "SELFSBTV1");
        assertEq(sbtContract.VALIDITY_PERIOD(), 180 days);

        // Check ERC5192 supports interface
        assertTrue(sbtContract.supportsInterface(type(IERC5192).interfaceId));
    }

    function test_IsTokenValid() external {
        ISelfVerificationRoot.DiscloseCircuitProof memory proof = _prepareForVerifySelfProof();
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // Token is valid
        assertEq(sbtContract.isTokenValid(1), true);

        // Token is not minted
        assertEq(sbtContract.isTokenValid(2), false);

        // Token is minted but expired
        vm.warp(block.timestamp + sbtContract.VALIDITY_PERIOD() + 1);
        assertEq(sbtContract.isTokenValid(1), false);
    }

    // Case 1: Nullifier NEW + Receiver NO SBT → mint
    function test_VerifySelfProof_Case1_NewNullifier_NoSBT_Mint() external {
        ISelfVerificationRoot.DiscloseCircuitProof memory proof = _prepareForVerifySelfProof();

        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // Verify token was minted
        assertEq(sbtContract.ownerOf(1), user);
        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
    }

    // Case 2: Nullifier NEW + Receiver HAS SBT → update
    function test_VerifySelfProof_Case2_NewNullifier_HasSBT_Update() external {
        // First mint an SBT for user
        ISelfVerificationRoot.DiscloseCircuitProof memory proof = _prepareForVerifySelfProof();
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        uint256 originalExpiry = sbtContract.getTokenExpiry(1);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Use a different nullifier for the same user
        uint256 newNullifier = TEST_NULLIFIER + 1;
        proof = _prepareForVerifySelfProofWithNullifier(user, newNullifier);
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // Should still be only one token, but expiry updated
        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);
        assertEq(sbtContract.ownerOf(1), user);

        // Both nullifiers should be used
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
        assertEq(sbtContract.isNullifierUsed(newNullifier), true);

        // Expiry should be updated
        uint256 newExpiry = sbtContract.getTokenExpiry(1);
        assertGt(newExpiry, originalExpiry);
    }

    // Case 3: Nullifier USED + Receiver NO SBT → revert
    function test_VerifySelfProof_Case3_UsedNullifier_NoSBT_Revert() external {
        // First user mints with nullifier
        ISelfVerificationRoot.DiscloseCircuitProof memory proof = _prepareForVerifySelfProof();
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // Different user tries to use same nullifier
        address user2 = makeAddr("user2");
        proof = _prepareForVerifySelfProofWithNullifier(user2, TEST_NULLIFIER);

        vm.expectRevert(SelfPassportSBTV1.RegisteredNullifier.selector);
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);
    }

    // Case 4: Nullifier USED + Receiver HAS SBT → check owner match
    function test_VerifySelfProof_Case4_UsedNullifier_HasSBT_SameOwner_Update() external {
        // User mints with nullifier
        ISelfVerificationRoot.DiscloseCircuitProof memory proof = _prepareForVerifySelfProof();
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        uint256 originalExpiry = sbtContract.getTokenExpiry(1);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Same user uses same nullifier again (should update)
        proof = _prepareForVerifySelfProof();
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // Should still be only one token, but expiry updated
        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);

        uint256 newExpiry = sbtContract.getTokenExpiry(1);
        assertGt(newExpiry, originalExpiry);
    }

    function test_VerifySelfProof_Case4_UsedNullifier_HasSBT_DifferentOwner_Revert() external {
        // User1 mints with nullifier
        ISelfVerificationRoot.DiscloseCircuitProof memory proof = _prepareForVerifySelfProof();
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // User2 gets an SBT with different nullifier
        address user2 = makeAddr("user2");
        uint256 user2Nullifier = TEST_NULLIFIER + 1;
        proof = _prepareForVerifySelfProofWithNullifier(user2, user2Nullifier);
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);

        // User2 tries to use User1's nullifier (should revert)
        proof = _prepareForVerifySelfProofWithNullifier(user2, TEST_NULLIFIER);

        vm.expectRevert(SelfPassportSBTV1.RegisteredNullifier.selector);
        vm.prank(relayer);
        sbtContract.verifySelfProof(proof);
    }

    function _prepareForVerifySelfProof() internal returns (ISelfVerificationRoot.DiscloseCircuitProof memory proof) {
        return _prepareForVerifySelfProofWithNullifier(user, TEST_NULLIFIER);
    }

    function _prepareForVerifySelfProofWithNullifier(
        address userAddress,
        uint256 nullifier
    )
        internal
        returns (ISelfVerificationRoot.DiscloseCircuitProof memory proof)
    {
        // Create the expected verification result
        IIdentityVerificationHubV1.VcAndDiscloseVerificationResult memory result = IIdentityVerificationHubV1
            .VcAndDiscloseVerificationResult({
            attestationId: 1,
            scope: SCOPE_VALUE,
            userIdentifier: uint256(uint160(userAddress)),
            nullifier: nullifier,
            identityCommitmentRoot: 12_345,
            revealedDataPacked: [uint256(0), uint256(0), uint256(0)],
            forbiddenCountriesListPacked: [uint256(0), uint256(0), uint256(0), uint256(0)]
        });

        // Mock the identity hub to return the proper struct
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV1.verifyVcAndDisclose.selector),
            abi.encode(result)
        );

        // Create proof
        proof = _createMockProof(userAddress, nullifier);
    }

    function _createMockProof(
        address userAddress,
        uint256 nullifier
    )
        internal
        pure
        returns (ISelfVerificationRoot.DiscloseCircuitProof memory)
    {
        uint256[21] memory pubSignals;
        pubSignals[7] = nullifier; // NULLIFIER_INDEX = 7
        pubSignals[8] = 1; // ATTESTATION_ID_INDEX = 8 (valid attestation ID)
        pubSignals[19] = SCOPE_VALUE; // SCOPE_INDEX = 19
        pubSignals[20] = uint256(uint160(userAddress)); // USER_IDENTIFIER_INDEX = 20

        return ISelfVerificationRoot.DiscloseCircuitProof({
            a: [uint256(0), uint256(0)],
            b: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
            c: [uint256(0), uint256(0)],
            pubSignals: pubSignals
        });
    }
}
