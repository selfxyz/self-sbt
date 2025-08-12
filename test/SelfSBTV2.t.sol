// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts-v2/contracts/interfaces/ISelfVerificationRoot.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts-v2/contracts/interfaces/IIdentityVerificationHubV2.sol";
import { IERC5192 } from "../src/interfaces/IERC5192.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { SelfSBTV2 } from "../src/SelfSBTV2.sol";

contract SelfSBTV2Test is Test {
    using ECDSA for bytes32;

    // Test data
    uint256 internal constant SCOPE_VALUE = 12_345;
    uint64 internal constant INVALID_TOKEN_ID = 999;
    uint256 internal constant TEST_NULLIFIER = 54_321;
    uint256 internal constant VALIDITY_PERIOD = 180 days;
    bytes32 internal constant VERIFICATION_CONFIG_ID = bytes32(uint256(0x123));

    // EIP-712 constants
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant VERIFY_IDENTITY_TYPEHASH = keccak256("VerifyIdentity(address wallet,uint256 timestamp)");

    // Test private keys for signing
    uint256 internal constant SIGNER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal constant SIGNER2_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant SIGNER3_PRIVATE_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // Test variables
    SelfSBTV2 internal sbtContract;
    address internal identityHub;
    address internal owner;
    address internal user;
    address internal user2;
    address internal newUser;
    address internal relayer;

    function setUp() public {
        // Create addresses using Foundry best practices
        identityHub = makeAddr("identityHub");
        owner = makeAddr("owner");
        // Use addresses corresponding to the private keys for proper signature verification
        user = vm.addr(SIGNER_PRIVATE_KEY);
        user2 = vm.addr(SIGNER2_PRIVATE_KEY);
        newUser = vm.addr(SIGNER3_PRIVATE_KEY);
        relayer = makeAddr("relayer");

        // Mock the identity hub to say the verification config exists
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(true)
        );

        // Deploy contract
        sbtContract = new SelfSBTV2(identityHub, SCOPE_VALUE, owner, VALIDITY_PERIOD, VERIFICATION_CONFIG_ID);
    }

    function test_SetUp() external view {
        assertEq(sbtContract.name(), "SelfSBTV2");
        assertEq(sbtContract.symbol(), "SELFSBTV2");
        assertEq(sbtContract.validityPeriod(), VALIDITY_PERIOD);
        assertEq(sbtContract.verificationConfigId(), VERIFICATION_CONFIG_ID);
        assertEq(sbtContract.owner(), owner);

        // Check ERC5192 supports interface
        assertTrue(sbtContract.supportsInterface(type(IERC5192).interfaceId));
    }

    function test_Constructor_InvalidValidityPeriod() external {
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(true)
        );

        vm.expectRevert(SelfSBTV2.InvalidValidityPeriod.selector);
        new SelfSBTV2(identityHub, SCOPE_VALUE, owner, 0, VERIFICATION_CONFIG_ID);
    }

    function test_Constructor_VerificationConfigDoesNotExist() external {
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(false)
        );

        vm.expectRevert(SelfSBTV2.VerificationConfigDoesNotExist.selector);
        new SelfSBTV2(identityHub, SCOPE_VALUE, owner, VALIDITY_PERIOD, VERIFICATION_CONFIG_ID);
    }

    function test_IsTokenValid() external {
        _simulateVerification(user, TEST_NULLIFIER);

        // Token is valid
        assertEq(sbtContract.isTokenValid(1), true);

        // Token is not minted
        assertEq(sbtContract.isTokenValid(2), false);

        // Token is minted but expired
        vm.warp(block.timestamp + sbtContract.validityPeriod() + 1);
        assertEq(sbtContract.isTokenValid(1), false);
    }

    function test_GetValidityPeriod() external view {
        assertEq(sbtContract.getValidityPeriod(), VALIDITY_PERIOD);
    }

    function test_GetTokenExpiry() external {
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 expectedExpiry = block.timestamp + VALIDITY_PERIOD;
        assertEq(sbtContract.getTokenExpiry(1), expectedExpiry);
    }

    function test_GetTokenIdByAddress() external {
        // No token initially
        assertEq(sbtContract.getTokenIdByAddress(user), 0);

        // Mint token
        _simulateVerification(user, TEST_NULLIFIER);

        // Should return token ID
        assertEq(sbtContract.getTokenIdByAddress(user), 1);
    }

    function test_IsNullifierUsed() external {
        // Nullifier not used initially
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), false);

        // Use nullifier
        _simulateVerification(user, TEST_NULLIFIER);

        // Should be marked as used
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
    }

    // Case 1: Nullifier NEW + Receiver NO SBT → mint
    function test_VerifySelfProof_Case1_NewNullifier_NoSBT_Mint() external {
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user, TEST_NULLIFIER);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the event right before the callback that emits it
        vm.expectEmit(true, true, true, true);
        emit SelfSBTV2.SBTMinted(user, 1, block.timestamp + VALIDITY_PERIOD);

        // Simulate the hub calling back
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

        // Verify token was minted
        assertEq(sbtContract.ownerOf(1), user);
        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
        assertEq(sbtContract.isTokenValid(1), true);
    }

    // Case 2: Nullifier NEW + Receiver HAS SBT → update
    function test_VerifySelfProof_Case2_NewNullifier_HasSBT_Update() external {
        // First mint an SBT for user
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 originalExpiry = sbtContract.getTokenExpiry(1);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Use a different nullifier for the same user
        uint256 newNullifier = TEST_NULLIFIER + 1;
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user, newNullifier);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the event right before the callback that emits it
        vm.expectEmit(true, true, true, true);
        emit SelfSBTV2.SBTUpdated(1, block.timestamp + VALIDITY_PERIOD);

        // Simulate the hub calling back
        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(user)),
                    nullifier: newNullifier,
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

    // Case 3: Nullifier USED + Receiver NO SBT → recover burned token
    function test_VerifySelfProof_Case3_UsedNullifier_NoSBT_RecoverBurnedToken() external {
        // First user mints with nullifier
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 tokenId = 1;
        assertEq(sbtContract.ownerOf(tokenId), user);

        // Owner burns the token
        vm.prank(owner);
        sbtContract.burnSBT(tokenId);

        // Verify token is burned
        vm.expectRevert();
        sbtContract.ownerOf(tokenId);
        assertEq(sbtContract.getTokenIdByAddress(user), 0);

        // User tries to recover with same nullifier to a different address
        // Using newUser which has a corresponding private key
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(newUser, TEST_NULLIFIER);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the event right before the callback that emits it
        vm.expectEmit(true, true, true, true);
        emit SelfSBTV2.SBTMinted(newUser, tokenId, block.timestamp + VALIDITY_PERIOD);

        // Simulate the hub calling back
        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(newUser)),
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

        // Token should be recovered to new address with same token ID
        assertEq(sbtContract.ownerOf(tokenId), newUser);
        assertEq(sbtContract.getTokenIdByAddress(newUser), tokenId);
        assertEq(sbtContract.isTokenValid(tokenId), true);
    }

    // Case 3: Nullifier USED + Receiver NO SBT → revert if token still active
    function test_VerifySelfProof_Case3_UsedNullifier_NoSBT_RevertIfActive() external {
        // First user mints with nullifier
        _simulateVerification(user, TEST_NULLIFIER);

        // Different user tries to use same nullifier (token still active)
        // Using user2 which has a corresponding private key
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user2, TEST_NULLIFIER);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the revert in the callback
        vm.expectRevert(SelfSBTV2.RegisteredNullifier.selector);
        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(user2)),
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

    // Case 4: Nullifier USED + Receiver HAS SBT → check owner match
    function test_VerifySelfProof_Case4_UsedNullifier_HasSBT_SameOwner_Update() external {
        // User mints with nullifier
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 originalExpiry = sbtContract.getTokenExpiry(1);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Same user uses same nullifier again (should update)
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user, TEST_NULLIFIER);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the event right before the callback that emits it
        vm.expectEmit(true, true, true, true);
        emit SelfSBTV2.SBTUpdated(1, block.timestamp + VALIDITY_PERIOD);

        // Simulate the hub calling back
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

        // Should still be only one token, but expiry updated
        assertEq(sbtContract.balanceOf(user), 1);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);

        uint256 newExpiry = sbtContract.getTokenExpiry(1);
        assertGt(newExpiry, originalExpiry);
    }

    function test_VerifySelfProof_Case4_UsedNullifier_HasSBT_DifferentOwner_Revert() external {
        // User1 mints with nullifier
        _simulateVerification(user, TEST_NULLIFIER);

        // User2 gets an SBT with different nullifier
        // Using user2 which has a corresponding private key
        uint256 user2Nullifier = TEST_NULLIFIER + 1;
        _simulateVerification(user2, user2Nullifier);

        // User2 tries to use User1's nullifier (should revert)
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user2, TEST_NULLIFIER);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the revert in the callback
        vm.expectRevert(SelfSBTV2.RegisteredNullifier.selector);
        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(user2)),
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

    // Owner functions tests
    function test_BurnSBT() external {
        // Mint token first
        _simulateVerification(user, TEST_NULLIFIER);

        uint256 tokenId = 1;
        assertEq(sbtContract.ownerOf(tokenId), user);

        // Owner burns the token
        vm.expectEmit(true, true, true, true);
        emit SelfSBTV2.SBTBurned(tokenId, user);

        vm.prank(owner);
        sbtContract.burnSBT(tokenId);

        // Token should be burned
        vm.expectRevert();
        sbtContract.ownerOf(tokenId);
        assertEq(sbtContract.getTokenIdByAddress(user), 0);
    }

    function test_BurnSBT_OnlyOwner() external {
        // Mint token first
        _simulateVerification(user, TEST_NULLIFIER);

        // Non-owner tries to burn
        vm.expectRevert();
        vm.prank(user);
        sbtContract.burnSBT(1);
    }

    function test_BurnSBT_TokenDoesNotExist() external {
        vm.expectRevert(SelfSBTV2.TokenDoesNotExist.selector);
        vm.prank(owner);
        sbtContract.burnSBT(999);
    }

    function test_SetValidityPeriod() external {
        uint256 newPeriod = 365 days;

        vm.expectEmit(true, true, true, true);
        emit SelfSBTV2.ValidityPeriodUpdated(VALIDITY_PERIOD, newPeriod);

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
        vm.expectRevert(SelfSBTV2.InvalidValidityPeriod.selector);
        vm.prank(owner);
        sbtContract.setValidityPeriod(0);
    }

    // Test invalid signature (wrong signer)
    function test_InvalidUserData_WrongSigner() external {
        // Try to verify with user2 but use a signature from user (mismatch)
        address targetUser = user2;
        bytes memory proofPayload = abi.encode("mock_proof_payload", TEST_NULLIFIER, targetUser);

        // Create signature with user's key but claim it's for user2
        uint256 timestamp = block.timestamp;
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Self SBT Verification")),
                keccak256(bytes("1")),
                block.chainid,
                address(sbtContract)
            )
        );

        // Sign for user (not user2)
        bytes32 structHash = keccak256(
            abi.encode(
                VERIFY_IDENTITY_TYPEHASH,
                user, // Sign for user
                timestamp
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // But claim the signature is for user2
        bytes memory userContextData = abi.encodePacked(signature, bytes32(timestamp));

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the revert when hub calls back
        vm.expectRevert(SelfSBTV2.InvalidSignature.selector);
        vm.prank(identityHub);
        sbtContract.onVerificationSuccess(
            abi.encode(
                ISelfVerificationRoot.GenericDiscloseOutputV2({
                    attestationId: bytes32(0),
                    userIdentifier: uint256(uint160(targetUser)),
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

    // Test expired signature
    function test_InvalidUserData_SignatureExpired() external {
        // Create signature with old timestamp
        uint256 oldTimestamp = block.timestamp - 601; // 10 minutes + 1 second ago

        bytes memory proofPayload = abi.encode("mock_proof_payload", TEST_NULLIFIER, user);

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Self SBT Verification")),
                keccak256(bytes("1")),
                block.chainid,
                address(sbtContract)
            )
        );

        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, user, oldTimestamp));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory userContextData = abi.encodePacked(signature, bytes32(oldTimestamp));

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the revert when hub calls back
        vm.expectRevert(SelfSBTV2.SignatureExpired.selector);
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

    // Helper functions
    function _prepareForVerifySelfProof() internal returns (bytes memory proofPayload, bytes memory userContextData) {
        return _prepareForVerifySelfProofWithNullifier(user, TEST_NULLIFIER);
    }

    function _createMockName() internal pure returns (string[] memory) {
        string[] memory mockName = new string[](1);
        mockName[0] = "Test User";
        return mockName;
    }

    function _simulateVerification(address userAddress, uint256 nullifier) internal {
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(userAddress, nullifier);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Simulate the hub calling back
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

    function _simulateVerificationWithEvent(address userAddress, uint256 nullifier) internal {
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(userAddress, nullifier);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Simulate the hub calling back - this is where the event will be emitted
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

    function _prepareForVerifySelfProofWithNullifier(
        address userAddress,
        uint256 nullifier
    )
        internal
        returns (bytes memory proofPayload, bytes memory userContextData)
    {
        // Create mock payload
        proofPayload = abi.encode("mock_proof_payload", nullifier, userAddress);

        // Create EIP-712 signature for the user
        uint256 timestamp = block.timestamp;

        // Create domain separator for the deployed contract
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Self SBT Verification")),
                keccak256(bytes("1")),
                block.chainid,
                address(sbtContract)
            )
        );

        // Create the struct hash
        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, userAddress, timestamp));

        // Create the digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Determine which private key to use based on the user address
        uint256 privateKey;
        if (userAddress == user) {
            privateKey = SIGNER_PRIVATE_KEY;
        } else if (userAddress == user2) {
            privateKey = SIGNER2_PRIVATE_KEY;
        } else if (userAddress == newUser) {
            privateKey = SIGNER3_PRIVATE_KEY;
        } else {
            // For any other address, use the default key (tests will likely fail but at least compile)
            privateKey = SIGNER_PRIVATE_KEY;
        }

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Pack the user context data with signature and timestamp
        // Format: signature (65 bytes) + timestamp (32 bytes)
        userContextData = abi.encodePacked(signature, bytes32(timestamp));
    }
}
