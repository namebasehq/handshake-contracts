// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "contracts/HandshakeNft.sol";
import "interfaces/resolvers/INameResolver.sol";
import "contracts/resolvers/BaseResolver.sol";
import {Namehash} from "utils/Namehash.sol";
import "interfaces/IResolver.sol";
import "interfaces/resolvers/IAddressResolver.sol";

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

    function setName(string calldata _name) external {
        nameMap[msg.sender] = _name;
    }

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
                }
            } catch {
                return "";
            }
        }

        return "";
    }

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
                }
            } catch {
                return "";
            }
        }

        return "";
    }

    function getResolver(bytes32 node) private view returns (IResolver) {
        uint256 id = uint256(node);

        if (sldContract.exists(id)) {
            return sldContract.tokenResolverMap(node);
        }

        if (tldContract.exists(id)) {
            return tldContract.tokenResolverMap(node);
        }

        return IResolver(address(0));
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(INameResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}
