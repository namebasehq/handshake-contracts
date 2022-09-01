// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// TODO: remove owner?!
struct RegistryRecord {
    address owner;
    address resolver;
    uint64 ttl;
}