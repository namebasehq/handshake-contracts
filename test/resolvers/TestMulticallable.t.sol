// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "contracts/resolvers/DefaultResolver.sol";
import "test/mocks/MockHandshakeNft.sol";

contract TestMulticallable is Test {
    DefaultResolver resolver;
    MockHandshakeNft tld;
    MockHandshakeNft sld;

    function setUp() public {
        tld = new MockHandshakeNft();
        sld = new MockHandshakeNft();

        resolver = new DefaultResolver(tld, sld);
    }

    bytes[] testArray;

    function testSetMultiple() public {
        address owner = address(0x99887766);
        uint256 id = 696969;

        sld.mint(owner, id);

        bytes[] memory calldataArray;

        bytes32 node = bytes32(id);
        string memory key = "key";
        string memory value = "value";

        //resolver.setText(node, key, value);

        bytes memory selector1 = abi.encodePacked(bytes4(keccak256("test()")));
        bytes memory selector2 = abi.encodeWithSelector(
            bytes4(keccak256("setText(bytes32,string,string)")),
            key,
            value
        );

        testArray.push(selector1);

        resolver.multicall(testArray);
    }
}
