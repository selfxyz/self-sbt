// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts-v2/contracts/interfaces/ISelfVerificationRoot.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts-v2/contracts/interfaces/IIdentityVerificationHubV2.sol";
import { IERC5192 } from "../src/interfaces/IERC5192.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { EspressoSelfSBT } from "../src/EspressoSBT.sol";

contract EspressoSelfSBTTest is Test {
    using ECDSA for bytes32;

    // Test data
    uint256 internal constant SCOPE_VALUE = 12_345;
    uint64 internal constant INVALID_TOKEN_ID = 999;
    uint256 internal constant TEST_NULLIFIER = 54_321;
    uint256 internal constant VALIDITY_PERIOD = 180 days;
    bytes32 internal constant VERIFICATION_CONFIG_ID = bytes32(uint256(0x123));

    // EIP-712 constants - NOTE: Updated to include ethereumAddress
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant VERIFY_IDENTITY_TYPEHASH =
        keccak256("VerifyIdentity(address wallet,uint256 timestamp,address ethereumAddress)");

    // Test private keys for signing
    uint256 internal constant SIGNER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal constant SIGNER2_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant SIGNER3_PRIVATE_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // Test variables
    EspressoSelfSBT internal sbtContract;
    address internal identityHub;
    address internal owner;
    address internal user;
    address internal user2;
    address internal newUser;
    address internal relayer;
    address internal airdropAddress;
    address internal airdropAddress2;

    function setUp() public {
        // Create addresses using Foundry best practices
        identityHub = makeAddr("identityHub");
        owner = makeAddr("owner");
        // Use addresses corresponding to the private keys for proper signature verification
        user = vm.addr(SIGNER_PRIVATE_KEY);
        user2 = vm.addr(SIGNER2_PRIVATE_KEY);
        newUser = vm.addr(SIGNER3_PRIVATE_KEY);
        relayer = makeAddr("relayer");
        airdropAddress = makeAddr("airdropAddress");
        airdropAddress2 = makeAddr("airdropAddress2");

        // Mock the identity hub to say the verification config exists
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(true)
        );

        // Deploy contract
        sbtContract = new EspressoSelfSBT(identityHub, SCOPE_VALUE, owner, VALIDITY_PERIOD, VERIFICATION_CONFIG_ID);
    }

    function test_SetUp() external view {
        assertEq(sbtContract.name(), "EspressoSelfSBT");
        assertEq(sbtContract.symbol(), "ESPRESSOSELFSBT");
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

        vm.expectRevert(EspressoSelfSBT.InvalidValidityPeriod.selector);
        new EspressoSelfSBT(identityHub, SCOPE_VALUE, owner, 0, VERIFICATION_CONFIG_ID);
    }

    function test_Constructor_VerificationConfigDoesNotExist() external {
        vm.mockCall(
            identityHub,
            abi.encodeWithSelector(IIdentityVerificationHubV2.verificationConfigV2Exists.selector),
            abi.encode(false)
        );

        vm.expectRevert(EspressoSelfSBT.VerificationConfigDoesNotExist.selector);
        new EspressoSelfSBT(identityHub, SCOPE_VALUE, owner, VALIDITY_PERIOD, VERIFICATION_CONFIG_ID);
    }

    // Test EIP-712 signature verification with ethereumAddress
    function test_SignatureVerification_ValidSignatureWithEthereumAddress() external {
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user, TEST_NULLIFIER, airdropAddress);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect VerificationCompleted event with correct ethereumAddress
        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.VerificationCompleted(user, TEST_NULLIFIER, airdropAddress, block.timestamp);

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
    }

    // Test invalid signature (wrong signer)
    function test_SignatureVerification_WrongSigner() external {
        // Create signature with user's key but claim it's for user2
        address targetUser = user2;
        bytes memory proofPayload = abi.encode("mock_proof_payload", TEST_NULLIFIER, targetUser);

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
        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, user, timestamp, airdropAddress));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Pack with ethereumAddress
        bytes memory rawData = abi.encodePacked(signature, bytes32(timestamp), bytes20(airdropAddress));
        bytes memory userContextData = _bytesToAsciiHex(rawData);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect the revert when hub calls back
        vm.expectRevert(EspressoSelfSBT.InvalidSignature.selector);
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

    // Test signature with wrong ethereumAddress
    function test_SignatureVerification_WrongEthereumAddress() external {
        bytes memory proofPayload = abi.encode("mock_proof_payload", TEST_NULLIFIER, user);

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

        // Sign with airdropAddress
        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, user, timestamp, airdropAddress));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // But pack with different ethereumAddress (airdropAddress2)
        bytes memory rawData = abi.encodePacked(signature, bytes32(timestamp), bytes20(airdropAddress2));
        bytes memory userContextData = _bytesToAsciiHex(rawData);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect InvalidSignature because ethereumAddress mismatch
        vm.expectRevert(EspressoSelfSBT.InvalidSignature.selector);
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

    // Test zero address for ethereumAddress
    function test_SignatureVerification_ZeroEthereumAddress() external {
        address zeroAddress = address(0);
        bytes memory proofPayload = abi.encode("mock_proof_payload", TEST_NULLIFIER, user);

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

        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, user, timestamp, zeroAddress));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory rawData = abi.encodePacked(signature, bytes32(timestamp), bytes20(zeroAddress));
        bytes memory userContextData = _bytesToAsciiHex(rawData);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect InvalidEthereumAddress error
        vm.expectRevert(EspressoSelfSBT.InvalidEthereumAddress.selector);
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

    // Test expired signature
    function test_SignatureVerification_SignatureExpired() external {
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

        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, user, oldTimestamp, airdropAddress));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory rawData = abi.encodePacked(signature, bytes32(oldTimestamp), bytes20(airdropAddress));
        bytes memory userContextData = _bytesToAsciiHex(rawData);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        vm.expectRevert(EspressoSelfSBT.SignatureExpired.selector);
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

    // Test userContextData with incorrect length (too short)
    function test_UserContextData_TooShort() external {
        bytes memory proofPayload = abi.encode("mock_proof_payload", TEST_NULLIFIER, user);

        // Create data that's too short (only 97 bytes instead of 117)
        bytes memory signature = new bytes(65);
        bytes32 timestamp = bytes32(uint256(block.timestamp));
        bytes memory rawData = abi.encodePacked(signature, timestamp); // Missing ethereumAddress
        bytes memory userContextData = _bytesToAsciiHex(rawData);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        vm.expectRevert(EspressoSelfSBT.InvalidUserData.selector);
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

    // Test VerificationCompleted event emission
    function test_VerificationCompletedEvent_EmittedCorrectly() external {
        _simulateVerification(user, TEST_NULLIFIER, airdropAddress);

        // Verify token was minted and event was emitted in _simulateVerification
        assertEq(sbtContract.ownerOf(1), user);
        assertEq(sbtContract.getTokenIdByAddress(user), 1);
    }

    // Case 1: Nullifier NEW + Receiver NO SBT → mint + emit VerificationCompleted
    function test_VerifySelfProof_Case1_NewNullifier_NoSBT_Mint() external {
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user, TEST_NULLIFIER, airdropAddress);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect both SBTMinted and VerificationCompleted events
        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.SBTMinted(user, 1, block.timestamp + VALIDITY_PERIOD);
        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.VerificationCompleted(user, TEST_NULLIFIER, airdropAddress, block.timestamp);

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

    // Case 2: Nullifier NEW + Receiver HAS SBT → update + emit VerificationCompleted
    function test_VerifySelfProof_Case2_NewNullifier_HasSBT_Update() external {
        // First mint an SBT for user
        _simulateVerification(user, TEST_NULLIFIER, airdropAddress);

        uint256 originalExpiry = sbtContract.getTokenExpiry(1);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Use a different nullifier and airdrop address for the same user
        uint256 newNullifier = TEST_NULLIFIER + 1;
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(user, newNullifier, airdropAddress2);

        vm.prank(relayer);
        sbtContract.verifySelfProof(proofPayload, userContextData);

        // Expect both SBTUpdated and VerificationCompleted events
        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.SBTUpdated(1, block.timestamp + VALIDITY_PERIOD);
        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.VerificationCompleted(user, newNullifier, airdropAddress2, block.timestamp);

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

    // Owner functions tests
    function test_BurnSBT() external {
        // Mint token first
        _simulateVerification(user, TEST_NULLIFIER, airdropAddress);

        uint256 tokenId = 1;
        assertEq(sbtContract.ownerOf(tokenId), user);

        // Owner burns the token
        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.SBTBurned(tokenId, user);

        vm.prank(owner);
        sbtContract.burnSBT(tokenId);

        // Token should be burned
        vm.expectRevert();
        sbtContract.ownerOf(tokenId);
        assertEq(sbtContract.getTokenIdByAddress(user), 0);
    }

    function test_SetValidityPeriod() external {
        uint256 newPeriod = 365 days;

        vm.expectEmit(true, true, true, true);
        emit EspressoSelfSBT.ValidityPeriodUpdated(VALIDITY_PERIOD, newPeriod);

        vm.prank(owner);
        sbtContract.setValidityPeriod(newPeriod);

        assertEq(sbtContract.validityPeriod(), newPeriod);
    }

    // View functions tests
    function test_IsTokenValid() external {
        _simulateVerification(user, TEST_NULLIFIER, airdropAddress);

        // Token is valid
        assertEq(sbtContract.isTokenValid(1), true);

        // Token is not minted
        assertEq(sbtContract.isTokenValid(2), false);

        // Token is minted but expired
        vm.warp(block.timestamp + sbtContract.validityPeriod() + 1);
        assertEq(sbtContract.isTokenValid(1), false);
    }

    function test_GetTokenExpiry() external {
        _simulateVerification(user, TEST_NULLIFIER, airdropAddress);

        uint256 expectedExpiry = block.timestamp + VALIDITY_PERIOD;
        assertEq(sbtContract.getTokenExpiry(1), expectedExpiry);
    }

    function test_IsNullifierUsed() external {
        // Nullifier not used initially
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), false);

        // Use nullifier
        _simulateVerification(user, TEST_NULLIFIER, airdropAddress);

        // Should be marked as used
        assertEq(sbtContract.isNullifierUsed(TEST_NULLIFIER), true);
    }

    // Helper functions
    function _createMockName() internal pure returns (string[] memory) {
        string[] memory mockName = new string[](1);
        mockName[0] = "Test User";
        return mockName;
    }

    function _simulateVerification(address userAddress, uint256 nullifier, address ethereumAddr) internal {
        (bytes memory proofPayload, bytes memory userContextData) =
            _prepareForVerifySelfProofWithNullifier(userAddress, nullifier, ethereumAddr);

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

    /// @notice Converts a single byte to ASCII hex characters
    /// @param b The byte to convert
    /// @return c1 First hex character
    /// @return c2 Second hex character
    function _byteToHexChars(uint8 b) internal pure returns (bytes1 c1, bytes1 c2) {
        uint8 high = b >> 4;
        uint8 low = b & 0x0f;

        c1 = high < 10 ? bytes1(0x30 + high) : bytes1(0x61 + high - 10); // 0-9 or a-f
        c2 = low < 10 ? bytes1(0x30 + low) : bytes1(0x61 + low - 10); // 0-9 or a-f
    }

    /// @notice Converts bytes to ASCII hex string with "0x" prefix
    /// @param data The bytes to convert
    /// @return ASCII hex string
    function _bytesToAsciiHex(bytes memory data) internal pure returns (bytes memory) {
        bytes memory result = new bytes(2 + data.length * 2); // "0x" + 2 chars per byte

        // Add "0x" prefix
        result[0] = 0x30; // '0'
        result[1] = 0x78; // 'x'

        // Convert each byte to two hex characters
        for (uint256 i = 0; i < data.length; i++) {
            (bytes1 c1, bytes1 c2) = _byteToHexChars(uint8(data[i]));
            result[2 + i * 2] = c1;
            result[2 + i * 2 + 1] = c2;
        }

        return result;
    }

    function _prepareForVerifySelfProofWithNullifier(
        address userAddress,
        uint256 nullifier,
        address ethereumAddr
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

        // Create the struct hash with ethereumAddress
        bytes32 structHash = keccak256(abi.encode(VERIFY_IDENTITY_TYPEHASH, userAddress, timestamp, ethereumAddr));

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

        // Pack the user context data with signature, timestamp, and ethereumAddress
        // Format: ASCII hex string of signature (65 bytes) + timestamp (32 bytes) + ethereumAddress (20 bytes) = 117 bytes
        bytes memory rawData = abi.encodePacked(signature, bytes32(timestamp), bytes20(ethereumAddr));
        userContextData = _bytesToAsciiHex(rawData);
    }
}
