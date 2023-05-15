// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "interfaces/resolvers/ITextResolver.sol";
import "contracts/resolvers/BaseResolver.sol";
import "contracts/HandshakeSld.sol";

abstract contract TextResolver is ITextResolver, BaseResolver {
    mapping(uint256 => mapping(bytes32 => mapping(string => string))) versionable_texts;

    function text(bytes32 node, string calldata key) public view returns (string memory) {
        string memory avatar;

        if (
            keccak256(bytes(key)) == keccak256(bytes("avatar")) && sldContract.exists(uint256(node))
        ) {
            avatar = getParentAvatar(node, key);
            string memory thisAvatar = versionable_texts[recordVersions[node]][node][key];
            return (bytes(thisAvatar).length == 0) ? avatar : thisAvatar;
        }
       
        return versionable_texts[recordVersions[node]][node][key];       
    }

    /**
     * Sets the text data associated with an ENS node and key.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setText(bytes32 node, string calldata key, string calldata value)
        public
        virtual
        authorised(node)
    {
        versionable_texts[recordVersions[node]][node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(ITextResolver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    function getParentAvatar(bytes32 node, string calldata key)
        private
        view
        returns (string memory)
    {
        HandshakeSld sld = HandshakeSld(address(sldContract));
        bytes32 parentNode = sld.namehashToParentMap(node);
        IResolver resolver = getResolver(parentNode);

        return resolver.text(parentNode, key);
    }
}
