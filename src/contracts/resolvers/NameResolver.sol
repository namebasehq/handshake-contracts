// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "interfaces/resolvers/INameResolver.sol";
import "contracts/resolvers/BaseResolver.sol";
import {Namehash} from "utils/Namehash.sol";

/**
 * @title NameResolver aka Reverse Resolver
 * @notice NameResolver is a contract that allows users to set the domain name for their address
 * @author Sam Ward (hodl.esf.eth)
 */
abstract contract NameResolver is INameResolver, BaseResolver {
    mapping(address => string) public nameMap;

    function name(bytes32 node) external view returns (string memory) {
        uint256 id = uint256(node);

        if (sldContract.exists(id)) {
            return sldContract.name(node);
        }

        if (tldContract.exists(id)) {
            return tldContract.name(node);
        }

        revert("id does not exist");
    }

    /**
     * @notice setName sets the domain linked to an address.
     * @dev setName sets the domain value associated with a specific address. It uses
     * msg.sender to get the address and then sets the value for that address.
     * @param _name The domain name you wish to set. Can be TLD or SLD.
     */
    function setName(string calldata _name) external {
        nameMap[msg.sender] = _name;

        emit ReverseClaimed(msg.sender, _name);
    }

    /**
     * @notice getName records the value associated with a specific domain for an address.
     * @dev getName gets the value associated with a specific domain for an address. This is validated that the
     * address is correct and not invalid or changed
     * @param _addr The address to query.
     * @param _coinType The coin type to query.
     */
    function getName(address _addr, uint256 _coinType) external view returns (string memory) {
        string memory reverseName = nameMap[_addr];
        IResolver resolver;

        if (bytes(reverseName).length == 0) {
            return "";
        }

        bytes32 node = Namehash.getDomainNamehash(reverseName);
        resolver = getResolver(node);

        if (
            address(resolver) != address(0) &&
            resolver.supportsInterface(type(IAddressResolver).interfaceId)
        ) {
            try resolver.addr(node, _coinType) returns (bytes memory resolvedAddress) {
                address addr;

                assembly {
                    addr := mload(add(resolvedAddress, 20))
                }

                if (addr == _addr) {
                    return reverseName;
                } else {
                    return "";
                }
            } catch {
                return "";
            }
        }

        return "";
    }

    /**
     * @notice getText records the value associated with a specific key for an address.
     * @dev getText records the value associated with a specific key for an address. This is validated that the
     * address is correct and not invalid or changed
     * @param _addr The address to query.
     * @param _key The key to query.
     * @param _coinType The coin type to query.
     */
    function getText(address _addr, string calldata _key, uint256 _coinType)
        external
        view
        returns (string memory)
    {
        string memory reverseName = nameMap[_addr];
        IResolver resolver;

        if (bytes(reverseName).length == 0) {
            return "";
        }

        bytes32 node = Namehash.getDomainNamehash(reverseName);

        resolver = getResolver(node);

        if (
            address(resolver) != address(0) &&
            resolver.supportsInterface(type(IAddressResolver).interfaceId) &&
            resolver.supportsInterface(type(ITextResolver).interfaceId)
        ) {
            try resolver.addr(node, _coinType) returns (bytes memory resolvedAddress) {
                address addr;

                assembly {
                    addr := mload(add(resolvedAddress, 20))
                }

                if (addr == _addr) {
                    try resolver.text(node, _key) returns (string memory text) {
                        return text;
                    } catch {
                        return "";
                    }
                } else {
                    return "";
                }
            } catch {
                return "";
            }
        }

        return "";
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(INameResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}
