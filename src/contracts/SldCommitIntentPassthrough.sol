// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/ICommitIntent.sol";

/**
 * @title SLD intent to register
 * @author Sam Ward
 * @notice This contract is for registering intent to register a SLD
 * @dev This contract is just a passthrough, we can update the commit intent in the
 *     future if we want to
 */
contract SldCommitIntentPassthrough is ICommitIntent {
    function updateMaxBlockWaitForCommit(uint256) external pure {
        revert("commit intent not required");
    }

    function updateMinBlockWaitForCommit(uint256) external pure {
        revert("commit intent not required");
    }

    function commitIntent(bytes32) external pure {
        revert("commit intent not required");
    }

    function multiCommitIntent(bytes32[] calldata) external pure {
        revert("commit intent not required");
    }

    function allowedCommit(bytes32, bytes32, address) external pure returns (bool) {
        return true;
    }

    function maxBlockWaitForCommit() external pure returns (uint256) {
        return type(uint256).max;
    }

    function minBlockWaitForCommit() external pure returns (uint256) {
        return 0;
    }
}
