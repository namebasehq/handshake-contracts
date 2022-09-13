// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "ens/resolvers/profiles/ABIResolver.sol";
import "ens/resolvers/profiles/AddrResolver.sol";
import "ens/resolvers/profiles/ContentHashResolver.sol";
import "ens/resolvers/profiles/DNSResolver.sol";
import "ens/resolvers/profiles/InterfaceResolver.sol";
import "ens/resolvers/profiles/NameResolver.sol";
import "ens/resolvers/profiles/PubkeyResolver.sol";
import "ens/resolvers/profiles/TextResolver.sol";
import "ens/resolvers/Multicallable.sol";

/**
 * A simple resolver that only allows the owner of a node to set its address.
 */
contract OwnedResolver is
    Ownable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver
{

    address immutable tldContract;
    address immutable sldContract;

    constructor(address _tldContract, address _sldContract) {
        tldContract = _tldContract;
        sldContract = _sldContract;
    }

    function isAuthorised(bytes32) internal view override returns (bool) {
        return msg.sender == owner();
    }

    function supportsInterface(bytes4 interfaceID)
        public
        view
        virtual
        override(
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}
