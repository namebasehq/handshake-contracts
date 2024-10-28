// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// create2 factory
contract Factory {
    address public owner;

    event Deployed(address addr, uint256 salt);

    constructor() {
        owner = msg.sender;
    }

    function deploy(bytes memory code, uint256 salt) public {
        require(msg.sender == owner, "Only the contract owner can deploy");

        address addr;
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }

        emit Deployed(addr, salt);
    }
}
