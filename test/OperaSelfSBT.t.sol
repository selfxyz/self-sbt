// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts-v2/contracts/interfaces/ISelfVerificationRoot.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts-v2/contracts/interfaces/IIdentityVerificationHubV2.sol";
import { IERC5192 } from "../src/interfaces/IERC5192.sol";

import { OperaSelfSBT } from "../src/OperaSBT.sol";

contract OperaSelfSBTTest is Test {
    // Test data
    uint256 internal constant SCOPE_VALUE = 12_345;
    uint256 internal constant TEST_NULLIFIER = 54_321;
    uint256 internal constant VALIDITY_PERIOD = 180 days;
    bytes32 internal constant VERIFICATION_CONFIG_ID = bytes32(uint256(0x123));
    // Test variables
    OperaSelfSBT internal sbtContract;
    address internal identityHub;
    address internal owner;
    address internal user;
    address internal user2;
    address internal newUser;
    address internal relayer;

    function setUp() public {
        identityHub = makeAddr("identityHub");
        owner = makeAddr("owner");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        newUser = makeAddr("newUser");
        relayer = makeAddr("relayer");

        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(true)
        );

        sbtContract = new OperaSelfSBT(
            identityHub, SCOPE_VALUE, owner, VALIDITY_PERIOD, VERIFICATION_CONFIG_ID
        );
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetUp() external view {
        assertEq(sbtContract.name(), "OperaSelfSBT");
        assertEq(sbtContract.symbol(), "OPERASELF");
        assertEq(sbtContract.validityPeriod(), VALIDITY_PERIOD);
        assertEq(sbtContract.verificationConfigId(), VERIFICATION_CONFIG_ID);
        assertEq(sbtContract.owner(), owner);
        assertTrue(sbtContract.supportsInterface(type(IERC5192).interfaceId));
    }

    function test_Constructor_InvalidValidityPeriod() external {
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(true)
        );

        vm.expectRevert(OperaSelfSBT.InvalidValidityPeriod.selector);
        new OperaSelfSBT(identityHub, SCOPE_VALUE, owner, 0, VERIFICATION_CONFIG_ID);
    }

    function test_Constructor_VerificationConfigDoesNotExist() external {
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(false)
        );

        vm.expectRevert(OperaSelfSBT.VerificationConfigDoesNotExist.selector);
        new OperaSelfSBT(identityHub, SCOPE_VALUE, owner, VALIDITY_PERIOD, VERIFICATION_CONFIG_ID);
    }

    /*//////////////////////////////////////////////////////////////
                      VERIFICATION CASE TESTS
    //////////////////////////////////////////////////////////////*/

    // Case 1: Nullifier NEW + Receiver NO SBT → mint
    function test_VerifySelfProof_Case1_NewNullifier_NoSBT_Mint() external {
        _simulateVerification(user, TEST_NULLIFIER);

        assertEq(sbtContract.ownerOf(1), user);
        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
        assertEq(sbtContract.isTokenValid(1), true);
    }

    function test_VerifySelfProof_Case1_EmitsSBTMinted() external {
        bytes memory proofPayload = abi.encodePacked(bytes32(0), bytes("mock_proof_data"));
        bytes memory userContextData = abi.encodePacked(
            bytes32(uint256(block.chainid)),
            bytes32(uint256(uint160(user)))
        );

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        vm.expectEmit(true, true, true, true);
        emit OperaSelfSBT.SBTMinted(user, 1, block.timestamp + VALIDITY_PERIOD);

        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(user)),
                    nullifier: TEST_NULLIFIER,
                    forbiddenCountriesListPacked: [uint256(0), uint256(0), uint256(0), uint256(0)],
                    issuingState: "US",
                    name: _createMockName(),
                    idNumber: "123456789",
                    nationality: "US",
                    dateOfBirth: "1990-01-01",
                    gender: "M",
                    expiryDate: "2030-12-31",
                    olderThan: 18,
                    ofac: [false, false, false]
                })
            ),
            userContextData
        );
    }

    function test_VerifySelfProof_Case1_EmitsVerificationCompleted() external {
        bytes memory proofPayload = abi.encodePacked(bytes32(0), bytes("mock_proof_data"));
        bytes memory userContextData = abi.encodePacked(
            bytes32(uint256(block.chainid)),
            bytes32(uint256(uint160(user)))
        );

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        vm.expectEmit(true, true, false, true);
        emit OperaSelfSBT.VerificationCompleted(user, TEST_NULLIFIER, block.timestamp);

        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(user)),
                    nullifier: TEST_NULLIFIER,
                    forbiddenCountriesListPacked: [uint256(0), uint256(0), uint256(0), uint256(0)],
                    issuingState: "US",
                    name: _createMockName(),
                    idNumber: "123456789",
                    nationality: "US",
                    dateOfBirth: "1990-01-01",
                    gender: "M",
                    expiryDate: "2030-12-31",
                    olderThan: 18,
                    ofac: [false, false, false]
                })
            ),
            userContextData
        );
    }

    // Case 2: Nullifier NEW + Receiver HAS SBT → revert
    function test_VerifySelfProof_Case2_NewNullifier_HasSBT_Reverts() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 newNullifier = TEST_NULLIFIER + 1;
        _callVerifySelfProof(user);

        vm.expectRevert(OperaSelfSBT.RegisteredNullifier.selector);
        _callOnVerificationSuccess(user, newNullifier);
    }

    // Case 3: Nullifier USED + Receiver NO SBT → recover burned token
    function test_VerifySelfProof_Case3_UsedNullifier_NoSBT_RecoverBurnedToken() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 tokenId = 1;
        assertEq(sbtContract.ownerOf(tokenId), user);

        vm.prank(owner);
        sbtContract.burnSBT(tokenId);

        vm.expectRevert();
        sbtContract.ownerOf(tokenId);
        assertEq(sbtContract.getTokenIdByAddress(user), 0);

        _simulateVerification(newUser, TEST_NULLIFIER);

        assertEq(sbtContract.ownerOf(tokenId), newUser);
        assertEq(sbtContract.getTokenIdByAddress(newUser), tokenId);
        assertEq(sbtContract.isTokenValid(tokenId), true);
    }

    // Case 3: Nullifier USED + Receiver NO SBT → revert if token still active
    function test_VerifySelfProof_Case3_UsedNullifier_NoSBT_RevertIfActive() external {
        _simulateVerification(user, TEST_NULLIFIER);

        _callVerifySelfProof(user2);

        vm.expectRevert(OperaSelfSBT.RegisteredNullifier.selector);
        _callOnVerificationSuccess(user2, TEST_NULLIFIER);
    }

    // Case 4: Nullifier USED + Receiver HAS SBT → same owner → update
    function test_VerifySelfProof_Case4_UsedNullifier_HasSBT_SameOwner_Update() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 originalExpiry = sbtContract.getTokenExpiry(1);

        vm.warp(block.timestamp + 30 days);

        _callVerifySelfProof(user);

        vm.expectEmit(true, true, true, true);
        emit OperaSelfSBT.SBTUpdated(1, block.timestamp + VALIDITY_PERIOD);

        _callOnVerificationSuccess(user, TEST_NULLIFIER);

        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);

        uint256 newExpiry = sbtContract.getTokenExpiry(1);
        assertGt(newExpiry, originalExpiry);
    }

    // Case 4: Nullifier USED + Receiver HAS SBT → different owner → revert
    function test_VerifySelfProof_Case4_UsedNullifier_HasSBT_DifferentOwner_Revert() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 user2Nullifier = TEST_NULLIFIER + 1;
        _simulateVerification(user2, user2Nullifier);

        _callVerifySelfProof(user2);

        vm.expectRevert(OperaSelfSBT.RegisteredNullifier.selector);
        _callOnVerificationSuccess(user2, TEST_NULLIFIER);
    }

    function test_InvalidReceiver_ZeroAddress() external {
        vm.expectRevert(OperaSelfSBT.InvalidReceiver.selector);
        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(0),
                    nullifier: TEST_NULLIFIER,
                    forbiddenCountriesListPacked: [uint256(0), uint256(0), uint256(0), uint256(0)],
                    issuingState: "US",
                    name: _createMockName(),
                    idNumber: "123456789",
                    nationality: "US",
                    dateOfBirth: "1990-01-01",
                    gender: "M",
                    expiryDate: "2030-12-31",
                    olderThan: 18,
                    ofac: [false, false, false]
                })
            ),
            abi.encodePacked(bytes32(0), bytes32(0))
        );
    }

    /*//////////////////////////////////////////////////////////////
                      SECURITY REGRESSION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies the full attack scenario is blocked at Case 2
    function test_Case2Attack_Blocked() external {
        // Victim mints SBT
        _simulateVerification(user, TEST_NULLIFIER);
        assertEq(sbtContract.ownerOf(1), user);

        // Attacker tries to link their nullifier to victim's token (Case 2)
        uint256 attackerNullifier = TEST_NULLIFIER + 100;
        _callVerifySelfProof(user);

        vm.expectRevert(OperaSelfSBT.RegisteredNullifier.selector);
        _callOnVerificationSuccess(user, attackerNullifier);
    }

    /*//////////////////////////////////////////////////////////////
                       OWNER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BurnSBT() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 tokenId = 1;
        assertEq(sbtContract.ownerOf(tokenId), user);

        vm.expectEmit(true, true, true, true);
        emit OperaSelfSBT.SBTBurned(tokenId, user);

        vm.prank(owner);
        sbtContract.burnSBT(tokenId);

        vm.expectRevert();
        sbtContract.ownerOf(tokenId);
        assertEq(sbtContract.getTokenIdByAddress(user), 0);
    }

    function test_BurnSBT_OnlyOwner() external {
        _simulateVerification(user, TEST_NULLIFIER);

        vm.expectRevert();
        vm.prank(user);
        sbtContract.burnSBT(1);
    }

    function test_BurnSBT_TokenDoesNotExist() external {
        vm.expectRevert(OperaSelfSBT.TokenDoesNotExist.selector);
        vm.prank(owner);
        sbtContract.burnSBT(999);
    }

    function test_SetValidityPeriod() external {
        uint256 newPeriod = 365 days;

        vm.expectEmit(true, true, true, true);
        emit OperaSelfSBT.ValidityPeriodUpdated(VALIDITY_PERIOD, newPeriod);

        vm.prank(owner);
        sbtContract.setValidityPeriod(newPeriod);

        assertEq(sbtContract.validityPeriod(), newPeriod);
    }

    function test_SetValidityPeriod_OnlyOwner() external {
        vm.expectRevert();
        vm.prank(user);
        sbtContract.setValidityPeriod(365 days);
    }

    function test_SetValidityPeriod_InvalidPeriod() external {
        vm.expectRevert(OperaSelfSBT.InvalidValidityPeriod.selector);
        vm.prank(owner);
        sbtContract.setValidityPeriod(0);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IsTokenValid() external {
        _simulateVerification(user, TEST_NULLIFIER);

        assertEq(sbtContract.isTokenValid(1), true);
        assertEq(sbtContract.isTokenValid(2), false);

        vm.warp(block.timestamp + sbtContract.validityPeriod() + 1);
        assertEq(sbtContract.isTokenValid(1), false);
    }

    function test_GetTokenExpiry() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 expectedExpiry = block.timestamp + VALIDITY_PERIOD;
        assertEq(sbtContract.getTokenExpiry(1), expectedExpiry);
    }

    function test_GetTokenIdByAddress() external {
        assertEq(sbtContract.getTokenIdByAddress(user), 0);

        _simulateVerification(user, TEST_NULLIFIER);

        assertEq(sbtContract.getTokenIdByAddress(user), 1);
    }

    function test_IsNullifierUsed() external {
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), false);

        _simulateVerification(user, TEST_NULLIFIER);

        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
    }

    /*//////////////////////////////////////////////////////////////
                        SOULBOUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TokenIsLocked() external {
        _simulateVerification(user, TEST_NULLIFIER);

        assertTrue(sbtContract.locked(1));
    }

    function test_TransferBlocked() external {
        _simulateVerification(user, TEST_NULLIFIER);

        vm.expectRevert();
        vm.prank(user);
        sbtContract.transferFrom(user, user2, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createMockName() internal pure returns (string[] memory) {
        string[] memory mockName = new string[](1);
        mockName[0] = "Test User";
        return mockName;
    }

    function _simulateVerification(address userAddress, uint256 nullifier) internal {
        _callVerifySelfProof(userAddress);
        _callOnVerificationSuccess(userAddress, nullifier);
    }

    function _callVerifySelfProof(address userAddress) internal {
        bytes memory proofPayload = abi.encodePacked(bytes32(0), bytes("mock_proof_data"));
        bytes memory userContextData = abi.encodePacked(
            bytes32(uint256(block.chainid)),
            bytes32(uint256(uint160(userAddress)))
        );

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);
    }

    function _callOnVerificationSuccess(address userAddress, uint256 nullifier) internal {
        bytes memory userContextData = abi.encodePacked(
            bytes32(uint256(block.chainid)),
            bytes32(uint256(uint160(userAddress)))
        );

        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(userAddress)),
                    nullifier: nullifier,
                    forbiddenCountriesListPacked: [uint256(0), uint256(0), uint256(0), uint256(0)],
                    issuingState: "US",
                    name: _createMockName(),
                    idNumber: "123456789",
                    nationality: "US",
                    dateOfBirth: "1990-01-01",
                    gender: "M",
                    expiryDate: "2030-12-31",
                    olderThan: 18,
                    ofac: [false, false, false]
                })
            ),
            userContextData
        );
    }
}
