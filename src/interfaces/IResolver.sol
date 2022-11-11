// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "interfaces/resolvers/IABIResolver.sol";
import "interfaces/resolvers/IAddressResolver.sol";
import "interfaces/resolvers/IAddrResolver.sol";
import "interfaces/resolvers/IContentHashResolver.sol";
import "interfaces/resolvers/IDNSRecordResolver.sol";
import "interfaces/resolvers/IDNSZoneResolver.sol";
import "interfaces/resolvers/IInterfaceResolver.sol";
import "interfaces/resolvers/INameResolver.sol";
import "interfaces/resolvers/ITextResolver.sol";

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
    ITextResolver
{

}
