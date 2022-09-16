// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ISldRegistrationStrategy.sol";

interface IHandshakeSld {
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);

    function registerSld(
        address _to,
        bytes32 _tldNamehash,
        bytes32 _sldNamehash
    ) external;

    function getRegistrationStrategy(bytes32 _parentNamehash)
        external
        view
        returns (ISldRegistrationStrategy);
}
