// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "ens/resolvers/profiles/IABIResolver.sol";
import "ens/resolvers/profiles/IAddressResolver.sol";
import "ens/resolvers/profiles/IAddrResolver.sol";
import "ens/resolvers/profiles/IContentHashResolver.sol";
import "ens/resolvers/profiles/IDNSRecordResolver.sol";
import "ens/resolvers/profiles/IDNSZoneResolver.sol";
import "ens/resolvers/profiles/IInterfaceResolver.sol";
import "ens/resolvers/profiles/INameResolver.sol";
import "ens/resolvers/profiles/IPubkeyResolver.sol";
import "ens/resolvers/profiles/ITextResolver.sol";
import "ens/resolvers/profiles/IExtendedResolver.sol";

/**
 * A generic resolver interface which includes all the functions including the ones deprecated
 */
interface IResolver is
    IERC165,
    IABIResolver,
    IAddressResolver,
    IAddrResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    IPubkeyResolver,
    ITextResolver,
    IExtendedResolver
{
    /* Deprecated events */
    event ContentChanged(bytes32 indexed node, bytes32 hash);

    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external;

    function setAddr(bytes32 node, address addr) external;

    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes calldata a
    ) external;

    function setContenthash(bytes32 node, bytes calldata hash) external;

    function setDnsrr(bytes32 node, bytes calldata data) external;

    function setName(bytes32 node, string calldata _name) external;

    function setPubkey(
        bytes32 node,
        bytes32 x,
        bytes32 y
    ) external;

    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external;

    function setInterface(
        bytes32 node,
        bytes4 interfaceID,
        address implementer
    ) external;

    function multicall(bytes[] calldata data)
        external
        returns (bytes[] memory results);

    /* Deprecated functions */
    function content(bytes32 node) external view returns (bytes32);

    function multihash(bytes32 node) external view returns (bytes memory);

    function setContent(bytes32 node, bytes32 hash) external;

    function setMultihash(bytes32 node, bytes calldata hash) external;
}
