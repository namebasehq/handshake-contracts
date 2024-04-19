/// @author raffy.eth
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// interfaces
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {IExtendedDNSResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedDNSResolver.sol";
import {IAddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {INameResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/INameResolver.sol";
import {IPubkeyResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IPubkeyResolver.sol";
import {IContentHashResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IContentHashResolver.sol";
import {IMulticallable} from "@ensdomains/ens-contracts/contracts/resolvers/IMulticallable.sol";

// libraries
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BytesUtils} from "@ensdomains/ens-contracts/contracts/wrapper/BytesUtils.sol";
import {HexUtils} from "@ensdomains/ens-contracts/contracts/utils/HexUtils.sol";

// https://eips.ethereum.org/EIPS/eip-3668
error OffchainLookup(address from, string[] urls, bytes request, bytes4 callback, bytes carry);

interface IOnchainResolver {
    function onchain(bytes32 node) external view returns (bool);
    event OnchainChanged(bytes32 indexed node, bool on);
}

contract OffchainResolver is
    IERC165,
    ITextResolver,
    IAddrResolver,
    IAddressResolver,
    IPubkeyResolver,
    IContentHashResolver,
    IMulticallable,
    IExtendedResolver,
    IExtendedDNSResolver,
    IOnchainResolver,
    INameResolver
{
    using BytesUtils for bytes;
    using HexUtils for bytes;

    error Unauthorized(address owner); // not operator of node
    error InvalidContext(bytes context); // context too short or invalid signer
    error Unreachable(bytes name);
    error CCIPReadExpired(uint256 t); // ccip response is stale
    error CCIPReadUntrusted(address signed, address expect);
    error NodeCheck(bytes32 node);

    uint256 constant COIN_TYPE_ETH = 60;
    uint256 constant COIN_TYPE_FALLBACK =
        0xb32cdf4d3c016cb0f079f205ad61c36b1a837fb3e95c70a94bdedfca0518a010; // https://adraffy.github.io/keccak.js/test/demo.html#algo=keccak-256&s=fallback&escape=1&encoding=utf8
    string constant TEXT_CONTEXT = "ccip.context";
    bool constant REPLACE_WITH_ONCHAIN = true;
    bool constant OFFCHAIN_ONLY = false;
    bool constant CALL_WITH_NULL_NODE = true;
    bool constant CALL_UNMODIFIED = false;
    bytes4 constant PREFIX_ONLY_OFF = 0x000000FF;
    bytes4 constant PREFIX_ONLY_ON = ~PREFIX_ONLY_OFF;
    uint256 constant ERC165_GAS_LIMIT = 30000; // https://eips.ethereum.org/EIPS/eip-165

    ENS immutable ens;
    constructor(ENS a) {
        ens = a;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return
            x == type(IERC165).interfaceId ||
            x == type(ITextResolver).interfaceId ||
            x == type(IAddrResolver).interfaceId ||
            x == type(IAddressResolver).interfaceId ||
            x == type(IPubkeyResolver).interfaceId ||
            x == type(IContentHashResolver).interfaceId ||
            x == type(INameResolver).interfaceId ||
            x == type(IMulticallable).interfaceId ||
            x == type(IExtendedResolver).interfaceId ||
            x == type(IExtendedDNSResolver).interfaceId ||
            x == type(IOnchainResolver).interfaceId ||
            x == 0x73302a25; // https://adraffy.github.io/keccak.js/test/demo.html#algo=evm&s=ccip.context&escape=1&encoding=utf8
    }

    // utils
    modifier requireOperator(bytes32 node) {
        address owner = ens.owner(node);
        if (owner != msg.sender && !ens.isApprovedForAll(owner, msg.sender))
            revert Unauthorized(owner);
        _;
    }
    function slotForCoin(bytes32 node, uint256 cty) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodeCall(IAddressResolver.addr, (node, cty))));
    }
    function slotForText(bytes32 node, string memory key) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodeCall(ITextResolver.text, (node, key))));
    }
    function slotForSelector(bytes4 selector, bytes32 node) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodeWithSelector(selector, node)));
    }

    // getters (structured)
    function addr(bytes32 node) external view returns (address payable a) {
        (bytes32 extnode, address resolver) = determineExternalFallback(node);
        if (
            resolver != address(0) &&
            IERC165(resolver).supportsInterface{gas: ERC165_GAS_LIMIT}(
                type(IAddrResolver).interfaceId
            )
        ) {
            a = IAddrResolver(resolver).addr(extnode);
        }
        if (a == address(0)) {
            a = payable(address(bytes20(getTiny(slotForCoin(node, COIN_TYPE_ETH)))));
        }
    }
    function pubkey(bytes32 node) external view returns (bytes32 x, bytes32 y) {
        (bytes32 extnode, address resolver) = determineExternalFallback(node);
        if (
            resolver != address(0) &&
            IERC165(resolver).supportsInterface{gas: ERC165_GAS_LIMIT}(
                type(IPubkeyResolver).interfaceId
            )
        ) {
            (x, y) = IPubkeyResolver(resolver).pubkey(extnode);
        }
        if (x == 0 && y == 0) {
            bytes memory v = getTiny(slotForSelector(IPubkeyResolver.pubkey.selector, node));
            if (v.length == 64) (x, y) = abi.decode(v, (bytes32, bytes32));
        }
    }

    // getters (bytes-like)
    function addr(bytes32, uint256) external view returns (bytes memory) {
        return reflectGetBytes(msg.data);
    }
    function text(bytes32, string calldata) external view returns (string memory) {
        return string(reflectGetBytes(msg.data));
    }
    function contenthash(bytes32) external view returns (bytes memory) {
        return reflectGetBytes(msg.data);
    }
    function name(bytes32) external view returns (string memory) {
        return string(reflectGetBytes(msg.data));
    }
    function reflectGetBytes(bytes memory request) internal view returns (bytes memory v) {
        bytes32 node;
        assembly {
            node := mload(add(request, 36))
        }
        uint256 slot = uint256(keccak256(request)); // hash before we mangle
        v = getTiny(slot);
        if (v.length == 0) {
            (bytes32 extnode, address resolver) = determineExternalFallback(node);
            if (resolver != address(0)) {
                assembly {
                    mstore(add(request, 36), extnode)
                } // mangled
                (bool ok, bytes memory u) = resolver.staticcall(request);
                if (ok) {
                    v = abi.decode(u, (bytes));
                }
            }
        }
    }

    // TOR helpers
    function parseContext(
        bytes memory v
    ) internal pure returns (string[] memory urls, address signer) {
        // {SIGNER} {ENDPOINT}
        // "0x51050ec063d393217B436747617aD1C2285Aeeee http://a" => (2 + 40 + 1 + 8)
        if (v.length < 51) revert InvalidContext(v);
        bool valid;
        (signer, valid) = v.hexToAddress(2, 42); // unchecked 0x-prefix
        if (!valid) revert InvalidContext(v);
        assembly {
            let size := mload(v)
            v := add(v, 43) // drop address
            mstore(v, sub(size, 43))
        }
        urls = new string[](1); // TODO: support multiple URLs
        urls[0] = string(v);
    }
    function verifyOffchain(
        bytes calldata ccip,
        bytes memory carry
    ) internal view returns (bytes memory request, bytes memory response, bool replace) {
        bytes memory sig;
        uint64 expires;
        (sig, expires, response) = abi.decode(ccip, (bytes, uint64, bytes));
        if (expires < block.timestamp) revert CCIPReadExpired(expires);
        address signer;
        (request, signer, replace) = abi.decode(carry, (bytes, address, bool));
        bytes32 hash = keccak256(
            abi.encodePacked(address(this), expires, keccak256(request), keccak256(response))
        );
        address signed = ECDSA.recover(hash, sig);
        if (signed != signer) revert CCIPReadUntrusted(signed, signer);
    }

    // IExtendedDNSResolver
    function resolve(
        bytes calldata dnsname,
        bytes calldata data,
        bytes calldata context
    ) external view returns (bytes memory) {
        (string[] memory urls, address signer) = parseContext(context);
        bytes memory request = abi.encodeWithSelector(
            IExtendedResolver.resolve.selector,
            dnsname,
            data
        );
        revert OffchainLookup(
            address(this),
            urls,
            request,
            this.buggedCallback.selector,
            abi.encode(abi.encode(request, signer, false), address(this))
        );
    }
    function buggedCallback(
        bytes calldata response,
        bytes calldata buggedExtraData
    ) external view returns (bytes memory v) {
        (, v, ) = verifyOffchain(response, abi.decode(buggedExtraData, (bytes)));
    }

    // IExtendedResolver
    function resolve(
        bytes calldata dnsname,
        bytes calldata data
    ) external view returns (bytes memory) {
        unchecked {
            bytes32 node = dnsname.namehash(0);
            if (bytes4(data) == PREFIX_ONLY_ON) {
                return resolveOnchain(data[4:], CALL_UNMODIFIED);
            } else if (bytes4(data) == PREFIX_ONLY_OFF) {
                if (onchain(node)) {
                    return resolveOnchain(data[4:], CALL_WITH_NULL_NODE);
                } else {
                    resolveOffchain(dnsname, data[4:], OFFCHAIN_ONLY);
                }
            } else if (onchain(node)) {
                // manditory on-chain
                return resolveOnchain(data, CALL_UNMODIFIED);
            } else {
                // off-chain then replace with on-chain
                if (bytes4(data) == IMulticallable.multicall.selector) {
                    bytes[] memory a = abi.decode(data[4:], (bytes[]));
                    bytes[] memory b = new bytes[](a.length);
                    // if one record is missing, go off-chain
                    for (uint256 i; i < a.length; i += 1) {
                        bytes memory v = getEncodedFallbackValue(a[i]);
                        if (v.length == 0) resolveOffchain(dnsname, data, REPLACE_WITH_ONCHAIN);
                        b[i] = v;
                    }
                    return abi.encode(b); // multi-answerable on-chain
                } else {
                    bytes memory v = getEncodedFallbackValue(data);
                    if (v.length != 0) return v; // answerable on-chain
                    resolveOffchain(dnsname, data, OFFCHAIN_ONLY);
                }
            }
        }
    }
    function resolveOnchain(
        bytes calldata data,
        bool clear
    ) internal view returns (bytes memory result) {
        if (bytes4(data) == IMulticallable.multicall.selector) {
            bytes[] memory a = abi.decode(data[4:], (bytes[]));
            for (uint256 i; i < a.length; i += 1) {
                bytes memory v = a[i];
                if (clear)
                    assembly {
                        mstore(add(v, 36), 0)
                    } // clear the node
                (, a[i]) = address(this).staticcall(v);
            }
            result = abi.encode(a);
        } else {
            bytes memory v = data;
            if (clear)
                assembly {
                    mstore(add(v, 36), 0)
                } // clear the node
            (, result) = address(this).staticcall(v);
        }
    }
    function resolveOffchain(
        bytes calldata dnsname,
        bytes calldata data,
        bool replace
    ) internal view {
        (string[] memory urls, address signer) = parseContext(findContext(dnsname));
        bytes memory request = abi.encodeWithSelector(
            IExtendedResolver.resolve.selector,
            dnsname,
            data
        );
        revert OffchainLookup(
            address(this),
            urls,
            request,
            this.ensCallback.selector,
            abi.encode(request, signer, replace)
        );
    }
    function findContext(bytes calldata dnsname) internal view returns (bytes memory context) {
        unchecked {
            uint256 offset;
            while (true) {
                // find the first node in direct lineage...
                bytes32 node = dnsname.namehash(offset);
                if (ens.resolver(node) == address(this)) {
                    // ...that is TOR
                    context = getTiny(slotForText(node, TEXT_CONTEXT));
                    if (context.length != 0) break; // ...and has non-null context
                }
                uint256 size = uint256(uint8(dnsname[offset]));
                if (size == 0) revert Unreachable(dnsname);
                offset += 1 + size;
            }
        }
    }
    function ensCallback(
        bytes calldata ccip,
        bytes calldata carry
    ) external view returns (bytes memory) {
        unchecked {
            (bytes memory request, bytes memory response, bool replace) = verifyOffchain(
                ccip,
                carry
            );
            // single record calls that had on-chain values would of been answered on-chain
            // so we only need to handle multicall() replacement
            if (!replace) return response;
            assembly {
                mstore(add(request, 4), sub(mload(request), 4)) // trim resolve() selector
                request := add(request, 4)
            }
            (, request) = abi.decode(request, (bytes, bytes));
            assembly {
                mstore(add(request, 4), sub(mload(request), 4)) // trim multicall() selector
                request := add(request, 4)
            }
            bytes[] memory a = abi.decode(request, (bytes[]));
            bytes[] memory b = abi.decode(response, (bytes[]));
            for (uint256 i; i < a.length; i += 1) {
                bytes memory v = getEncodedFallbackValue(a[i]);
                if (v.length != 0) b[i] = v; // replace with on-chain
            }
            return abi.encode(b);
        }
    }
    function determineExternalFallback(
        bytes32 node
    ) internal view returns (bytes32 extnode, address resolver) {
        bytes memory v = getTiny(slotForCoin(node, COIN_TYPE_FALLBACK));
        if (v.length == 20) {
            // resolver using same node
            extnode = node;
            resolver = address(bytes20(v));
        } else {
            if (v.length == 32) {
                // differnt node
                extnode = bytes32(v);
            } else if (v.length != 0) {
                // external fallback disabled
                // extnode = 0 => resolver = 0
            } else {
                // default
                // derived: namehash("_" + node)
                // https://adraffy.github.io/keccak.js/test/demo.html#algo=keccak-256&s=_&escape=1&encoding=utf8
                extnode = keccak256(
                    abi.encode(
                        node,
                        0xcd5edcba1904ce1b09e94c8a2d2a85375599856ca21c793571193054498b51d7
                    )
                );
            }
            // Q: should this be ENSIP-10?
            // A: no, since we're calling on-chain methods
            resolver = ens.resolver(extnode);
        }
    }
    function getEncodedFallbackValue(
        bytes memory request
    ) internal view returns (bytes memory encoded) {
        (bool ok, bytes memory v) = address(this).staticcall(request);
        if (ok && !isNullAssumingPadded(v)) {
            // unfortunately it is impossible to determine if an arbitrary abi-encoded response is null
            // abi.encode('') = 0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
            // https://adraffy.github.io/keccak.js/test/demo.html#algo=keccak-256&s=0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000&escape=1&encoding=hex
            if (
                keccak256(v) != 0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd
            ) {
                encoded = v;
            }
        }
    }
    function isNullAssumingPadded(bytes memory v) internal pure returns (bool ret) {
        assembly {
            let p := add(v, 32)
            let e := add(p, mload(v))
            for {
                ret := 1
            } lt(p, e) {
                p := add(p, 32)
            } {
                if iszero(iszero(mload(p))) {
                    // != 0
                    ret := 0
                    break
                }
            }
        }
    }

    // multicall (for efficient multi-record writes)
    // Q: allow ccip-read through this mechanism?
    // A: no, too complex (mixed targets) and not ENSIP-10 compatible
    function multicall(bytes[] calldata calls) external returns (bytes[] memory) {
        return _multicall(0, calls);
    }
    function multicallWithNodeCheck(
        bytes32 nodehash,
        bytes[] calldata calls
    ) external returns (bytes[] memory) {
        return _multicall(nodehash, calls);
    }
    function _multicall(
        bytes32 node,
        bytes[] calldata calls
    ) internal returns (bytes[] memory answers) {
        unchecked {
            answers = new bytes[](calls.length);
            for (uint256 i; i < calls.length; i += 1) {
                if (node != 0) {
                    bytes32 check = bytes32(calls[i][4:36]);
                    if (check != node) revert NodeCheck(check);
                }
                (bool ok, bytes memory v) = address(this).delegatecall(calls[i]);
                require(ok);
                answers[i] = v;
            }
        }
    }

    // setters
    function setAddr(bytes32 node, address a) external {
        setAddr(node, COIN_TYPE_ETH, a == address(0) ? bytes("") : abi.encodePacked(a));
    }
    function setAddr(bytes32 node, uint256 cty, bytes memory v) public requireOperator(node) {
        setTiny(slotForCoin(node, cty), v);
        emit AddressChanged(node, cty, v);
        if (cty == COIN_TYPE_ETH) emit AddrChanged(node, address(bytes20(v)));
    }
    function setText(
        bytes32 node,
        string calldata key,
        string calldata s
    ) external requireOperator(node) {
        setTiny(slotForText(node, key), bytes(s));
        emit TextChanged(node, key, key, s);
    }
    function setContenthash(bytes32 node, bytes calldata v) external requireOperator(node) {
        setTiny(slotForSelector(IContentHashResolver.contenthash.selector, node), v);
        emit ContenthashChanged(node, v);
    }
    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external requireOperator(node) {
        setTiny(
            slotForSelector(IPubkeyResolver.pubkey.selector, node),
            x == 0 && y == 0 ? bytes("") : abi.encode(x, y)
        );
        emit PubkeyChanged(node, x, y);
    }

    // IOnchainResolver
    function toggleOnchain(bytes32 node) external requireOperator(node) {
        uint256 slot = slotForSelector(IOnchainResolver.onchain.selector, node);
        bool on;
        assembly {
            on := iszero(sload(slot))
            sstore(slot, on)
        }
        emit OnchainChanged(node, on);
    }
    function onchain(bytes32 node) public view returns (bool) {
        uint256 slot = slotForSelector(IOnchainResolver.onchain.selector, node);
        assembly {
            slot := sload(slot)
        }
        return slot != 0;
    }

    // ************************************************************
    // TinyKV.sol: https://github.com/adraffy/TinyKV.sol

    // header: first 4 bytes
    // [00000000_00000000000000000000000000000000000000000000000000000000] // null (0 slot)
    // [00000001_XX000000000000000000000000000000000000000000000000000000] // 1 byte (1 slot)
    // [0000001C_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX] // 28 bytes (1 slot
    // [0000001D_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX][XX000000...] // 29 bytes (2 slots)
    function tinySlots(uint256 size) internal pure returns (uint256) {
        unchecked {
            return size != 0 ? (size + 35) >> 5 : 0; // ceil((4 + size) / 32)
        }
    }
    function setTiny(uint256 slot, bytes memory v) internal {
        unchecked {
            uint256 head;
            assembly {
                head := sload(slot)
            }
            uint256 size;
            assembly {
                size := mload(v)
            }
            uint256 n0 = tinySlots(head >> 224);
            uint256 n1 = tinySlots(size);
            assembly {
                // overwrite
                if gt(n1, 0) {
                    sstore(slot, or(shl(224, size), shr(32, mload(add(v, 32)))))
                    let ptr := add(v, 60)
                    for {
                        let i := 1
                    } lt(i, n1) {
                        i := add(i, 1)
                    } {
                        sstore(add(slot, i), mload(ptr))
                        ptr := add(ptr, 32)
                    }
                }
                // clear unused
                for {
                    let i := n1
                } lt(i, n0) {
                    i := add(i, 1)
                } {
                    sstore(add(slot, i), 0)
                }
            }
        }
    }
    function getTiny(uint256 slot) internal view returns (bytes memory v) {
        unchecked {
            uint256 head;
            assembly {
                head := sload(slot)
            }
            uint256 size = head >> 224;
            if (size != 0) {
                v = new bytes(size);
                uint256 n = tinySlots(size);
                assembly {
                    mstore(add(v, 32), shl(32, head))
                    let p := add(v, 60)
                    for {
                        let i := 1
                    } lt(i, n) {
                        i := add(i, 1)
                    } {
                        mstore(p, sload(add(slot, i)))
                        p := add(p, 32)
                    }
                }
            }
        }
    }
}
