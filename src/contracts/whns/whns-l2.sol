// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OptimismMintableERC20} from "./bedrock-contracts/OptimismMintableERC20.sol";

/// @title Wrapped Handshake ERC20
/// @notice Wrapped Handshake ERC20 is a token contract that inherits from OptimismMintableERC20
///         and serves as the L2 representation of the WHNS token.
contract WrappedHandshake is OptimismMintableERC20 {
    /// @param _bridge      Address of the L2 standard bridge.
    /// @param _remoteToken Address of the corresponding L1 token.
    constructor(
        address _bridge,
        address _remoteToken
    ) OptimismMintableERC20(_bridge, _remoteToken, "Wrapped Handshake", "WHNS", 6) {}
}
