// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract TestTests is Test {
    function testTest() public {
        bytes memory hexBytes = hex"04746573740a74657374696e673738390365746800";
        string memory stringVal = hexToText(hexBytes);
        console.log(stringVal); // Should print "testing789.eth"

        hexBytes = hex"74657374696e673738390365746800";

        stringVal = hexToText(hexBytes);
        console.log(stringVal); // Should print "testing789.eth"
    }

    function hexToText(bytes memory hexBytes) public pure returns (string memory) {
<<<<<<< HEAD
        uint256 start = 0;
        // Find the first line break (0x0a)
        for (uint256 i = 0; i < hexBytes.length; i++) {
=======
        uint start = 0;
        // Find the first line break (0x0a)
        for (uint i = 0; i < hexBytes.length; i++) {
>>>>>>> main
            if (hexBytes[i] == 0x0a) {
                start = i + 1;
                break;
            }
        }

        // Initialize the final bytes array
        bytes memory tempBytes = new bytes(hexBytes.length - start - 1);
<<<<<<< HEAD
        uint256 tempIndex = 0;

        for (uint256 i = start; i < hexBytes.length; i++) {
=======
        uint tempIndex = 0;

        for (uint i = start; i < hexBytes.length; i++) {
>>>>>>> main
            if (hexBytes[i] == 0x00) {
                break; // Ignore termination byte and stop processing
            } else if (hexBytes[i] == 0x03) {
                tempBytes[tempIndex] = bytes1(uint8(0x2e)); // Replace ETX with dot
            } else {
                tempBytes[tempIndex] = hexBytes[i];
            }
            tempIndex++;
        }

        // Create the final bytes array with the exact length of valid characters
        bytes memory strBytes = new bytes(tempIndex);
<<<<<<< HEAD
        for (uint256 j = 0; j < tempIndex; j++) {
=======
        for (uint j = 0; j < tempIndex; j++) {
>>>>>>> main
            strBytes[j] = tempBytes[j];
        }

        return string(strBytes);
    }
}
