// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPoseidonT3 {
    function hash(uint256[2] memory inputs) external pure returns (uint256);
}
