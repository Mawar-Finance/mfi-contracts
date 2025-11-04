// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Custom errors (hemat gas)
library Errors {
    error ZeroAddress();
    error InvalidAmount();
    error NotMultipleOfRoseUnit();
    error ExceedsMaxRoses();
    error NotTokenOwner();
    error Unauthorized();
}
